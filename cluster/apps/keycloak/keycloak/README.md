# Keycloak

Keycloak provides the `hq` application realm and serves both the internal and
external `sso.${BASE_DOMAIN}` routes.

## External Access Controls

The `block-admin-page` `EnvoyExtensionPolicy` targets only the
`keycloak-external` HTTPRoute. Its Lua filter is stored in
`scripts/block-external-admin-access.lua`, generated as the
`keycloak-block-admin` ConfigMap, and referenced by the policy with a
`ValueRef`.

The external route returns the custom `403` page for:

- `/admin` and all paths below it;
- `/realms/master` and all paths below it.

This prevents internet access to both the Keycloak administration console and
the `master` realm's endpoints before a request reaches Keycloak. The policy is
not attached to `keycloak-internal`, so server administration remains available
through the internal gateway or by connecting directly to the Keycloak service.

The `hq` realm remains externally available for application authentication and
the account console. Requests to the SSO root are redirected to
`/realms/hq/account`.
