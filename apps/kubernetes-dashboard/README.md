# kubernetes-dashboard

In order to generate a token for the service-account `cluster-reader`, you have to create the empty secret `cluster-reader-token`. When applied, kubernetes will populate the secret with the necessary token.
After the secret is populated, extract the token and add it to the middleware `kubernetes-dashboard-auth`.

**get service-account token**

```bash
kubectl get secrets -n kubernetes-dashboard -ojsonpath='{.items[?(@.metadata.annotations.kubernetes\.io/service-account\.name == "cluster-reader")].data.token}' | base64 -d
```
