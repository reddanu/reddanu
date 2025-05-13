package main

import (
	"flag"

	"github.com/ch-robinson-internal/kpt-ds-csi-operator/internal/app"
	"k8s.io/klog/v2"
)

func main() {
	// Define command-line flags
	var (
		namespace        string
		daemonset        string
		tolerationKey    string
		tolerationValue  string
		tolerationEffect string
	)

	// Initialize klog
	klog.InitFlags(nil)

	// Define our custom flags
	flag.StringVar(&namespace, "namespace", "kube-system", "Namespace where the DaemonSet is located")
	flag.StringVar(&daemonset, "daemonset", "vsphere-csi-node", "Name of the DaemonSet to monitor")
	flag.StringVar(&tolerationKey, "toleration-key", "dedicated", "Key for the toleration to enforce")
	flag.StringVar(&tolerationValue, "toleration-value", "prometheus", "Value for the toleration to enforce")
	flag.StringVar(&tolerationEffect, "toleration-effect", "NoSchedule", "Effect for the toleration to enforce")

	// Set verbosity default
	flag.Set("v", "2")

	// Parse flags
	flag.Parse()

	klog.Infof("Starting DaemonSet CSI operator with config: namespace=%s, daemonset=%s, toleration=%s=%s:%s",
		namespace, daemonset, tolerationKey, tolerationValue, tolerationEffect)

	// Run the application with the parsed flags
	app.Run(namespace, daemonset, tolerationKey, tolerationValue, tolerationEffect)
}
