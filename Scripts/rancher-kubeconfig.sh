#!/bin/bash

# Variables
declare -A RANCHER_API_URLS_TOKENS=(
    ["https://eb-rcm-prd.chr8s.io/v3"]="token-************"   # create a bear token api from your account ebdc
    ["https://or-rcm-prd.chr8s.io/v3"]="token-************"   # create a bear token api from your account ordc
)
KUBE_CONFIG="$HOME/.kube/config"
TEMP_KUBE_CONFIG="/tmp/temp_kube_config"
MERGED_KUBE_CONFIG="/tmp/merged_kubeconfig"

# Check if curl and jq are installed
if ! command -v curl &> /dev/null; then
    echo "curl could not be found, installing..."
    sudo brew install curl
fi

if ! command -v jq &> /dev/null; then
    echo "jq could not be found, installing..."
    sudo brew install jq
fi

# Initialize the merged kubeconfig file
echo "" > $MERGED_KUBE_CONFIG

# Loop through each Rancher API URL and its token
for RANCHER_API_URL in "${!RANCHER_API_URLS_TOKENS[@]}"; do
    API_TOKEN=${RANCHER_API_URLS_TOKENS[$RANCHER_API_URL]}
    RANCHER_NAME=$(echo $RANCHER_API_URL | awk -F[/:] '{print $4}')
    echo "Fetching cluster configurations from Rancher URL: $RANCHER_API_URL"
    CLUSTERS=$(curl -s -k -H "Authorization: Bearer $API_TOKEN" "$RANCHER_API_URL/clusters" | jq -r '.data[] | @base64')

    # Loop through each cluster and fetch kubeconfig
    for cluster in $CLUSTERS; do
        _jq() {
            echo ${cluster} | base64 --decode | jq -r ${1}
        }

        CLUSTER_ID=$(_jq '.id')
        CLUSTER_NAME=$(_jq '.name')

        echo "Fetching kubeconfig for cluster: $CLUSTER_NAME ($CLUSTER_ID)"
        RESPONSE=$(curl -s -k -X POST -H "Authorization: Bearer $API_TOKEN" "$RANCHER_API_URL/clusters/$CLUSTER_ID?action=generateKubeconfig")
        KUBECONFIG=$(echo "$RESPONSE" | jq -r '.config')

        # Debugging: Print the full response
        echo "Full response for $CLUSTER_NAME:"
        echo "$RESPONSE"

        # Check if kubeconfig is null
        if [ "$KUBECONFIG" == "null" ]; then
            echo "Failed to fetch kubeconfig for cluster: $CLUSTER_NAME ($CLUSTER_ID)"
            continue
        fi

        # Write the kubeconfig to a temporary file
        echo "$KUBECONFIG" > "$TEMP_KUBE_CONFIG"

        # Rename the context and cluster names to include the Rancher name
        CONTEXT_NAME="${RANCHER_NAME}-${CLUSTER_NAME}"
        CLUSTER_NAME="${RANCHER_NAME}-${CLUSTER_NAME}"
        kubectl config rename-context local $CONTEXT_NAME --kubeconfig=$TEMP_KUBE_CONFIG
        kubectl config set-cluster $CLUSTER_NAME --kubeconfig=$TEMP_KUBE_CONFIG

        # Merge the temporary kubeconfig with the merged kubeconfig
        KUBECONFIG=$MERGED_KUBE_CONFIG:$TEMP_KUBE_CONFIG kubectl config view --flatten > /tmp/temp_merged_kubeconfig
        mv /tmp/temp_merged_kubeconfig $MERGED_KUBE_CONFIG
    done
done

# Copy the merged kubeconfig to the final kubeconfig location
cp $MERGED_KUBE_CONFIG $KUBE_CONFIG

# Clean up temporary files
rm -f "$TEMP_KUBE_CONFIG" "$MERGED_KUBE_CONFIG"

echo "Cluster configurations have been updated in $KUBE_CONFIG"