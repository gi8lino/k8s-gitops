# k8s-gitops

![Kubernetes](https://i.imgur.com/p1RzXjQ.png)

## :loudspeaker:&nbsp; About

This repository contains my entire Kubernetes cluster setup built on K3s and managed by Flux v2.  
Secrets are encrypted and managed with [SOPS](https://github.com/mozilla/sops).

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

### :closed_lock_with_key:&nbsp; Setting up GnuPG keys

:round_pushpin: Using SOPS with GnuPG allows to encrypt and decrypt secrets.

Create a GPG Key for Flux:

```sh
export GPG_TTY=$(tty)
export FLUX_KEY_NAME="k3s"

gpg --batch --full-generate-key <<EOF
%no-protection
Key-Type: 1
Key-Length: 4096
Subkey-Type: 1
Subkey-Length: 4096
Expire-Date: 0
Name-Real: ${FLUX_KEY_NAME}
EOF
```

Show the just created Flux GPG Key:

```sh
gpg --list-secret-keys "${FLUX_KEY_NAME}"
# pub   rsa4096 2021-03-11 [SC]
#       AB675CE4CC64251G3S9AE1DAA88ARRTY2C009E2D
# uid           [ultimate] Home cluster (Flux) <k8s-at-home@gmail.com>
# sub   rsa4096 2021-03-11 [E]
```

Export the fingerprint of the just created Flux GPG Key to the variable `FLUX_KEY_FP`:

```sh
export FLUX_KEY_FP=$(gpg --list-secret-keys "${FLUX_KEY_NAME}" | sed -n '/sec/{n;s/^\s*\s//;p;}')
```

Check if the exported fingerprint was extracted correctly:

```sh
echo ${FLUX_KEY_FP}
# AB675CE4CC64251G3S9AE1DAA88ARRTY2C009E2D
```

Create/update `.sops.yaml`:

```bash
cat << EOF > .sops.yaml
---
creation_rules:
  - encrypted_regex: ^(data|stringData|customRequestHeaders)$
    pgp: ${FLUX_KEY_FP}

EOF
```

## :leftwards_arrow_with_hook:&nbsp; Install pre-commit Hooks

Install all pre-commit hooks so they are executed every time before a commit occurs.

```bash
pre-commit install --hook-type pre-commit
```

Add `export BASE_DOMAIN=example.com` to your `.bashrc`, `.zprofile` or `.zshrc`.

## :wrench:&nbsp; Initial Deployment

1. Install [K3s](https://k3s.io)
2. Install [cilium](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default)
3. Create `flux-system` namespace

```bash
kubectl create namespace flux-system
```

4. Add the Flux GPG key in-order for Flux to decrypt SOPS secrets

```bash
gpg --export-secret-keys --armor "${FLUX_KEY_FP}" |
kubectl create secret generic sops-gpg \
    --namespace=flux-system \
    --from-file=sops.asc=/dev/stdin
```

5. Update `cluster-secrets.yaml` with your settings
6. Apply `cluster-settings.yaml`

```bash
kubectl apply -f core/cluster-settings.yaml
```

7. Bootstrap cluster

```bash
kubectl apply --kustomize=./core/flux-system
```

## :robot:&nbsp; Automation

- [Renovate](https://www.whitesourcesoftware.com/free-developer-tools/renovate) is a very useful tool that when configured will start to create PRs in your GitHub repository when Docker images, Helm charts or anything else that can be tracked has a newer version. The configuration for Renovate is located [here](./.github/renovate.json5)

There are also a couple GitHub workflows included in this repository that will help automate some processes.

- [Update Flux](./.github/workflows/update-flux.yaml) - workflow to update Flux components
- [Sync Cloudflare network ranges](./.github/workflows/sync-cloudflare-nets.yaml) - workflow to update Cloudflare network ranges
- [Diff HelmReleases on Pull Requests](./.github/workflows/helm-release-differ.yaml) - workflow to add diff to `HelmRelease` pull requests

## :hugs:&nbsp; Thanks

Huge thanks to the community at [k8s@home](https://github.com/k8s-at-home) for the awesome templates and the Kubernetes at home logo!
