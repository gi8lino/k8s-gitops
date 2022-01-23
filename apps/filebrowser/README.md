# filebrowser

## proxy auth

exec into container:

```bash
kubectl exec -ti -n filebrowser $(kubectl get pods -l app=filebrowser -ojsonpath='{..metadata.name}') -- ash
```

delete database:

```bash
rm -f /db/filebrowser.db
```

create new database:

```bash
./filebrowser config init --auth.method proxy --auth.header X-Authentik-Email -c .filebrowser.json -d /db/filebrowser.db
```

create new admin user:

```bash
./filebrowser users add email@gmail.com <PASSWORD> --perm.admin
```

restart deployment:

```bash
kubectl rollout restart deployment -n filebrowser filebrowser
```
