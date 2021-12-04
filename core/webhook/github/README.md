# webhook receivers

The notification controller generates a unique URL using the provided token and the receiver name/namespace.

Find the URL with:

```bash
kubectl get receivers/flux-system --namespace flux-system
```

output:

```console
NAME          READY   STATUS                                                                                                  AGE
flux-system   True    Receiver initialized with URL: /hook/bed6d00b5555b1603e1f59b94d7fdbca58089cb5663633fb83f2815dc626d92b   140m
```

On GitHub, navigate to your repository and click on the "Add webhook" button under "Settings/Webhooks". Fill the form with:

- **Payload URL**: compose the address using the receiver ingress and the generated URL http://<flux-webhook.${BASE_DOMAIN}>/<ReceiverURL>
- **Secret**: use the token string

With the above settings, when you push a commit to the repository, the following happens:

- GitHub sends the Git push event to the receiver address
- Notification controller validates the authenticity of the payload using HMAC
- Source controller is notified about the changes
- Source controller pulls the changes into the cluster and updates the `GitRepository` revision
- Kustomize controller is notified about the revision change
- Kustomize controller reconciles all the `Kustomizations` that reference the `GitRepository` object

stolen from [here](https://fluxcd.io/docs/guides/webhook-receivers/#define-a-git-repository-receiver)
