#!/bin/bash
# Restart all deployments across all namespaces efficiently

echo "Restarting all deployments across all namespaces..."

# Get all deployments across all namespaces and restart them
kubectl get deployments --all-namespaces --no-headers -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name | while read ns name; do
    echo "Restarting deployment $name in namespace $ns"
    kubectl rollout restart deployment/$name -n $ns
done

kubectl get statefulsets --all-namespaces --no-headers -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name | while read ns name; do
    echo "Restarting statefulset $name in namespace $ns"
    kubectl rollout restart statefulset/$name -n $ns
done

echo "All deployments restart initiated!"
echo "Use 'kubectl get deployments --all-namespaces' to check status"
echo "Use 'kubectl get statefulsets --all-namespaces' to check status"
echo "Done!"