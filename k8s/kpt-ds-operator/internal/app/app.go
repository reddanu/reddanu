package app

import (
	"os"
	"os/signal"
	"syscall"

	"github.com/ch-robinson-internal/kpt-ds-csi-operator/pkg/controller"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/klog/v2"
)

// Run starts the application with the provided parameters
func Run(namespace, daemonSetName, tolerationKey, tolerationValue, tolerationEffect string) {
	klog.Info("DaemonSet Toleration Controller is running. Press Ctrl+C to stop.")

	// Create the in-cluster config
	config, err := rest.InClusterConfig()
	if err != nil {
		klog.Warningf("Failed to create in-cluster config, falling back to kubeconfig: %v", err)

		// Try to use kubeconfig file
		kubeconfig := os.Getenv("KUBECONFIG")
		if kubeconfig == "" {
			home := os.Getenv("HOME")
			if home == "" {
				home = os.Getenv("USERPROFILE") // windows
			}
			if home != "" {
				kubeconfig = clientcmd.RecommendedHomeFile
			}
		}

		if kubeconfig != "" {
			config, err = clientcmd.BuildConfigFromFlags("", kubeconfig)
			if err != nil {
				klog.Fatalf("Failed to build config from kubeconfig: %v", err)
			}
		} else {
			klog.Fatalf("No kubeconfig found")
		}
	}

	// Create the clientset
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		klog.Fatalf("Failed to create clientset: %v", err)
	}

	// Create the controller
	daemonSetController := controller.NewDaemonSetController(
		clientset,
		namespace,
		daemonSetName,
		tolerationKey,
		tolerationValue,
		tolerationEffect,
	)

	// Set up signal handler
	stopCh := setupSignalHandler()

	// Start the controller
	daemonSetController.Run(stopCh)
}

// setupSignalHandler registers for SIGTERM and SIGINT
func setupSignalHandler() <-chan struct{} {
	stopCh := make(chan struct{})
	signalCh := make(chan os.Signal, 2)
	signal.Notify(signalCh, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-signalCh
		close(stopCh)
		<-signalCh
		os.Exit(1) // second signal. Exit directly.
	}()
	return stopCh
}
