#!/bin/bash

# Script to list namespaces with ako-gslb=enabled and avioperator=3 labels

echo "Namespaces with ako-gslb=enabled and avioperator=3:"
echo "================================================="

kubectl get namespaces -l "ako-gslb=enabled,avioperator=3" --no-headers -o custom-columns=NAME:.metadata.name

echo ""
echo "Count: $(kubectl get namespaces -l "ako-gslb=enabled,avioperator=3" --no-headers | wc -l)"
