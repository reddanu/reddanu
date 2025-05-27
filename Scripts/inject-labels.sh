#!/bin/bash

# Script to inject labels into Kubernetes namespaces
# Labels to be added: ako-gslb: enabled, avioperator: "3"

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_usage() {
    echo -e "${YELLOW}Usage: $0 <namespace>${NC}"
    echo -e "This script adds required labels to an existing namespace in all appropriate clusters"
    echo -e "Example: $0 my-application-namespace"
}

apply_labels() {
    local cluster=$1
    local namespace=$2
    
    echo -e "${BLUE}Applying labels to namespace ${namespace} in cluster ${cluster}...${NC}"
    
    # Check if we can connect to the cluster
    if ! kubectl config use-context "${cluster}" &>/dev/null; then
        echo -e "${RED}Error: Cannot connect to cluster ${cluster}${NC}"
        return 1
    fi
    
    # Check if namespace exists
    if ! kubectl get namespace "${namespace}" &>/dev/null; then
        echo -e "${RED}Namespace ${namespace} does not exist in cluster ${cluster}. Skipping...${NC}"
        return 1
    fi
    
    # Apply the labels
    kubectl label namespace "${namespace}" ako-gslb=enabled avioperator="3" --overwrite
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully applied labels to namespace ${namespace} in cluster ${cluster}${NC}"
    else
        echo -e "${RED}Failed to apply labels to namespace ${namespace} in cluster ${cluster}${NC}"
        return 1
    fi
    
    return 0
}

# Main script
if [ $# -ne 1 ]; then
    print_usage
    exit 1
fi

NAMESPACE=$1

echo -e "${BLUE}Adding labels to namespace ${NAMESPACE} across all relevant clusters${NC}"
echo -e "${BLUE}Labels to be added: ako-gslb: enabled, avioperator: \"3\"${NC}"

# Apply to all the relevant clusters based on requirements
echo -e "\n${YELLOW}Processing development and integration environments...${NC}"
# For dev/int on kub2-eb-prd cluster
apply_labels "kub2-eb-prd" "${NAMESPACE}"

echo -e "\n${YELLOW}Processing production and training environments...${NC}"
# For prd/trn on kub2-eb-prd and kub2-or-prd clusters
apply_labels "kub2-eb-prd" "${NAMESPACE}"
apply_labels "kub2-or-prd" "${NAMESPACE}"

echo -e "\n${GREEN}Operation completed.${NC}"
echo -e "Labels 'ako-gslb: enabled' and 'avioperator: \"3\"' have been applied to namespace '${NAMESPACE}' in all relevant clusters."

exit 0