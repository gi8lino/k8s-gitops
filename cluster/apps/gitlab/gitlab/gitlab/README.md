## Envoy RBAC protections

The `block-gitlab-admin-access` patch configures the external listener to deny any `/admin` requests before they ever hit Gitlab. That path remains blocked on `envoy-external`, so if you genuinely need on-cluster access to `/admin` you must route through `envoy-internal` or talk directly to the service.

## Envoy extension protections

The `disable-direct-login` Lua extension intercepts requests to `/users/sign_in?auto_sign_in=false` and redirects them back to `https://git.${BASE_DOMAIN}`, so direct login attempts from the Gateway are blocked before hitting the application.

# Garage buckets

GitLab uses the in-cluster Garage S3 endpoint at `http://gitlab-garage.gitlab.svc.cluster.local:3900`.
The GitLab release currently reads credentials from these secrets:

- `gitlab-object-storage` for the Rails object store config
- `gitlab-object-storage-s3cmd` for toolbox backups
- `gitlab-registry-storage` for the container registry

At the moment the Helm values explicitly reference these buckets:

- `registry`
- `gitlab-dependency-proxy`

If you add another bucket-backed GitLab feature, create the bucket in Garage first and then update the matching GitLab secret or Helm value.

## Add a bucket and access key

The easiest way to manage Garage is from inside the Garage pod:

```bash
kubectl -n gitlab exec -it statefulset/gitlab-garage -- sh
```

Create the bucket:

```bash
garage bucket create <bucket-name>
```

Create a dedicated access key for GitLab or for the specific feature you are wiring up:

```bash
garage key new --name <key-name>
```

Save the generated access key id and secret key immediately. Garage only prints the secret once.

Grant the key access to the bucket:

```bash
garage bucket allow \
  --bucket <bucket-name> \
  --key <access-key-id> \
  --read \
  --write \
  --owner
```

You can verify the final permissions with:

```bash
garage bucket info <bucket-name>
garage key info <access-key-id>
```

## Update the GitLab secrets

All GitLab storage credentials for this app live in [secret.yaml](/Users/qiwi/hq/k8s-gitops/cluster/apps/gitlab/gitlab/gitlab/secret.yaml).
After generating a new Garage access key, replace the credentials in the relevant secret entries and re-encrypt with `sops`.

For the shared Rails object store secret (`gitlab-object-storage`), the config format is:

```yaml
stringData:
  config: |
    provider: AWS
    region: garage
    aws_access_key_id: <access-key-id>
    aws_secret_access_key: <secret-key>
    endpoint: "http://gitlab-garage.gitlab.svc.cluster.local:3900"
    path_style: true
```

For toolbox backup uploads (`gitlab-object-storage-s3cmd`), use:

```ini
[default]
access_key = <access-key-id>
secret_key = <secret-key>
host_base = gitlab-garage.gitlab.svc.cluster.local:3900
host_bucket = gitlab-garage.gitlab.svc.cluster.local:3900
use_https = False
```

For registry storage (`gitlab-registry-storage`), use:

```yaml
stringData:
  config: |
    s3:
      v4auth: true
      regionendpoint: "http://gitlab-garage.gitlab.svc.cluster.local:3900"
      pathstyle: true
      region: garage
      bucket: <bucket-name>
      accesskey: <access-key-id>
      secretkey: <secret-key>
```

If you are rotating credentials for an existing bucket, update every secret that still references the old key pair before reconciling Flux.
