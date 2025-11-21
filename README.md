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

- **cluster/flux** directory is where Flux deployments are located
- **cluster/crds** directory contains CustomResourceDefinitions that need to exist before anything else
- **cluster/apps** directory (depends on **crds**) is where common applications are located
- **cluster/networkpolicies** directory (depends on **cilium**) contains network policies

These directories are not tracked by Flux but are useful nonetheless:

- **.github** directory contains GitHub related files
- **.taskfiles** directory contains [go-taks](https://github.com/go-task/task) related files
- **hack** directory contains useful scrips

---

## 🌐 DNS

### Gateways

Ports `80/443` forward to the two Envoy Gateway data planes: `envoy-external` serves public FQDNs while `envoy-internal` handles internal-only services. Cloudflare fronts the external Gateway, and dedicated Cilium network policies only permit traffic originating from Cloudflare's published ranges; everything else is dropped before it reaches Envoy. My router port-forwards those public ports to the `gateway-external` gateway, while internal services stay behind `gateway-internal`.

### Internal DNS

Internal DNS relies on the built-in [dnsmasq](https://thekelleys.org.uk/dnsmasq/doc.html) of [pihole](https://pi-hole.net) deployed on a raspberry pi, which forwards every lookup to `gateway-internal` so internal applications are reachable only via the internal gateway. Pi-hole also handles ad blocking.

### External DNS

[cloudflare-operator](https://github.com/containeroo/cloudflare-operator) is deployed in my cluster and ingresses with the annotation `cloudflare-operator.io/type=CNAME` and `cloudflare-operator.io/content=${BASE_DOMAIN}` will be synced with [Cloudflare](https://www.cloudflare.com/).

### Dynamic DNS

[cloudflare-operator](https://github.com/containeroo/cloudflare-operator) syncs also my external IPv4 address with [Cloudflare](https://www.cloudflare.com/).

---

## :hugs:&nbsp; Thanks

Huge thanks to the community at [k8s@home](https://github.com/k8s-at-home) for the awesome templates and the Kubernetes at home logo!
