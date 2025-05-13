#!/bin/bash

# List of subscription IDs
subscriptions=("subscription_id_1" "subscription_id_2" "subscription_id_3")

# Loop through each subscription
for subscription_id in "${subscriptions[@]}"; do
    echo "Processing subscription: $subscription_id"
    az account set --subscription "$subscription_id"
    
    # Get the list of AKS clusters in the subscription
    clusters=$(az aks list --query '[].{name:name, resourceGroup:resourceGroup}' -o tsv)
    
    # Loop through each cluster and get the kubeconfig
    while IFS=$'\t' read -r cluster_name resource_group; do
        echo "Found AKS cluster: $cluster_name in resource group: $resource_group"
        az aks get-credentials --resource-group "$resource_group" --name "$cluster_name"
        echo "Kubeconfig for cluster $cluster_name added to kubeconfig."
    done <<< "$clusters"
done

echo "All AKS clusters have been added to your kubeconfig."