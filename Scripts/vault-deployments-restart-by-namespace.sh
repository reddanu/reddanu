#!/bin/bash

# Set to true for dry-run (no actual restarts), false for real execution
DRY_RUN=false

# Define target namespaces
target_namespaces=(
    "astronomer-astro-load-priority-prod"
    "astronomer-bookitnow-v2-dev"
    "astronomer-bookitnow-v2-prod"
    "astronomer-contractual-po-prod"
    "astronomer-development-tpe"
    "astronomer-main-tpe"
    "astronomer-nastdatadomains-prd"
    "astronomer-visibility-gf-dev"
    "astronomer-visibility-gf-prod"
)

# Get current cluster context
cluster_name=$(kubectl config current-context)
echo "Processing cluster: $cluster_name"
echo "Target namespaces: ${target_namespaces[*]}"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "*** DRY-RUN MODE: No actual restarts will be performed ***"
fi
echo

# Function to restart deployments in specified namespaces
restart_deployments() {
    echo "=== Restarting ALL Deployments ==="
    
    for namespace in "${target_namespaces[@]}"; do
        echo "Checking deployments in namespace: $namespace"
        deployments=$(kubectl get deployments -n "$namespace" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)
        
        if [[ -n "$deployments" ]]; then
            echo "$deployments" | while IFS= read -r name; do
                if [[ -n "$name" ]]; then
                    if [[ "$DRY_RUN" == "true" ]]; then
                        echo "  [DRY-RUN] Would restart deployment: $name in namespace: $namespace"
                    else
                        echo "  Restarting deployment: $name in namespace: $namespace"
                        kubectl rollout restart deployment "$name" -n "$namespace"
                    fi
                fi
            done
        else
            echo "  No deployments found in namespace: $namespace"
        fi
        echo
    done
}

# Function to restart statefulsets in specified namespaces
restart_statefulsets() {
    echo "=== Restarting ALL StatefulSets ==="
    
    for namespace in "${target_namespaces[@]}"; do
        echo "Checking statefulsets in namespace: $namespace"
        statefulsets=$(kubectl get sts -n "$namespace" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)
        
        if [[ -n "$statefulsets" ]]; then
            echo "$statefulsets" | while IFS= read -r name; do
                if [[ -n "$name" ]]; then
                    if [[ "$DRY_RUN" == "true" ]]; then
                        echo "  [DRY-RUN] Would restart statefulset: $name in namespace: $namespace"
                    else
                        echo "  Restarting statefulset: $name in namespace: $namespace"
                        kubectl rollout restart sts "$name" -n "$namespace"
                    fi
                fi
            done
        else
            echo "  No statefulsets found in namespace: $namespace"
        fi
        echo
    done
}

# Main execution
restart_deployments
restart_statefulsets

echo "Restart operations completed for cluster: $cluster_name"