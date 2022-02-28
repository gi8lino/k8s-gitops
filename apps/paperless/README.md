# paperless

create new user:

```bash
kubectl exec -ti -n paperless \
  $(kubectl get \
    pods \
    --namespace paperless \
    --selector app.kubernetes.io/name=paperless \
    --field-selector=status.phase=Running \
    --output jsonpath='{.items..metadata.name}') -- python ./manage.py createsuperuser
```
