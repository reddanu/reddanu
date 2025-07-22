#!/bin/bash
# check-duplicate-node-ips.sh
# Script to check for duplicate IP addresses among Kubernetes nodes
# Created: July 16, 2025

set -e

echo "============================================"
echo "Checking for duplicate IP addresses in Kubernetes nodes"
echo "============================================"

# Function to check if required commands exist
check_prerequisites() {
  local missing_tools=()
  
  for tool in kubectl jq sort uniq grep; do
    if ! command -v $tool &> /dev/null; then
      missing_tools+=("$tool")
    fi
  done
  
  if [ ${#missing_tools[@]} -gt 0 ]; then
    echo "Error: Required tools are missing: ${missing_tools[*]}"
    echo "Please install these tools before running this script."
    exit 1
  fi
}

# Function to get node IP addresses
get_node_ips() {
  # Try different address types that might be available in the node status
  local address_types=("InternalIP" "ExternalIP")
  local results=()
  
  echo "Fetching node information..."
  
  for address_type in "${address_types[@]}"; do
    echo "Checking $address_type addresses:"
    echo "--------------------------------"
    
    # Get nodes with their IPs, filter by address type
    nodes_with_ips=$(kubectl get nodes -o json | jq -r ".items[] | 
      .metadata.name as \$name | 
      .status.addresses[] | 
      select(.type == \"$address_type\") | 
      { name: \$name, ip: .address, type: .type } | 
      [.name, .ip, .type] | @tsv")
    
    if [[ -z "$nodes_with_ips" ]]; then
      echo "No $address_type addresses found."
      continue
    fi
    
    # Print all nodes with their IPs
    echo "$nodes_with_ips" | while read -r line; do
      node_name=$(echo "$line" | awk '{print $1}')
      ip=$(echo "$line" | awk '{print $2}')
      echo "Node: $node_name, IP: $ip"
    done
    
    # Check for duplicate IPs
    duplicate_ips=$(echo "$nodes_with_ips" | awk '{print $2}' | sort | uniq -d)
    
    if [[ -n "$duplicate_ips" ]]; then
      echo ""
      echo "⚠️  DUPLICATE IPs DETECTED ($address_type):"
      echo "----------------------------------------"
      
      for ip in $duplicate_ips; do
        echo "Duplicate IP: $ip is used by:"
        echo "$nodes_with_ips" | grep "$ip" | awk '{print "  - " $1}'
      done
      
      results+=("true")
    else
      echo ""
      echo "✅ No duplicate $address_type addresses found"
      results+=("false")
    fi
    
    echo ""
  done
  
  # Return overall result
  if [[ "${results[*]}" == *"true"* ]]; then
    return 1
  else
    return 0
  fi
}

# Function to check kubelet status for potential issues
check_kubelet_status() {
  echo "Checking kubelet status on nodes..."
  echo "--------------------------------"
  
  problem_nodes=$(kubectl get nodes -o json | jq -r '.items[] | 
    select(.status.conditions[] | 
    select(.type=="Ready" and .status!="True")) | 
    .metadata.name')
  
  if [[ -n "$problem_nodes" ]]; then
    echo "⚠️  The following nodes have Ready=False status:"
    echo "$problem_nodes" | while read -r node; do
      echo "  - $node"
      echo "    Conditions:"
      kubectl get node "$node" -o json | jq -r '.status.conditions[] | "    * " + .type + ": " + .status + " (" + .reason + ")"'
    done
    return 1
  else
    echo "✅ All nodes have Ready=True status"
    return 0
  fi
}

# Function to check for other networking issues
check_network_issues() {
  echo ""
  echo "Checking for potential network configuration issues..."
  echo "---------------------------------------------------"

  # Check for pods with networking issues
  echo "Checking for pods with networking issues..."
  problem_pods=$(kubectl get pods --all-namespaces -o json | jq -r '.items[] | 
    select(.status.phase!="Running" and .status.phase!="Succeeded") | 
    select(.status.conditions[] | select(.type=="PodScheduled" and .status=="True")) | 
    {name: .metadata.name, namespace: .metadata.namespace, status: .status.phase, message: (.status.conditions[] | select(.type=="Ready") | .message)} |
    [.namespace, .name, .status, .message] | @tsv' | grep -i -e "network" -e "connect" -e "unreachable" -e "refused" || true)
  
  if [[ -n "$problem_pods" ]]; then
    echo "⚠️  The following pods have network-related issues:"
    echo "$problem_pods" | while read -r line; do
      namespace=$(echo "$line" | awk '{print $1}')
      name=$(echo "$line" | awk '{print $2}')
      status=$(echo "$line" | awk '{print $3}')
      echo "  - $namespace/$name: $status"
    done
  else
    echo "✅ No pods with obvious networking issues found"
  fi
}

# Main execution
main() {
  check_prerequisites
  
  # Check for duplicate IPs
  if get_node_ips; then
    echo "✅ No duplicate IP addresses detected among nodes"
  else
    echo "⚠️  Duplicate IP addresses detected - this can cause serious cluster issues!"
  fi
  
  echo ""
  
  # Check kubelet status
  check_kubelet_status
  
  # Check for other network issues
  check_network_issues
  
  echo ""
  echo "============================================"
  echo "Checking registry pull configuration:"
  echo "============================================"
  
  # Check if kubelet is configured with the registry QPS and burst settings
  echo "Checking for registry QPS and burst settings on a node..."
  
  # Get one node name
  node=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
  
  # Try to ssh to the node and check kubelet config
  echo "To verify the registry pull settings on node $node, run:"
  echo "  ssh <user>@$node 'ps aux | grep kubelet | grep -E \"registry-(qps|burst)\"'"
  echo ""
  echo "Or run this on the node to check the kubelet config:"
  echo "  cat /var/lib/kubelet/config.yaml | grep -A2 -E \"registryPullQPS|registryBurst\""
  
  echo ""
  echo "============================================"
  echo "Script execution completed"
  echo "============================================"
}

# Run the script
main
