# flux Directory

This directory contains Flux deployments and other manifests.

## Contents

- **vars** contains all `Secret` and `ConfigMap` manifests
- **config** contains Flux manifests
- **repositories** contains all `HelmRepository` and `kustomizations` for Flux
- **namespaces** contains all `Namespace` manifests
- **networkpolicies** containsi `CiliumNetworkPolicy` manifests for Flux
- **notifications** contains all manifests to configure Slack and GitHub notifications for Flux
- **webhook** contains all manifests to configure GitHub webhook to Flux
- **crds.yaml** contains all `CustomResourceDefinition` manifests
- **apps.yaml** contains all `Kustomization` manifests
- **networkpolicies.yaml** contains all `CiliumClusterwideNetworkPolicy` manifests for the cluster
