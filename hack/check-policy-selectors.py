#!/usr/bin/env python3
"""Check live Cilium and Kubernetes network-policy selectors against pods."""

import json
import subprocess
import sys
from typing import Dict, Iterable, List, Optional


NAMESPACE_KEYS = (
    "k8s:io.kubernetes.pod.namespace",
    "io.kubernetes.pod.namespace",
)
NAMESPACE_LABEL_PREFIX = "io.cilium.k8s.namespace.labels."
SERVICE_ACCOUNT_LABEL = "io.cilium.k8s.policy.serviceaccount"


def kubectl_get(kind: str) -> Dict:
    """Return ``kubectl get <kind> -A -o json`` or raise on any failure."""
    try:
        result = subprocess.run(
            ["kubectl", "get", kind, "-A", "-o", "json"],
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError as exc:
        raise RuntimeError("kubectl was not found in PATH") from exc
    except subprocess.CalledProcessError as exc:
        detail = exc.stderr.strip() or exc.stdout.strip() or "unknown kubectl error"
        raise RuntimeError(f"kubectl get {kind} failed: {detail}") from exc

    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"kubectl get {kind} returned invalid JSON: {exc}") from exc

    if not isinstance(data.get("items"), list):
        raise RuntimeError(f"kubectl get {kind} returned JSON without an items list")
    return data


def load_pods() -> Dict[str, List[Dict]]:
    """Return all live pods keyed by namespace."""
    pods_by_ns: Dict[str, List[Dict]] = {}
    for item in kubectl_get("pods")["items"]:
        namespace = item.get("metadata", {}).get("namespace")
        if namespace:
            pods_by_ns.setdefault(namespace, []).append(item)
    return pods_by_ns


def load_namespace_labels() -> Dict[str, Dict[str, str]]:
    """Return namespace labels keyed by namespace name."""
    labels_by_ns: Dict[str, Dict[str, str]] = {}
    for item in kubectl_get("namespace")["items"]:
        metadata = item.get("metadata", {})
        name = metadata.get("name")
        if name:
            labels_by_ns[name] = metadata.get("labels", {}) or {}
    return labels_by_ns


def labels_match(selector: Optional[Dict], labels: Dict[str, str]) -> bool:
    """Implement Kubernetes LabelSelector matchLabels and matchExpressions."""
    if not selector:
        return True

    for key, value in (selector.get("matchLabels") or {}).items():
        if labels.get(key) != value:
            return False

    for requirement in selector.get("matchExpressions") or []:
        key = requirement.get("key")
        operator = requirement.get("operator")
        values = requirement.get("values") or []
        present = key in labels

        if operator == "In" and (not present or labels[key] not in values):
            return False
        if operator == "NotIn" and present and labels[key] in values:
            return False
        if operator == "Exists" and not present:
            return False
        if operator == "DoesNotExist" and present:
            return False
        if operator not in {"In", "NotIn", "Exists", "DoesNotExist"}:
            return False

    return True


def selector_keys(selector: Optional[Dict]) -> Iterable[str]:
    if not selector:
        return []
    keys = list((selector.get("matchLabels") or {}).keys())
    keys.extend(
        requirement.get("key")
        for requirement in selector.get("matchExpressions") or []
        if requirement.get("key")
    )
    return keys


def cilium_labels_for_pod(
    pod: Dict,
    namespace_labels: Dict[str, Dict[str, str]],
) -> Dict[str, str]:
    """Return the pod labels plus Cilium's namespace and service-account labels."""
    metadata = pod.get("metadata", {})
    namespace = metadata.get("namespace") or "default"
    labels = dict(metadata.get("labels", {}) or {})

    for key in NAMESPACE_KEYS:
        labels[key] = namespace
    for key, value in namespace_labels.get(namespace, {}).items():
        labels[f"{NAMESPACE_LABEL_PREFIX}{key}"] = value

    service_account = pod.get("spec", {}).get("serviceAccountName")
    if service_account:
        labels[SERVICE_ACCOUNT_LABEL] = service_account
    return labels


def cilium_selector_matches(
    selector: Optional[Dict],
    default_namespace: str,
    pods_by_ns: Dict[str, List[Dict]],
    namespace_labels: Dict[str, Dict[str, str]],
    cluster_scoped: bool = False,
) -> bool:
    """Return whether a Cilium endpoint selector matches at least one pod."""
    keys = set(selector_keys(selector))
    selects_namespaces = bool(keys.intersection(NAMESPACE_KEYS)) or any(
        key.startswith(NAMESPACE_LABEL_PREFIX) for key in keys
    )
    namespaces = sorted(pods_by_ns) if cluster_scoped or selects_namespaces else [default_namespace]

    return any(
        labels_match(selector, cilium_labels_for_pod(pod, namespace_labels))
        for namespace in namespaces
        for pod in pods_by_ns.get(namespace, [])
    )


def network_policy_peer_matches(
    peer: Dict,
    policy_namespace: str,
    pods_by_ns: Dict[str, List[Dict]],
    namespace_labels: Dict[str, Dict[str, str]],
) -> bool:
    """Return whether a Kubernetes NetworkPolicy peer matches a live pod."""
    pod_selector = peer.get("podSelector")
    namespace_selector = peer.get("namespaceSelector")
    if pod_selector is None and namespace_selector is None:
        return True

    if namespace_selector is None:
        namespaces = [policy_namespace]
    else:
        namespaces = [
            namespace
            for namespace, labels in namespace_labels.items()
            if labels_match(namespace_selector, labels)
        ]

    return any(
        labels_match(pod_selector, pod.get("metadata", {}).get("labels", {}) or {})
        for namespace in namespaces
        for pod in pods_by_ns.get(namespace, [])
    )


def describe_selector(selector: Optional[Dict]) -> str:
    return json.dumps(selector or {}, sort_keys=True, separators=(",", ":"))


def main() -> int:
    try:
        pods_by_ns = load_pods()
        namespace_labels = load_namespace_labels()
        cilium_policies = kubectl_get("ciliumnetworkpolicy")["items"]
        clusterwide_policies = kubectl_get("ciliumclusterwidenetworkpolicy")["items"]
        network_policies = kubectl_get("networkpolicy")["items"]
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    problems = []
    for policy in [*cilium_policies, *clusterwide_policies]:
        metadata = policy.get("metadata", {})
        namespace = metadata.get("namespace") or "default"
        policy_id = f"{policy.get('kind')}/{namespace}/{metadata.get('name')}"
        spec = policy.get("spec") or {}
        cluster_scoped = policy.get("kind") == "CiliumClusterwideNetworkPolicy"

        endpoint_selector = spec.get("endpointSelector")
        if not cilium_selector_matches(
            endpoint_selector,
            namespace,
            pods_by_ns,
            namespace_labels,
            cluster_scoped,
        ):
            problems.append((policy_id, "endpointSelector", endpoint_selector))

        for rule in spec.get("ingress") or []:
            for selector in rule.get("fromEndpoints") or []:
                if not cilium_selector_matches(
                    selector,
                    namespace,
                    pods_by_ns,
                    namespace_labels,
                    cluster_scoped,
                ):
                    problems.append((policy_id, "ingress.fromEndpoints", selector))

        for rule in spec.get("egress") or []:
            for selector in rule.get("toEndpoints") or []:
                if not cilium_selector_matches(
                    selector,
                    namespace,
                    pods_by_ns,
                    namespace_labels,
                    cluster_scoped,
                ):
                    problems.append((policy_id, "egress.toEndpoints", selector))

    for policy in network_policies:
        metadata = policy.get("metadata", {})
        namespace = metadata.get("namespace") or "default"
        policy_id = f"NetworkPolicy/{namespace}/{metadata.get('name')}"
        spec = policy.get("spec") or {}
        pod_selector = spec.get("podSelector")
        if not any(
            labels_match(pod_selector, pod.get("metadata", {}).get("labels", {}) or {})
            for pod in pods_by_ns.get(namespace, [])
        ):
            problems.append((policy_id, "podSelector", pod_selector))

        for direction in ("ingress", "egress"):
            peer_key = "from" if direction == "ingress" else "to"
            for rule in spec.get(direction) or []:
                for peer in rule.get(peer_key) or []:
                    if not network_policy_peer_matches(
                        peer,
                        namespace,
                        pods_by_ns,
                        namespace_labels,
                    ):
                        problems.append((policy_id, f"{direction}.{peer_key}", peer))

    if problems:
        print("Selectors with zero matching pods:\n")
        for policy_id, section, selector in problems:
            print(f"- {policy_id} :: {section} => {describe_selector(selector)}")
        return 1

    print("All policy selectors matched at least one pod.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
