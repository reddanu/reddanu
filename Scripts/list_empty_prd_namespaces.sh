#!/bin/bash

# Exit immediately on error
set -e

# Gather all prd-* namespaces
namespaces=$(kubectl get ns --no-headers -o custom-columns=':metadata.name' | grep '^prd-')

echo "Scanning prd namespaces for empty resources..."
empty_namespaces=()

for ns in $namespaces; do
  # Count deployments, ingresses, and statefulsets
  dep=$(kubectl get deployments -n "$ns" --ignore-not-found -o name | wc -l)
  ing=$(kubectl get ingress -n "$ns" --ignore-not-found -o name | wc -l)
  sts=$(kubectl get statefulsets -n "$ns" --ignore-not-found -o name | wc -l)

  # If all are zero, mark as empty
  if [[ $dep -eq 0 && $ing -eq 0 && $sts -eq 0 ]]; then
    empty_namespaces+=("$ns")
  fi
done

# Output results
if [ ${#empty_namespaces[@]} -eq 0 ]; then
  echo "No empty prd namespaces found."
else
  echo "Empty prd namespaces:";
  for ns in "${empty_namespaces[@]}"; do
    echo "- $ns"
  done
fi
