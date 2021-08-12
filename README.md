# k8s-gitops

![Kubernetes](https://i.imgur.com/p1RzXjQ.png)

## :loudspeaker:&nbsp; About

This repository contains my entire Kubernetes cluster setup built on K3s and managed by Flux v2.

## :open_file_folder:&nbsp; Repository structure

The Git repository contains the following directories and are ordered below by how Flux will apply them.

- **core** directory is the entrypoint to Flux
- **crds** directory contains custom resource definitions (CRDs) that need to exist globally in your cluster before anything else exists
- **infra** directory (depends on **crds**) are important infrastructure applications to run k3s(grouped by namespace)
- **base** directory (depends on **infra**) are additional infrastructure applications for k3s(grouped by namespace)
- **apps** directory (depends on **base**) is where your common applications (grouped by namespace) could be placed
- **hack** directory with helper scripts

### :closed_lock_with_key:&nbsp; Setting up GnuPG keys

:round_pushpin: Here we will create a personal and a Flux GPG key. Using SOPS with GnuPG allows us to encrypt and decrypt secrets.

1. Create a Personal GPG Key, password protected, and export the fingerprint. It's **strongly encouraged** to back up this key somewhere safe so you don't lose it.

```sh
export GPG_TTY=$(tty)
export PERSONAL_KEY_NAME="gi8lino"

gpg --batch --full-generate-key <<EOF
Key-Type: 1
Key-Length: 4096
Subkey-Type: 1
Subkey-Length: 4096
Expire-Date: 0
Name-Real: ${PERSONAL_KEY_NAME}
EOF

gpg --list-secret-keys "${PERSONAL_KEY_NAME}"
# pub   rsa4096 2021-03-11 [SC]
#       772154FFF783DE317KLCA0EC77149AC618D75581
# uid           [ultimate] k8s@home (Macbook) <k8s-at-home@gmail.com>
# sub   rsa4096 2021-03-11 [E]

export PERSONAL_KEY_FP=772154FFF783DE317KLCA0EC77149AC618D75581
```

2. Create a Flux GPG Key and export the fingerprint

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

gpg --list-secret-keys "${FLUX_KEY_NAME}"
# pub   rsa4096 2021-03-11 [SC]
#       AB675CE4CC64251G3S9AE1DAA88ARRTY2C009E2D
# uid           [ultimate] Home cluster (Flux) <k8s-at-home@gmail.com>
# sub   rsa4096 2021-03-11 [E]

export FLUX_KEY_FP=AB675CE4CC64251G3S9AE1DAA88ARRTY2C009E2D
```

update fingerprint in `.sops.yaml`

```bash
envsubst < .sops.template > ./.sops.yaml
```

## :leftwards_arrow_with_hook:&nbsp; Install pre-commit Hooks

```bash
pre-commit install --hook-type pre-commit
```

## :wrench:&nbsp; Initial Deployment

1. Install [K3s](https://k3s.io)
2. Install [Calico](https://docs.projectcalico.org/getting-started/kubernetes/)
3. Create `flux-system` namespace  
   `kubectl create namespace flux-system`
4. Add the Flux GPG key in-order for Flux to decrypt SOPS secrets  
  ```bash
  gpg --export-secret-keys --armor "${FLUX_KEY_FP}" |
  kubectl create secret generic sops-gpg \
      --namespace=flux-system \
      --from-file=sops.asc=/dev/stdin
  ```
5. Apply cluster-settings.yaml  
   `kubectl apply -f core/cluster-settings.yaml`
6. Bootstrap cluster  
   ```bash
   kubectl apply --kustomize=./core/flux-system
   ```

## :hugs:&nbsp; Thanks

Thanks to the community at [k8s@home](https://github.com/k8s-at-home) for the awesome templates and the Kubernetes at home logo!
