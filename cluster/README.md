# cluster Directory

This directory is the root of the GitOps stack reconciled by Flux.
Everything under here is applied declaratively.

## Contents

- **apps** – application definitions grouped per namespace or stack
- **crds** – `CustomResourceDefinition` sources Flux applies before apps
- **flux** – Flux controllers, sources, kustomizations, and shared vars
- **networkpolicies** – cluster-wide Cilium network policies
