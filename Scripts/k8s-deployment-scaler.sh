#!/bin/bash

# k8s-deployment-scaler.sh
# Script to scale down deployments in a namespace and scale them back up to original values
# Usage: 
#   Scale down: ./k8s-deployment-scaler.sh down <namespace>
#   Scale up:   ./k8s-deployment-scaler.sh up <namespace>

set -e

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed or not in PATH"
    exit 1
fi

# Display usage information
function show_usage() {
    echo "Usage: $0 [down|up] <namespace>"
    echo ""
    echo "  down    - Scale down all deployments in the namespace to 0 replicas, saving original counts"
    echo "  up      - Scale up all deployments to their original replica counts"
    echo ""
    echo "Example:"
    echo "  $0 down my-namespace"
    echo "  $0 up my-namespace"
    exit 1
}

# Validate parameters
if [ $# -ne 2 ]; then
    show_usage
fi

ACTION=$1
NAMESPACE=$2
BACKUP_FILE="/tmp/deployment-replicas-${NAMESPACE}.json"

# Verify the namespace exists
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "Error: Namespace '$NAMESPACE' does not exist"
    exit 1
fi

# Scale down all deployments in the namespace
scale_down() {
    echo "Scaling down all deployments in namespace '$NAMESPACE'..."
    
    # Get all deployments in the namespace
    DEPLOYMENTS=$(kubectl -n "$NAMESPACE" get deployments -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$DEPLOYMENTS" ]; then
        echo "No deployments found in namespace '$NAMESPACE'"
        exit 0
    fi
    
    # Create a JSON file to store the original replica counts
    echo "{" > "$BACKUP_FILE"
    
    # Loop through each deployment and save its replica count
    FIRST=true
    for DEPLOYMENT in $DEPLOYMENTS; do
        REPLICAS=$(kubectl -n "$NAMESPACE" get deployment "$DEPLOYMENT" -o jsonpath='{.spec.replicas}')
        
        if [ "$FIRST" = true ]; then
            FIRST=false
        else
            echo "," >> "$BACKUP_FILE"
        fi
        
        echo "  \"$DEPLOYMENT\": $REPLICAS" >> "$BACKUP_FILE"
        
        # Scale down the deployment to 0
        echo "Scaling down deployment '$DEPLOYMENT' from $REPLICAS to 0 replicas"
        kubectl -n "$NAMESPACE" scale deployment "$DEPLOYMENT" --replicas=0
    done
    
    echo "}" >> "$BACKUP_FILE"
    echo "Original deployment replica counts saved to $BACKUP_FILE"
    echo "All deployments in namespace '$NAMESPACE' have been scaled down to 0"
}

# Scale up all deployments to their original replica counts
scale_up() {
    echo "Scaling up deployments in namespace '$NAMESPACE'..."
    
    # Check if the backup file exists
    if [ ! -f "$BACKUP_FILE" ]; then
        echo "Error: Backup file '$BACKUP_FILE' not found"
        echo "Cannot restore deployments without the backup file"
        exit 1
    fi
    
    # Read the deployments and their replica counts from the backup file
    while read -r LINE; do
        if [[ "$LINE" =~ \"([^\"]+)\"\:\ ([0-9]+) ]]; then
            DEPLOYMENT="${BASH_REMATCH[1]}"
            REPLICAS="${BASH_REMATCH[2]}"
            
            # Check if the deployment exists
            if kubectl -n "$NAMESPACE" get deployment "$DEPLOYMENT" &> /dev/null; then
                echo "Scaling up deployment '$DEPLOYMENT' to $REPLICAS replicas"
                kubectl -n "$NAMESPACE" scale deployment "$DEPLOYMENT" --replicas="$REPLICAS"
            else
                echo "Warning: Deployment '$DEPLOYMENT' no longer exists, skipping"
            fi
        fi
    done < <(grep -o '"[^"]\+": [0-9]\+' "$BACKUP_FILE")
    
    echo "All deployments in namespace '$NAMESPACE' have been scaled up to their original replica counts"
}

# Execute the requested action
case "$ACTION" in
    down)
        scale_down
        ;;
    up)
        scale_up
        ;;
    *)
        echo "Error: Invalid action '$ACTION'"
        show_usage
        ;;
esac

exit 0