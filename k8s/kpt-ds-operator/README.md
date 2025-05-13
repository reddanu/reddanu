## ADO Pipeline

[![Azure Pipelines](https://img.shields.io/azure-devops/build/CHR-IT/Navisphere/11158?label=build&logo=azure-pipelines)](https://dev.azure.com/CHR-IT/Navisphere/_build?definitionId=11158&_a=summary)

Latest successful build: [Build #1639340](https://dev.azure.com/CHR-IT/Navisphere/_build/results?buildId=1639340&view=results)

https://dev.azure.com/CHR-IT/Navisphere/_build?definitionId=11158&_a=summary


# DaemonSet Kubernetes Toleration Operator

This operator watches a specific DaemonSet in your Kubernetes cluster and ensures that a custom toleration is always present, even after upgrades or patches.

## Problem Statement

When Kubernetes clusters are upgraded or nodepools are patched with different images, custom tolerations on DaemonSets can be wiped out. This is particularly problematic for critical infrastructure components like the vSphere CSI driver that need to run on specific nodes. This operator solves that problem by continuously watching a DaemonSet and ensuring that the specified toleration is always present.

## How It Works

The operator uses the Kubernetes Go client to watch a specific DaemonSet in a namespace. Whenever the DaemonSet is updated, the controller checks if the required toleration is present. If the toleration is missing, the operator automatically adds it back to the DaemonSet.

Key features:
- Focused single-purpose operator that does one thing well
- Resilient to manual changes and upgrades
- Continuous monitoring and enforcement of the desired state
- Low resource footprint

## Installation with Helm

The operator can be installed using Helm. The Helm chart allows for easy configuration and deployment to your Kubernetes cluster.

### Prerequisites

- Kubernetes 1.16+
- Helm 3+

### Installing the Chart

To install the chart with the release name `kpt-ds-csi-operator`:

```bash
helm install kpt-ds-csi-operator .helm \
  --namespace kube-system \
  --set daemonSet.name=vsphere-csi-node \
  --set toleration.key=dedicated \
  --set toleration.value=prometheus \
  --set toleration.effect=NoSchedule
```

For CH Robinson's environments, you can use the provided test installation command:

```bash
make test-install
```

This will install the operator in the `kube-system` namespace of the `eb-reddanu-np-k8s` cluster.

## Configuration

The following table lists the configurable parameters of the kpt-ds-csi-operator chart and their default values:

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `image.repository` | Image repository | `artifactory.chrobinson.com:5005/chr/kpt-ds-csi-operator` |
| `image.tag` | Image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `replicaCount` | Number of operator replicas | `1` |
| `daemonSet.namespace` | Namespace of the DaemonSet to watch | `kube-system` |
| `daemonSet.name` | Name of the DaemonSet to watch | `vsphere-csi-node` |
| `toleration.key` | Toleration key to enforce | `dedicated` |
| `toleration.value` | Toleration value to enforce | `prometheus` |
| `toleration.effect` | Toleration effect to enforce | `NoSchedule` |

## Building and Development

### Setting Up Your Development Environment

```bash
# Install required Go tools
make setup
```

### Running the Operator Locally

```bash
# Build and run the operator locally
make run
```

### Running in Docker

```bash
# Build and run the operator in Docker
make run-docker

# Check the logs
make logs
```

### Building the Docker Image

```bash
# Build the Docker image
make docker
```

## CI/CD Pipeline

The operator uses Azure DevOps pipelines for continuous integration and deployment. The pipeline configuration is in `azure-pipelines.yml`, which:

1. Builds the operator on pull requests and main branch changes
2. Runs tests to ensure the operator functions correctly
3. Publishes the Helm chart to Artifactory
4. Deploys to the appropriate Kubernetes cluster

## Testing

To test the operator:

1. Install the Helm chart using `make test-install`
2. Verify the operator is running
3. Check that the toleration exists on the DaemonSet
4. Remove the toleration manually and watch the operator add it back

```bash
# Check the DaemonSet tolerations
kubectl get daemonset vsphere-csi-node -n kube-system -o jsonpath='{.spec.template.spec.tolerations}' | jq

# Remove the toleration (this will simulate an upgrade removing it)
kubectl patch daemonset vsphere-csi-node -n kube-system --type json \
  -p='[{"op": "remove", "path": "/spec/template/spec.tolerations"}]'

# Check that the toleration was added back by the operator
kubectl get daemonset vsphere-csi-node -n kube-system -o jsonpath='{.spec.template.spec.tolerations}' | jq
```

## Troubleshooting

If the operator isn't functioning as expected:

1. Check the operator logs:
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=kpt-ds-csi-operator
   ```

2. Verify the operator has the necessary RBAC permissions to view and update DaemonSets

3. Ensure the DaemonSet name and namespace match the operator's configuration

## Further Documentation

For more detailed information, see the [documentation](docs/index.md) in the docs directory.
