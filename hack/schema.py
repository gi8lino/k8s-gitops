import os
import re
from dataclasses import dataclass


@dataclass
class Schema:
    api_version: str
    kind: str
    schema: str


schemas = [
    Schema(
        api_version="apps/v1",
        kind="Deployment",
        schema="https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/master-standalone/deployment-v1.json",
    ),
    Schema(
        api_version="apps/v1",
        kind="StatefulSet",
        schema="https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/master-standalone/statefulset-v1.json",
    ),
    Schema(
        api_version="apps/v1",
        kind="DaemonSet",
        schema="https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/master-standalone/daemonset-v1.json",
    ),
    Schema(
        api_version="v1",
        kind="Service",
        schema="https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/master-standalone/service-v1.json",
    ),
    Schema(
        api_version="v1",
        kind="ConfigMap",
        schema="https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/master-standalone/configmap-v1.json"
    ),
    Schema(
        api_version="networking.k8s.io/v1",
        kind="Ingress",
        schema="https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/master-standalone/ingress-v1.json"
    ),
    Schema(
        api_version="v1",
        kind="PersistentVolumeClaim",
        schema="https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/master-standalone/persistentvolumeclaim-v1.json"
    ),
    Schema(
        api_version="batch/v1",
        kind="CronJob",
        schema="https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/master-standalone/cronjob-batch-v1.json"
    ),
    Schema(
        api_version="kustomize.config.k8s.io/v1beta1",
        kind="Kustomization",
        schema="https://json.schemastore.org/kustomization",
    ),
    Schema(
        api_version="cilium.io/v2",
        kind="CiliumNetworkPolicy",
        schema="https://kubernetes-schemas.pages.dev/cilium.io/ciliumnetworkpolicy_v2.json",
    ),
    Schema(
        api_version="cilium.io/v2",
        kind="CiliumClusterwideNetworkPolicy",
        schema="https://kubernetes-schemas.pages.dev/cilium.io/ciliumclusterwidenetworkpolicy_v2.json",
    ),
    Schema(
        api_version="kustomize.toolkit.fluxcd.io/v1",
        kind="Kustomization",
        schema="https://kubernetes-schemas.pages.dev/kustomize.toolkit.fluxcd.io/kustomization_v1.json",
    ),
    Schema(
        api_version="helm.toolkit.fluxcd.io/v2beta2",
        kind="HelmRelease",
        schema="https://kubernetes-schemas.pages.dev/helm.toolkit.fluxcd.io/helmrelease_v2beta2.json",
    ),
    Schema(
        api_version="source.toolkit.fluxcd.io/v1beta2",
        kind="GitRepository",
        schema="https://kubernetes-schemas.pages.dev/source.toolkit.fluxcd.io/gitrepository_v1beta2.json",
    ),
    Schema(
        api_version="source.toolkit.fluxcd.io/v1beta2",
        kind="HelmRepository",
        schema="https://kubernetes-schemas.pages.dev/source.toolkit.fluxcd.io/helmrepository_v1beta2.json",
    ),
    Schema(
        api_version="notification.toolkit.fluxcd.io/v1beta2",
        kind="Alert",
        schema="https://kubernetes-schemas.pages.dev/notification.toolkit.fluxcd.io/alert_v1beta2.json",
    ),
    Schema(
        api_version="notification.toolkit.fluxcd.io/v1beta2",
        kind="Provider",
        schema="https://kubernetes-schemas.pages.dev/notification.toolkit.fluxcd.io/provider_v1beta1.json",
    ),
    Schema(
        api_version="notification.toolkit.fluxcd.io/v1beta1",
        kind="Receiver",
        schema="https://kubernetes-schemas.pages.dev/notification.toolkit.fluxcd.io/receiver_v1beta1.json",
    ),
    Schema(
        api_version="monitoring.coreos.com/v1",
        kind="Podmonitor",
        schema="https://kubernetes-schemas.pages.dev/monitoring.coreos.com/podmonitor_v1.json",
    ),
    Schema(
        api_version="monitoring.coreos.com/v1",
        kind="ServiceMonitor",
        schema="https://kubernetes-schemas.pages.dev/monitoring.coreos.com/servicemonitor_v1.json",
    ),
    Schema(
        api_version="monitoring.coreos.com/v1",
        kind="PrometheusRule",
        schema="https://kubernetes-schemas.pages.dev/monitoring.coreos.com/prometheusrule_v1.json",
    ),
    Schema(
        api_version="cert-manager.io/v1",
        kind="Certificate",
        schema="https://kubernetes-schemas.pages.dev/cert-manager.io/certificate_v1.json",
    ),
    Schema(
        api_version="cert-manager.io/v1",
        kind="ClusterIssuer",
        schema="https://kubernetes-schemas.pages.dev/cert-manager.io/clusterissuer_v1.json",
    ),
    Schema(
        api_version="traefik.containo.us/v1alpha1",
        kind="IngressRouteTCP",
        schema="https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/traefik.containo.us/ingressroutetcp_v1alpha1.json"
    ),
    Schema(
        api_version="traefik.containo.us/v1alpha1",
        kind="Middleware",
        schema="https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/traefik.containo.us/middlevare_v1alpha1.json"
    ),
]


def insert_schema_in_file(file_path):
    with open(file_path, 'r+', encoding='utf-8') as file:
        content = file.read()
        updated_content = content

        for item in schemas:
            pattern = re.compile(
                r'---\n' +
                r'apiVersion: ' + re.escape(item.api_version) + '\n'
                r'kind: ' + re.escape(item.kind)
            )
            if pattern.search(content):
                print("Inserting schema for "
                      f"{item.api_version} in {file_path}")
                # Insert the schema after the pattern match
                updated_content = pattern.sub(
                    r'---\n' +
                    r'# yaml-language-server: $schema=' + item.schema + '\n' +
                    r'apiVersion: ' + item.api_version + '\n' +
                    r'kind: ' + item.kind, updated_content
                )

        if updated_content != content:
            file.seek(0)
            file.write(updated_content)
            file.truncate()


# Walk through the directory tree
for root, dirs, files in os.walk("."):
    for file in files:
        if file.endswith(".yaml"):
            insert_schema_in_file(os.path.join(root, file))

print("Schema insertion complete.")
