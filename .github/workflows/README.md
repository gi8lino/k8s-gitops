# github actions

This directory contains github actions.

## Contents

- **diff-helmreleases** gives you a preview of what a `helm upgrade` would change
- **renovate-helmreleases** configures [Flux2](https://github.com/fluxcd/flux2) HelmRelease's for automated updates using [Renovate](https://github.com/renovatebot/renovate)
- **sync-cloudflare-nets** updates `infra/traefik/traefik/networkpolicies/traefik.yaml` if cloudflare ip ranges changes
- **sync-github-api-nets** updates `core/networkpolicies/flux-system/notification-controller.yaml` if github api ip ranges changes
- **update-flux** updates flux components
