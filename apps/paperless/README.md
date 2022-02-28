# paperless

create new user:

```bash
kubectl exec -ti -n paperless deployments/paperless -- python ./manage.py createsuperuser
```
