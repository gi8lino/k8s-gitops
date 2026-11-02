# github actions

This directory contains github actions.

## Contents

- **helm-release-differ** uses flate to compare rendered HelmReleases against the PR merge-base, with an updated PR comment and downloadable HTML/full diffs. SOPS keys are never provided: encrypted values use placeholders and unavailable values references are omitted, so this is an offline preview rather than an exact deployment plan.
- **scan-containers** check if used images have known vulnerabilities
- **sync-cloudflare-nets** updates `infra/traefik/networkpolicies/traefik.yaml` if cloudflare ip ranges changes
