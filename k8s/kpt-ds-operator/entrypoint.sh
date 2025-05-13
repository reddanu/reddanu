#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

if [ $# -gt 0 ]; then
    echo "Running overridden command '$*'."
    exec "$@"
else
    echo "Starting kpt-ds-csi-operator"
    exec /bin/main \
      --namespace=kube-system \
      --daemonset=vsphere-csi-node \
      --toleration-key=dedicated \
      --toleration-value=prometheus \
      --toleration-effect=NoSchedule
fi