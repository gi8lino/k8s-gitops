## Envoy extension protections

The `disable-direct-login` Lua extension policy redirects any `/login?all=*` requests that hit the `wiki` HTTPRoute back to `https://wiki.${BASE_DOMAIN}`, so those direct login attempts are blocked at the Gateway before reaching the wiki pod.

## Envoy extension protections

The `disable-direct-login` Lua extension intercepts requests to `/login/all=*` and redirects them back to `https://wiki.${BASE_DOMAIN}`, so direct login attempts from the Gateway are blocked before hitting the application.
