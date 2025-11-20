## Envoy RBAC protections

The `block-nextcloud-admin-access` patch configures the external listener to deny any `/settings/admin` requests before they ever hit Nextcloud. That path remains blocked on `envoy-external`, so if you genuinely need on-cluster access to `/settings/admin` you must route through `envoy-internal` or talk directly to the service.

## Envoy extension protections

The `disable-direct-login` Lua extension intercepts requests to `/login?direct=1` and redirects them back to `https://cloud.${BASE_DOMAIN}`, so direct login attempts from the Gateway are blocked before hitting the application.
