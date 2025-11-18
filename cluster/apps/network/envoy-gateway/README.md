# Envoy Gateway

This app deploys Envoy Gateway in the `network` namespace. Two Gateway
instances are defined:

- `envoy-external` announces `${ENVOY_EXTERNAL_LB_IP}` for public traffic.
- `envoy-internal` announces `${ENVOY_INTERNAL_LB_IP}` for
  `*.local.${BASE_DOMAIN}` traffic.

## Migrating workloads

1. Replace every `Ingress` with an `HTTPRoute` that targets the desired
   Gateway, e.g.

   ```yaml
   apiVersion: gateway.networking.k8s.io/v1
   kind: HTTPRoute
   metadata:
     name: whoami-external
     namespace: debug
   spec:
     parentRefs:
       - name: envoy-external
         namespace: network
         sectionName: https
     hostnames:
       - whoami.${BASE_DOMAIN}
     rules:
       - backendRefs:
           - name: whoami
             port: 80
   ```

2. When authenticated access is required, handle that logic within the
   application itself or via Envoy Gateway filters (JWT, RateLimit, etc.)
   so the HTTPRoute can point directly at the backend service.

3. Remove unused `Ingress` objects once their HTTPRoute equivalents have
   been reconciled.
