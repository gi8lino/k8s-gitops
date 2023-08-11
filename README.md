# k8s-gitops

![Kubernetes](https://i.imgur.com/p1RzXjQ.png)

## :loudspeaker:&nbsp; About

This repository contains my entire Kubernetes cluster setup built on K3s and managed by Flux v2.\
Secrets are encrypted and managed with [SOPS](https://github.com/mozilla/sops).

For initial deploy see this manuals:

- [Install pre-commit Hooks](./.github/docs/precommit.md)
- [Setting up GnuPG keys](./.github/docs/gpg.md)
- [Initial flux deployment](./.github/docs/flux.md)

---

## GitOps

[Flux](https://github.com/fluxcd/flux2) watches my cluster folder (see `Repository Structure` below) and makes the changes to my cluster based on the YAML manifests.

[Renovate](https://github.com/renovatebot/renovate) is a very useful tool that when configured will start to create PRs in your GitHub repository when Docker images, Helm charts or anything else that can be tracked has a newer version. The configuration for Renovate is located [here](./.github/renovate.json5)

There are also a couple GitHub workflows included in this repository that will help automate some processes. See [here](.github/workflows/README.md) fore more information.

## :open_file_folder:&nbsp; Repository Structure

This Git Repository contains the following directories and are ordered below by how Flux will apply them:

- **core** directory is where Flux deployments are located
- **crds** directory (depends on **core**) contains CustomResourceDefinitions that need to exist before anything else
- **infra** directory (depends on **crds**) contains infrastructure applications such as Traefik, MetalLB and so on
- **base** directory (depends on **infra**) contains applications that are useful for cluster operations such as kube-prometheus-stack, K8up and so on
- **apps** directory (depends on **base**) is where common applications are located

These directories are not tracked by Flux but are useful nonetheless:

- **.github** directory contains GitHub related files
- **.taskfiles** directory contains [go-taks](https://github.com/go-task/task) related files
- **hack** directory contains useful scrips

---

## 🌐 DNS

### Ingress Controller

Over WAN, I have port forwarded ports `80` and `443` to the load balancer IP of my ingress controller that's running in my Kubernetes cluster.

[Cloudflare](https://www.cloudflare.com/) works as a proxy to hide my homes WAN IP and also as a firewall. [Cilium](https://cilium.io) blocks all IPs not originating from the [Cloudflares list of IP ranges](https://www.cloudflare.com/ips/), except the local network range `${LAN_NETWORK_RANGE}`.

### Internal DNS

For internal DNS i use the built-in [dnsmasq](https://thekelleys.org.uk/dnsmasq/doc.html) of [pihole](https://pi-hole.net) deployed on a raspberry pi.

For adblocking, I have [pihole](https://pi-hole.net) deployed on a raspberry pi.

### External DNS

[cloudflare-operator](https://github.com/containeroo/cloudflare-operator) is deployed in my cluster and ingresses with the annotation `cloudflare-operator.io/type=CNAME` and `cloudflare-operator.io/content=${BASE_DOMAIN}` will be synced with [Cloudflare](https://www.cloudflare.com/).

### Dynamic DNS

[cloudflare-operator](https://github.com/containeroo/cloudflare-operator) syncs also my external IPv4 address with [Cloudflare](https://www.cloudflare.com/).

---

## :hugs:&nbsp; Thanks

Huge thanks to the community at [k8s@home](https://github.com/k8s-at-home) for the awesome templates and the Kubernetes at home logo!
