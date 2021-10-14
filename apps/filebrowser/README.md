# filebrowser

## proxy auth

exec into container:

```bash
kubectl exec -ti -n filebrowser $(kubectl get pods -l app=filebrowser -ojsonpath='{..metadata.name}') -- ash
```

create new admin user:

```bash
./filebrowser users add email@gmail.com <PASSWORD> --perm.admin
```

delete database:

```bash
rm -f /db/filebrowser.db
```

create new database:

```bash
./filebrowser config init --auth.method proxy --auth.header X-Forwarded-User -c .filebrowser.json -d /db/filebrowser.db
```

restart deployment:

```bash
kubectl rollout restart deployment -n filebrowser filebrowser
```
