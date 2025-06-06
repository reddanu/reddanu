#!/bin/bash

# Set script to exit on error
set -e

echo "=== Starting kpt-nslabel-injector test at $(date) ==="

# Define variables
NAMESPACE_FILE="./namespaces.yaml"
WAIT_TIME=60  # Time in seconds to watch logs (1 minute)
OPERATOR_NAMESPACE="kube-system"  # Change this if your operator is in a different namespace
OPERATOR_POD_LABEL="app=kpt-nslabel-injector"  # Change this to match your operator pod label

# Check dependencies
command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl is required but not installed. Aborting."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Warning: jq is not installed. Will display raw JSON instead of formatted output."; JQ_MISSING=true; }

# Function for formatted JSON output
format_json() {
  if [ "$JQ_MISSING" = true ]; then
    cat
  else
    jq .
  fi
}

# Check if namespace file exists
if [ ! -f "$NAMESPACE_FILE" ]; then
  echo "Error: $NAMESPACE_FILE not found!"
  exit 1
fi

# Get the kpt-nslabel-injector pod name
echo "Getting kpt-nslabel-injector pod name..."
POD_NAME=$(kubectl -n $OPERATOR_NAMESPACE get pods -l $OPERATOR_POD_LABEL -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)

if [ -z "$POD_NAME" ]; then
  echo "Error: kpt-nslabel-injector pod not found in namespace $OPERATOR_NAMESPACE with label $OPERATOR_POD_LABEL"
  echo "Please check if the operator is running and update the script with correct namespace/label"
  exit 1
fi

echo "Found operator pod: $POD_NAME in namespace $OPERATOR_NAMESPACE"

# Apply the namespace definitions
echo "Applying test namespaces from $NAMESPACE_FILE..."
kubectl apply -f "$NAMESPACE_FILE"

# Save the names of all test namespaces
TEST_NAMESPACES=$(kubectl get -f "$NAMESPACE_FILE" -o jsonpath='{.items[*].metadata.name}')
echo "Testing with these namespaces: $TEST_NAMESPACES"

# Start watching the operator logs
echo "Watching kpt-nslabel-injector logs for $WAIT_TIME seconds..."
echo "Look for namespace creation and label injection events in the log output..."

# Use kubectl logs with --since flag to only show new logs
echo "-------------------------- LOG START --------------------------"
kubectl logs -f -n $OPERATOR_NAMESPACE "$POD_NAME" --since=1s &
LOG_PID=$!

# Wait for specified time
echo "Waiting for $WAIT_TIME seconds to observe operator behavior..."
sleep $WAIT_TIME

# Stop watching logs
kill $LOG_PID 2>/dev/null || true
echo "-------------------------- LOG END ----------------------------"

# Check the state of the namespaces to verify injection worked
echo -e "\nChecking final state of test namespaces:"
for ns in $TEST_NAMESPACES; do
  echo -e "\nNamespace: $ns"
  echo "Labels:"
  kubectl get namespace $ns -o jsonpath='{.metadata.labels}' | format_json
done

# Cleanup: delete the namespaces
echo -e "\nTest complete. Cleaning up test namespaces..."
kubectl delete -f "$NAMESPACE_FILE" --ignore-not-found

# Check if namespaces were actually deleted
echo -e "\nVerifying namespace deletion..."
sleep 5  # Give K8s a moment to process deletion
for ns in $TEST_NAMESPACES; do
  if kubectl get namespace $ns >/dev/null 2>&1; then
    echo "Warning: Namespace $ns still exists. You may need to delete it manually."
  else
    echo "Namespace $ns successfully deleted."
  fi
done

echo "=== Test completed at $(date) ==="