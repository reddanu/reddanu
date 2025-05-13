#!/bin/bash

# Test script for the kpt-ds-csi-operator
# This script will:
# 1. Get the current state of the vsphere-csi-node DaemonSet
# 2. Remove the dedicated=prometheus:NoSchedule toleration 
# 3. Wait 60 seconds for the operator to add it back
# 4. Verify that the toleration has been added back

set -e

NAMESPACE="kube-system"
DAEMONSET="vsphere-csi-node"
TOLERATION_KEY="dedicated"
TOLERATION_VALUE="prometheus"
TOLERATION_EFFECT="NoSchedule"

echo "=== Testing kpt-ds-csi-operator ==="
echo ""

# Step 1: Get current state of the DaemonSet
echo "Current tolerations on $DAEMONSET DaemonSet:"
kubectl get daemonset $DAEMONSET -n $NAMESPACE -o jsonpath='{.spec.template.spec.tolerations}' | jq .
echo ""

# Step 2: Find the index of the toleration we want to remove
echo "Finding index of $TOLERATION_KEY=$TOLERATION_VALUE:$TOLERATION_EFFECT toleration..."
TOLERATIONS=$(kubectl get daemonset $DAEMONSET -n $NAMESPACE -o jsonpath='{.spec.template.spec.tolerations}')
INDEX=$(echo $TOLERATIONS | jq 'map(.key == "'$TOLERATION_KEY'" and .value == "'$TOLERATION_VALUE'" and .effect == "'$TOLERATION_EFFECT'") | index(true)')

if [ "$INDEX" == "null" ]; then
  echo "Toleration not found! This is good for testing the operator."
else
  echo "Toleration found at index $INDEX. Removing it to test the operator..."
  
  # Step 3: Remove the toleration
  kubectl patch daemonset $DAEMONSET -n $NAMESPACE --type=json -p='[{"op": "remove", "path": "/spec/template/spec/tolerations/'$INDEX'"}]'
  echo "Toleration removed."
fi

echo ""
echo "Waiting 60 seconds for operator to add the toleration back..."
for i in {1..6}; do
  echo "Waiting... $i/6"
  sleep 10
done

# Step 4: Verify the toleration was added back
echo ""
echo "Current tolerations after waiting:"
kubectl get daemonset $DAEMONSET -n $NAMESPACE -o jsonpath='{.spec.template.spec.tolerations}' | jq .

# Check if the toleration exists
if kubectl get daemonset $DAEMONSET -n $NAMESPACE -o jsonpath='{.spec.template.spec.tolerations[*].key}' | grep -q "$TOLERATION_KEY"; then
  echo ""
  echo "✅ SUCCESS: Toleration with key '$TOLERATION_KEY' found! The operator is working."
else
  echo ""
  echo "❌ FAILURE: Toleration with key '$TOLERATION_KEY' not found! The operator is not working."
fi

# Also check the operator logs
echo ""
echo "Operator logs:"
kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=kpt-ds-csi-operator --tail=20