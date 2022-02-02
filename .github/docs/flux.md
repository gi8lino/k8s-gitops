# :wrench:&nbsp; Initial Deployment

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
