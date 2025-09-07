# Miracle

Create http basic auth secret

```bash
printf "%s\n" "$(htpasswd -nb admin 'yourpassword')" | base64 -w0
```
