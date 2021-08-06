#!/usr/bin/env bash
set -ex

# Running on preview as every probable namespace should be here.

for namespace in $(kubectl get ns -A -o jsonpath={.items[*].metadata.name} | xargs -n1 | sort -u | xargs); do
  
if [[ $namespace == "kube-"* ]] || [[ $namespace == "default" ]]; 
then
  echo "skipping $namespace"
  continue
fi

if [ ! -f "apps/$namespace/base/kustomize.yaml" ]
then
    echo "Creating $namespace"
    mkdir -p apps/$namespace
    mkdir -p apps/$namespace/base

SLACK_CHANNEL=$(kubectl get ns $namespace -o jsonpath={.metadata.labels.slackChannel})
if [ -z "$SLACK_CHANNEL" ]
then
SLACK_CHANNEL="\${ENV_MONITOR_CHANNEL}"
fi
    
(
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
namespace: $namespace
patches:
  - path: ../../base/helmrelease-default.yaml
    target:
      kind: HelmRelease
EOF
) > "apps/$namespace/base/kustomization.yaml"

(
cat <<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1beta1
kind: Kustomization
metadata:
  name: $namespace
  namespace: flux-system
spec:
  interval: 1m0s
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-config
    namespace: flux-system
  validation: none
  path: ./apps/$namespace/\${ENVIRONMENT}
  postBuild:
    substitute:
      NAMESPACE: "$namespace"
      TEAM_NOTIFICATION_CHANNEL: "${SLACK_CHANNEL}"
      CLUSTER_FULL_NAME: "\${ENVIRONMENT}-\${CLUSTER}"
      KEYVAULT_ENVIRONMENT: "\${KEYVAULT_ENVIRONMENT}"
EOF
) > "apps/$namespace/base/kustomize.yaml"

fi

done