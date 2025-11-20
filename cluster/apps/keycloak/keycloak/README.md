## Envoy RBAC protections

The `block-keycloak-admin-access` patch configures the external listener to deny any `/admin` requests before they ever hit Keycloak. That path remains blocked on `envoy-external`, so if you genuinely need on-cluster access to `/admin` you must route through `envoy-internal` or talk directly to the service.
