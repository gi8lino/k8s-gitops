#!/usr/bin/env python3
"""
Check that all CiliumNetworkPolicy/NetworkPolicy matchLabels selectors match at least one live pod.

Requirements: kubectl in PATH and access to the cluster.
Exit status 0 if all selectors match; 1 otherwise.
"""
import json
import subprocess
import sys
from typing import Dict, List, Optional


NAMESPACE_LABEL_PREFIX = "io.cilium.k8s.namespace.labels."
SERVICE_ACCOUNT_LABEL = "io.cilium.k8s.policy.serviceaccount"


def kubectl_get(kind: str) -> Dict:
    """Return kubectl get <kind> -A -o json (dict) or empty items on failure."""
    try:
        out = subprocess.check_output(["kubectl", "get", kind, "-A", "-o", "json"], text=True)
        return json.loads(out)
    except subprocess.CalledProcessError:
        return {"items": []}
    except json.JSONDecodeError:
        return {"items": []}


def load_pods() -> Dict[str, List[Dict]]:
    """Return all pods keyed by namespace."""
    pods_by_ns: Dict[str, List[Dict]] = {}
    try:
        out = subprocess.check_output(["kubectl", "get", "pods", "-A", "-o", "json"], text=True)
        data = json.loads(out)
    except subprocess.CalledProcessError:
        return pods_by_ns
    except json.JSONDecodeError:
        return pods_by_ns

    for item in data.get("items", []):
        ns = item.get("metadata", {}).get("namespace")
        pods_by_ns.setdefault(ns, []).append(item)
    return pods_by_ns


def load_namespace_labels() -> Dict[str, Dict[str, str]]:
    """Return namespace labels keyed by namespace name."""
    data = kubectl_get("namespace")
    labels_by_ns: Dict[str, Dict[str, str]] = {}

    for item in data.get("items", []):
        meta = item.get("metadata", {})
        name = meta.get("name")
        labels_by_ns[name] = meta.get("labels", {}) or {}

    return labels_by_ns


def selector_matches(
    sel: Optional[Dict],
    default_ns: str,
    pods_by_ns: Dict[str, List[Dict]],
    labels_by_ns: Dict[str, Dict[str, str]],
) -> bool:
    """Return True if selector matches any pod in target namespace."""
    if not sel:
        return True
    raw_ml = sel.get("matchLabels") or {}
    ml = dict(raw_ml)
    if not ml:
        return True

    ns = default_ns
    has_explicit_namespace = False
    for ns_key in ("k8s:io.kubernetes.pod.namespace", "io.kubernetes.pod.namespace"):
        if ns_key in ml:
            ns = ml.pop(ns_key)
            has_explicit_namespace = True
            break

    namespace_labels = {}
    for key in list(ml):
        if key.startswith(NAMESPACE_LABEL_PREFIX):
            namespace_labels[key.removeprefix(NAMESPACE_LABEL_PREFIX)] = ml.pop(key)

    service_account = ml.pop(SERVICE_ACCOUNT_LABEL, None)

    namespaces = [ns] if has_explicit_namespace or not namespace_labels else sorted(pods_by_ns)
    for pod_ns in namespaces:
        ns_labels = labels_by_ns.get(pod_ns, {})
        if any(ns_labels.get(k) != v for k, v in namespace_labels.items()):
            continue

        for pod in pods_by_ns.get(pod_ns, []):
            labels = pod.get("metadata", {}).get("labels", {}) or {}
            pod_service_account = pod.get("spec", {}).get("serviceAccountName")
            if service_account and pod_service_account != service_account:
                continue
            if all(labels.get(k) == v for k, v in ml.items()):
                return True
    return False


def selector_labels(sel: Optional[Dict]) -> Dict:
    if not sel:
        return {}
    return sel.get("matchLabels", {})


def main() -> int:
    pods_by_ns = load_pods()
    labels_by_ns = load_namespace_labels()
    policies = []
    for kind in ("ciliumnetworkpolicy", "networkpolicy"):
        policies.extend(kubectl_get(kind).get("items", []))

    problems = []

    for p in policies:
        meta = p.get("metadata", {})
        ns = meta.get("namespace") or "default"
        name = meta.get("name")
        kind = p.get("kind")
        spec = p.get("spec") or {}
        policy_id = f"{kind}/{ns}/{name}"

        if not selector_matches(spec.get("endpointSelector"), ns, pods_by_ns, labels_by_ns):
            problems.append((policy_id, "endpointSelector", selector_labels(spec.get("endpointSelector"))))

        for rule in spec.get("ingress") or []:
            for sel in rule.get("fromEndpoints") or []:
                if not selector_matches(sel, ns, pods_by_ns, labels_by_ns):
                    problems.append((policy_id, "ingress.fromEndpoints", selector_labels(sel)))

        for rule in spec.get("egress") or []:
            for sel in rule.get("toEndpoints") or []:
                if not selector_matches(sel, ns, pods_by_ns, labels_by_ns):
                    problems.append((policy_id, "egress.toEndpoints", selector_labels(sel)))

    if problems:
        print("Selectors with zero matching pods:\n")
        for policy_id, section, ml in problems:
            labels = ", ".join(f"{k}={v}" for k, v in (ml or {}).items())
            print(f"- {policy_id} :: {section} => {labels}")
        return 1

    print("All matchLabels selectors matched at least one pod.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
