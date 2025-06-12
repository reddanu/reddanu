#!/bin/bash

echo "starting restart script with current context"

kubectl cluster-info

skip_deployments=("osrm-routed")

deployments=$(kubectl get deployments --all-namespaces -o jsonpath='{range .items[?(@.spec.template.metadata.annotations.vault\.hashicorp\.com/agent-inject=="true")]}{.metadata.namespace} {.metadata.name}{"\n"}{end}')
echo '########'
echo "${deployments}"

# Iterate over deployments
echo "$deployments" | while IFS= read -r deployment_info; do
    echo
    namespace=$(echo "$deployment_info" | awk '{print $1}')
    deployment_name=$(echo "$deployment_info" | awk '{print $2}')
    
    # Check if deployment is in the skip list
    if [[ " ${skip_deployments[@]} " =~ " ${deployment_name} " ]]; then
        echo "Skipping deployment: $deployment_name"
        continue
    fi
    
    echo "Processing deployment: $deployment_name in namespace: $namespace"
    
    # Uncomment the following line to actually restart the deployment
    kubectl rollout restart deployment "$deployment_name" -n "$namespace"
    # sleep 1
done