#!/usr/bin/env python3
"""
Cleanup unused container images on Kubernetes nodes via kubectl + SSH + crictl.

How it works:
  1) Pull all pods via kubectl and collect image refs per node (spec + status).
  2) For each node, use SSH to run `crictl images -o json`.
  3) Remove any image that is not referenced by running pods on that node.

Requirements:
  - kubectl access to the cluster
  - SSH access to each node (optionally with sudo crictl)
  - crictl installed on each node
"""

import argparse
import json
import os
import shlex
import subprocess
from typing import Dict, List, Set, Tuple


def run(cmd: List[str], capture: bool = True) -> subprocess.CompletedProcess:
    """Run a command and return the CompletedProcess (raises on failure)."""
    return subprocess.run(cmd, check=True, text=True, capture_output=capture)


def kubectl_get_json(args: List[str]) -> dict:
    """Run a kubectl command and parse JSON output."""
    out = run(["kubectl"] + args + ["-o", "json"]).stdout
    return json.loads(out)


def get_nodes() -> Dict[str, str]:
    """Return nodeName -> sshHost (InternalIP if present, else nodeName)."""
    data = kubectl_get_json(["get", "nodes"])
    nodes = {}
    for item in data.get("items", []):
        name = item["metadata"]["name"]
        internal_ip = None
        for addr in item.get("status", {}).get("addresses", []):
            if addr.get("type") == "InternalIP":
                internal_ip = addr.get("address")
                break
        nodes[name] = internal_ip or name
    return nodes


def normalize_image_ref(ref: str) -> str:
    """Normalize kube-style image refs to plain image references."""
    if not ref:
        return ref
    # Strip kube's docker-pullable:// prefix
    if ref.startswith("docker-pullable://"):
        return ref.split("docker-pullable://", 1)[1]
    if ref.startswith("docker://"):
        return ref.split("docker://", 1)[1]
    return ref


def get_used_images_by_node() -> Dict[str, Set[str]]:
    """Collect image references in use per node from pod specs and status."""
    data = kubectl_get_json(["get", "pods", "-A"])
    used_by_node: Dict[str, Set[str]] = {}

    for pod in data.get("items", []):
        node = pod.get("spec", {}).get("nodeName")
        if not node:
            continue
        used_by_node.setdefault(node, set())

        # Spec images (containers, initContainers, ephemeralContainers).
        spec = pod.get("spec", {})
        for key in ("containers", "initContainers", "ephemeralContainers"):
            for c in spec.get(key, []) or []:
                ref = normalize_image_ref(c.get("image", ""))
                if ref:
                    used_by_node[node].add(ref)

        # Status imageIDs (resolved digests) catch images pinned by digest.
        status = pod.get("status", {})
        for key in ("containerStatuses", "initContainerStatuses", "ephemeralContainerStatuses"):
            for cs in status.get(key, []) or []:
                ref = normalize_image_ref(cs.get("imageID", ""))
                if ref:
                    used_by_node[node].add(ref)

    return used_by_node


def ssh_run(host: str, user: str, cmd: str, capture: bool = True) -> subprocess.CompletedProcess:
    """Run a command on a remote host over SSH."""
    target = f"{user}@{host}" if user else host
    return run(["ssh", target, cmd], capture=capture)


def get_node_images(host: str, user: str, sudo: bool) -> List[dict]:
    """Return CRI image inventory for a node using crictl JSON output."""
    sudo_prefix = "sudo " if sudo else ""
    cmd = f"{sudo_prefix}crictl images -o json"
    out = ssh_run(host, user, cmd).stdout
    data = json.loads(out)
    return data.get("images", [])


def find_unused_images(node: str, used_refs: Set[str], images: List[dict]) -> List[Tuple[str, List[str], List[str]]]:
    """Return images that are not referenced by any running pod on the node."""
    unused = []
    for image in images:
        image_id = image.get("id", "")
        repo_tags = image.get("repoTags", []) or []
        repo_digests = image.get("repoDigests", []) or []

        # Build all refs that would count as used for this image.
        refs = set()
        for ref in repo_tags + repo_digests:
            if ref:
                refs.add(ref)
        if image_id:
            refs.add(image_id)

        # If any ref is used, keep the image.
        if refs.intersection(used_refs):
            continue

        unused.append((image_id, repo_tags, repo_digests))

    return unused


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Cleanup unused CRI images on Kubernetes nodes")
    parser.add_argument(
        "--user", default=os.environ.get("SSH_USER", ""), help="SSH user")
    parser.add_argument("--sudo", action="store_true",
                        help="Use sudo for crictl")
    parser.add_argument("--apply", action="store_true",
                        help="Actually delete images (default: dry-run)")
    parser.add_argument("--node", action="append", default=[],
                        help="Limit to specific node (repeatable)")
    args = parser.parse_args()

    # Discover nodes and current in-use images.
    nodes = get_nodes()
    used_by_node = get_used_images_by_node()

    targets = args.node if args.node else list(nodes.keys())

    for node in targets:
        host = nodes.get(node)
        if not host:
            print(f"[WARN] Node not found in cluster: {node}")
            continue

        print(f"\n==> {node} ({host})")
        used_refs = used_by_node.get(node, set())

        try:
            images = get_node_images(host, args.user, args.sudo)
        except subprocess.CalledProcessError as exc:
            print(f"[ERROR] Failed to list images on {node}: {exc}")
            continue

        # Compare CRI inventory to in-use refs.
        unused = find_unused_images(node, used_refs, images)
        if not unused:
            print("No unused images found.")
            continue

        for image_id, repo_tags, repo_digests in unused:
            tags = ", ".join(repo_tags) if repo_tags else "-"
            digests = ", ".join(repo_digests) if repo_digests else "-"
            if args.apply:
                # Remove by image ID to avoid ambiguity in tags/digests.
                sudo_prefix = "sudo " if args.sudo else ""
                cmd = f"{sudo_prefix}crictl rmi {shlex.quote(image_id)}"
                try:
                    ssh_run(host, args.user, cmd, capture=False)
                    print(
                        f"Removed: {image_id} | tags: {tags} | digests: {digests}")
                except subprocess.CalledProcessError as exc:
                    print(
                        f"[ERROR] Failed to remove {image_id} on {node}: {exc}")
            else:
                print(
                    f"Would remove: {image_id} | tags: {tags} | digests: {digests}")

    if not args.apply:
        print("\nDry-run only. Re-run with --apply to delete images.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
