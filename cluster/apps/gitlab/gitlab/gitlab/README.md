## Envoy RBAC protections

The `block-gitlab-admin-access` patch configures the external listener to deny any `/admin` requests before they ever hit Gitlab. That path remains blocked on `envoy-external`, so if you genuinely need on-cluster access to `/admin` you must route through `envoy-internal` or talk directly to the service.

## Envoy extension protections

The `disable-direct-login` Lua extension intercepts requests to `/users/sign_in?auto_sign_in=false` and redirects them back to `https://git.${BASE_DOMAIN}`, so direct login attempts from the Gateway are blocked before hitting the application.
