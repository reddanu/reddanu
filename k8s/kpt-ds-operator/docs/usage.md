# Usage Guide

This guide explains how to deploy and use the DaemonSet Toleration Operator.

## Deployment Options

The operator can be deployed using either Helm or direct Kubernetes manifests.

### Option 1: Deploy with Helm (Recommended)

```bash
# Add the Helm repository (replace with your actual repository URL)
helm repo add chr https://artifactory.chrobinson.com/artifactory/helm/

# Update your Helm repositories
helm repo update

# Install the chart
helm install kpt-ds-csi-operator chr/kpt-ds-csi-operator \
  --namespace kube-system \
  --set daemonSet.name=vsphere-csi-node \
  --set toleration.key=dedicated \
  --set toleration.value=prometheus \
  --set toleration.effect=NoSchedule
```

### Option 2: Deploy with kubectl

```bash
# Apply the deployment manifest
kubectl apply -f https://raw.githubusercontent.com/ch-robinson-internal/kpt-ds-csi-operator/main/deploy/deployment.yaml
```

## Configuration

The operator can be configured using either command-line arguments or a config file.

### Command-Line Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `--namespace` | Namespace of the DaemonSet to watch | `kube-system` |
| `--daemonset` | Name of the DaemonSet to watch | `vsphere-csi-node` |
| `--toleration-key` | Toleration key to enforce | `dedicated` |
| `--toleration-value` | Toleration value to enforce | `prometheus` |
| `--toleration-effect` | Toleration effect to enforce | `NoSchedule` |

### Example

```bash
./operator --namespace=kube-system --daemonset=vsphere-csi-node --toleration-key=dedicated --toleration-value=prometheus --toleration-effect=NoSchedule
```

## Verification

To verify that the operator is working correctly:

1. Check that the operator pod is running:

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=kpt-ds-csi-operator
```

2. Remove the toleration from the DaemonSet to test:

```bash
kubectl patch daemonset vsphere-csi-node -n kube-system --type json \
  -p='[{"op": "remove", "path": "/spec/template/spec/tolerations", "value": []}]'
```

3. Verify that the toleration is automatically restored:

```bash
kubectl get daemonset vsphere-csi-node -n kube-system -o jsonpath='{.spec.template.spec.tolerations}' | jq
```

## Troubleshooting

If the operator is not functioning as expected, check the operator logs:

```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=kpt-ds-csi-operator
```

Common issues:

- RBAC permissions: Ensure the operator's service account has the necessary permissions to read and update DaemonSets.
- Namespace/DaemonSet not found: Verify that the specified namespace and DaemonSet exist.
- Connection issues: Check if the operator can connect to the Kubernetes API server.