# filebrowser

## proxy auth

exec into container:

```bash
kubectl exec -ti -n filebrowser deployments/filebrowser -- ash
```

delete database:

```bash
rm -f /db/filebrowser.db
```

create new database:

```bash
./filebrowser config import /config/settings.json
```

import users:

```bash
./filebrowser users import .users.json
```

restart deployment:

```bash
kubectl rollout restart deployment -n filebrowser filebrowser
```

### Headers

| Proxy   | Header               |
| :------ | :------------------- |
| nginx   | X-Auth-Request-Email |
| traefik | X-Forwarded-User     |
