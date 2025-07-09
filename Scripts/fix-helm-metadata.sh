#!/bin/bash
set -e

# Script to fix Helm ownership metadata on existing Kubernetes resources
# This script adds required Helm labels and annotations to existing resources
# so they can be managed by Helm in subsequent deployments

# Default values
NAMESPACE="int-orders"
DEPLOYMENT_NAME="orders-14008-locationcurator"
RELEASE_NAME="orders-14008-locationcurator"
RELEASE_NAMESPACE="int-orders"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -n|--namespace)
      NAMESPACE="$2"
      shift
      shift
      ;;
    -d|--deployment)
      DEPLOYMENT_NAME="$2"
      shift
      shift
      ;;
    -r|--release-name)
      RELEASE_NAME="$2"
      shift
      shift
      ;;
    -rn|--release-namespace)
      RELEASE_NAMESPACE="$2"
      shift
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "=== Fixing Helm metadata for deployment '$DEPLOYMENT_NAME' in namespace '$NAMESPACE' ==="
echo "- Setting release name: $RELEASE_NAME"
echo "- Setting release namespace: $RELEASE_NAMESPACE"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
  echo "Error: kubectl is not installed or not in PATH"
  exit 1
fi

# Check if the deployment exists
if ! kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" &> /dev/null; then
  echo "Error: Deployment '$DEPLOYMENT_NAME' not found in namespace '$NAMESPACE'"
  exit 1
fi

# Add Helm managed-by label and required annotations to the deployment
echo "Adding Helm labels and annotations to deployment..."
kubectl label deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" "app.kubernetes.io/managed-by=Helm" --overwrite
kubectl annotate deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" "meta.helm.sh/release-name=$RELEASE_NAME" --overwrite
kubectl annotate deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" "meta.helm.sh/release-namespace=$RELEASE_NAMESPACE" --overwrite

# Check for related resources that might need the same labels/annotations
# For each resource type, we'll look for items with the same name prefix
echo "Checking for related resources with the same name prefix..."

# Function to fix labels and annotations for a resource
fix_resource() {
  local resource_type=$1
  local resource_name=$2
  
  echo "  - Fixing $resource_type/$resource_name"
  kubectl label "$resource_type" "$resource_name" -n "$NAMESPACE" "app.kubernetes.io/managed-by=Helm" --overwrite
  kubectl annotate "$resource_type" "$resource_name" -n "$NAMESPACE" "meta.helm.sh/release-name=$RELEASE_NAME" --overwrite
  kubectl annotate "$resource_type" "$resource_name" -n "$NAMESPACE" "meta.helm.sh/release-namespace=$RELEASE_NAMESPACE" --overwrite
}

# List of common resource types to check
resource_types=("service" "configmap" "secret" "serviceaccount" "ingress")

# Loop through resource types and fix any that match our deployment name
for resource_type in "${resource_types[@]}"; do
  echo "Checking for $resource_type resources related to $DEPLOYMENT_NAME..."
  
  # Get resources of this type in the namespace
  resources=$(kubectl get "$resource_type" -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
  
  # Loop through resources and fix those that match our deployment name
  for resource in $resources; do
    if [[ "$resource" == "$DEPLOYMENT_NAME"* ]]; then
      fix_resource "$resource_type" "$resource"
    fi
  done
done

echo "Done! The deployment and related resources now have the required Helm metadata."
echo "You should now be able to proceed with your Helm deployment."
