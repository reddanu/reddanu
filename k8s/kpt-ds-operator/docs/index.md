---
title: kpt-ds-csi-operator
---

## Documentation for kpt-ds-csi-operator

# DaemonSet Toleration Operator

The `kpt-ds-csi-operator` (DaemonSet Toleration Operator) is a Kubernetes operator designed to ensure that specific DaemonSets in your Kubernetes cluster always have the required tolerations, even after cluster upgrades or other operations that might modify them.

## Overview

This operator continuously monitors specific DaemonSets (by default, the vSphere CSI node DaemonSet) and ensures that a designated toleration is always present. If the toleration is removed for any reason, the operator will automatically add it back.

## How It Works

The operator runs as a Kubernetes Deployment and uses the Kubernetes Go client to:

1. Watch for changes to the specified DaemonSet
2. Check if the required toleration is present
3. If the toleration is missing, update the DaemonSet to add it back

This is particularly useful for critical infrastructure components that need to run on nodes with specific taints, even after cluster maintenance operations.

## Features

- Monitors specific DaemonSets for required tolerations
- Automatically restores missing tolerations
- Configurable through command-line flags or configuration files
- Designed for high availability and low resource footprint
- Built using the Kubernetes operator pattern

???+ tip "What next?"

    - [Add the annotation](https://platform.app.chrazure.cloud/docs/default/component/platform.backstage/tech-docs/quick-start/#step-2-add-the-annotation) in your `catalog-info.yml` file.
    - [Write your docs](https://platform.app.chrazure.cloud/docs/default/component/platform.backstage/tech-docs/software-catalog/importing-data/#step-3-write-your-docs) for this project!
