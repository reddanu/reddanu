#!/bin/bash
set -e

# Handle multiple resources across different namespaces
declare -A NAMESPACES
NAMESPACES=( 
  ["int-executionintegration"]="executionintegration-13717-execution-integ"
  ["trn-executionintegration"]="executionintegration-13717-execution-integ"
  ["prd-executionintegration"]="executionintegration-13717-execution-integ"
  ["dev-executionintegration"]="executionintegration-13717-execution-integ"
)

# Functions for resource handling
update_resource() {
  local RESOURCE_TYPE=$1
  local RESOURCE_NAME=$2
  local NAMESPACE=$3
  local RELEASE_NAME=$4
  
  echo "Updating $RESOURCE_TYPE '$RESOURCE_NAME' in namespace '$NAMESPACE'..."
  
  # Check if resource exists
  if ! kubectl get $RESOURCE_TYPE $RESOURCE_NAME -n $NAMESPACE &>/dev/null; then
    echo "⚠️ $RESOURCE_TYPE '$RESOURCE_NAME' not found in namespace '$NAMESPACE', skipping"
    return 1
  fi
  
  # Add required annotations
  echo "  - Adding annotations..."
  kubectl annotate $RESOURCE_TYPE $RESOURCE_NAME -n $NAMESPACE \
    meta.helm.sh/release-name=$RELEASE_NAME \
    meta.helm.sh/release-namespace=$NAMESPACE \
    --overwrite
  
  # Add required labels
  echo "  - Adding labels..."
  kubectl label $RESOURCE_TYPE $RESOURCE_NAME -n $NAMESPACE \
    app.kubernetes.io/managed-by=Helm \
    --overwrite
  
  # Verify the resource has the expected metadata
  verify_resource $RESOURCE_TYPE $RESOURCE_NAME $NAMESPACE
  
  return 0
}

verify_resource() {
  local RESOURCE_TYPE=$1
  local RESOURCE_NAME=$2
  local NAMESPACE=$3
  
  echo "  - Verifying $RESOURCE_TYPE metadata..."
  
  # Get annotations and check for required keys
  local ANNOTATIONS=$(kubectl get $RESOURCE_TYPE $RESOURCE_NAME -n $NAMESPACE -o jsonpath="{.metadata.annotations}")
  if [[ $ANNOTATIONS != *"meta.helm.sh/release-name"* ]]; then
    echo "    ❌ Annotation 'meta.helm.sh/release-name' is missing!"
    HAS_ERROR=true
  fi
  
  if [[ $ANNOTATIONS != *"meta.helm.sh/release-namespace"* ]]; then
    echo "    ❌ Annotation 'meta.helm.sh/release-namespace' is missing!"
    HAS_ERROR=true
  fi
  
  # Get labels and check for required keys
  local LABELS=$(kubectl get $RESOURCE_TYPE $RESOURCE_NAME -n $NAMESPACE -o jsonpath="{.metadata.labels}")
  if [[ $LABELS != *"app.kubernetes.io/managed-by"* ]]; then
    echo "    ❌ Label 'app.kubernetes.io/managed-by' is missing!"
    HAS_ERROR=true
  fi
  
  if [ "$HAS_ERROR" = true ]; then
    echo "    ⚠️ Some metadata is still missing. Trying alternate approach..."
    
    # Direct patch approach as a fallback
    echo "    - Applying direct JSON patch..."
    
    # Create a patch file
    cat > patch.yaml <<EOF
metadata:
  annotations:
    meta.helm.sh/release-name: $RELEASE_NAME
    meta.helm.sh/release-namespace: $NAMESPACE
  labels:
    app.kubernetes.io/managed-by: Helm
EOF
    
    # Apply the patch
    kubectl patch $RESOURCE_TYPE $RESOURCE_NAME -n $NAMESPACE --patch-file patch.yaml
    
    # Clean up
    rm patch.yaml
    
    # Verify again
    echo "    - Re-verifying metadata..."
    local ANNOTATIONS=$(kubectl get $RESOURCE_TYPE $RESOURCE_NAME -n $NAMESPACE -o jsonpath="{.metadata.annotations}")
    local LABELS=$(kubectl get $RESOURCE_TYPE $RESOURCE_NAME -n $NAMESPACE -o jsonpath="{.metadata.labels}")
    
    if [[ $ANNOTATIONS == *"meta.helm.sh/release-name"* ]] && 
       [[ $ANNOTATIONS == *"meta.helm.sh/release-namespace"* ]] && 
       [[ $LABELS == *"app.kubernetes.io/managed-by"* ]]; then
      echo "    ✅ Patch successful!"
    else
      echo "    ❌ Failed to apply metadata even with patch method!"
    fi
  else
    echo "    ✅ $RESOURCE_TYPE metadata verified successfully!"
  fi
}

# Main processing logic
for NAMESPACE in "${!NAMESPACES[@]}"; do
  RELEASE_NAME=${NAMESPACES[$NAMESPACE]}
  INGRESS_NAME=$RELEASE_NAME
  SERVICE_NAME=$RELEASE_NAME
  HAS_ERROR=false
  
  echo "===================================================="
  echo "Processing namespace: $NAMESPACE"
  echo "===================================================="
  
  # Update Ingress
  update_resource "ingress" $INGRESS_NAME $NAMESPACE $RELEASE_NAME
  
  # Update Service
  update_resource "service" $SERVICE_NAME $NAMESPACE $RELEASE_NAME
  
  echo ""
  echo "Detailed verification for namespace $NAMESPACE:"
  
  # Show detailed output for verification
  if kubectl get ingress $INGRESS_NAME -n $NAMESPACE &>/dev/null; then
    echo "Ingress annotations:"
    kubectl get ingress $INGRESS_NAME -n $NAMESPACE -o jsonpath="{.metadata.annotations}" | jq .
    echo "Ingress labels:"
    kubectl get ingress $INGRESS_NAME -n $NAMESPACE -o jsonpath="{.metadata.labels}" | jq .
  fi
  
  if kubectl get service $SERVICE_NAME -n $NAMESPACE &>/dev/null; then
    echo "Service annotations:"
    kubectl get service $SERVICE_NAME -n $NAMESPACE -o jsonpath="{.metadata.annotations}" | jq .
    echo "Service labels:"
    kubectl get service $SERVICE_NAME -n $NAMESPACE -o jsonpath="{.metadata.labels}" | jq .
  fi
  
  echo ""
done

echo "Done! All resources should now be properly managed by Helm."
echo "If you still encounter issues, please try your Helm operation with the --force flag:"
echo "helm upgrade --install --force [your-other-options] [release-name] [chart]"