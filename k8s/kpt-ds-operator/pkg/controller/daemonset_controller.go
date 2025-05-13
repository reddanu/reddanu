package controller

import (
	"context"
	"time"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/util/runtime"
	"k8s.io/apimachinery/pkg/util/wait"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/util/workqueue"
	"k8s.io/klog/v2"
)

// DaemonSetController is the controller implementation
type DaemonSetController struct {
	kubeclientset    kubernetes.Interface
	namespace        string
	daemonSetName    string
	tolerationKey    string
	tolerationValue  string
	tolerationEffect string
	workqueue        workqueue.RateLimitingInterface
}

// NewDaemonSetController creates a new DaemonSetController
func NewDaemonSetController(
	kubeclientset kubernetes.Interface,
	namespace string,
	daemonSetName string,
	tolerationKey string,
	tolerationValue string,
	tolerationEffect string) *DaemonSetController {

	controller := &DaemonSetController{
		kubeclientset:    kubeclientset,
		namespace:        namespace,
		daemonSetName:    daemonSetName,
		tolerationKey:    tolerationKey,
		tolerationValue:  tolerationValue,
		tolerationEffect: tolerationEffect,
		workqueue:        workqueue.NewNamedRateLimitingQueue(workqueue.DefaultControllerRateLimiter(), "DaemonSets"),
	}

	klog.Infof("Created DaemonSet controller for %s/%s with toleration %s=%s:%s",
		namespace, daemonSetName, tolerationKey, tolerationValue, tolerationEffect)

	return controller
}

// Run starts the controller
func (c *DaemonSetController) Run(stopCh <-chan struct{}) {
	defer runtime.HandleCrash()
	defer c.workqueue.ShutDown()

	klog.Info("Starting DaemonSet controller")

	// Immediately check the DaemonSet
	c.checkAndUpdateDaemonSet()

	// Start a worker
	go wait.Until(c.runWorker, time.Second, stopCh)

	// Periodically check the DaemonSet
	go wait.Until(func() {
		klog.Info("Periodic check of DaemonSet")
		c.checkAndUpdateDaemonSet()
	}, 30*time.Second, stopCh)

	<-stopCh
	klog.Info("Shutting down DaemonSet controller")
}

// runWorker processes items from the workqueue
func (c *DaemonSetController) runWorker() {
	for c.processNextWorkItem() {
	}
}

// processNextWorkItem processes one item from the workqueue
func (c *DaemonSetController) processNextWorkItem() bool {
	obj, shutdown := c.workqueue.Get()
	if shutdown {
		return false
	}

	err := func(obj interface{}) error {
		defer c.workqueue.Done(obj)

		// Process the item
		c.checkAndUpdateDaemonSet()
		c.workqueue.Forget(obj)
		return nil
	}(obj)

	if err != nil {
		runtime.HandleError(err)
	}

	return true
}

// checkAndUpdateDaemonSet gets the DaemonSet and ensures it has the required toleration
func (c *DaemonSetController) checkAndUpdateDaemonSet() {
	// Get the DaemonSet
	daemonSet, err := c.kubeclientset.AppsV1().DaemonSets(c.namespace).Get(context.TODO(), c.daemonSetName, metav1.GetOptions{})
	if err != nil {
		if errors.IsNotFound(err) {
			klog.Warningf("DaemonSet %s/%s not found", c.namespace, c.daemonSetName)
			return
		}
		klog.Errorf("Error getting DaemonSet %s/%s: %v", c.namespace, c.daemonSetName, err)
		return
	}

	klog.Infof("Checking tolerations on DaemonSet %s/%s", c.namespace, c.daemonSetName)
	// Log all existing tolerations
	for i, t := range daemonSet.Spec.Template.Spec.Tolerations {
		klog.Infof("DaemonSet %s/%s has toleration[%d]: key=%s, value=%s, effect=%s",
			c.namespace, c.daemonSetName, i, t.Key, t.Value, t.Effect)
	}

	// Check if our required toleration is present
	if !c.hasToleration(daemonSet) {
		klog.Infof("DaemonSet %s/%s is missing the required toleration %s=%s:%s, adding it",
			c.namespace, c.daemonSetName, c.tolerationKey, c.tolerationValue, c.tolerationEffect)

		daemonSetCopy := daemonSet.DeepCopy()

		// Convert effect string to TaintEffect
		var effect corev1.TaintEffect
		switch c.tolerationEffect {
		case "NoSchedule":
			effect = corev1.TaintEffectNoSchedule
		case "PreferNoSchedule":
			effect = corev1.TaintEffectPreferNoSchedule
		case "NoExecute":
			effect = corev1.TaintEffectNoExecute
		default:
			effect = corev1.TaintEffectNoSchedule
		}

		// Add our toleration
		toleration := corev1.Toleration{
			Key:    c.tolerationKey,
			Value:  c.tolerationValue,
			Effect: effect,
		}

		daemonSetCopy.Spec.Template.Spec.Tolerations = append(daemonSetCopy.Spec.Template.Spec.Tolerations, toleration)

		// Update the DaemonSet
		_, err = c.kubeclientset.AppsV1().DaemonSets(c.namespace).Update(context.TODO(), daemonSetCopy, metav1.UpdateOptions{})
		if err != nil {
			klog.Errorf("Failed to update DaemonSet: %v", err)
			return
		}
		klog.Infof("Successfully added toleration to DaemonSet %s/%s", c.namespace, c.daemonSetName)
	} else {
		klog.Infof("DaemonSet %s/%s already has the required toleration %s=%s:%s",
			c.namespace, c.daemonSetName, c.tolerationKey, c.tolerationValue, c.tolerationEffect)
	}
}

// hasToleration checks if the DaemonSet has the required toleration
func (c *DaemonSetController) hasToleration(daemonSet *appsv1.DaemonSet) bool {
	// Convert effect string to TaintEffect
	var effect corev1.TaintEffect
	switch c.tolerationEffect {
	case "NoSchedule":
		effect = corev1.TaintEffectNoSchedule
	case "PreferNoSchedule":
		effect = corev1.TaintEffectPreferNoSchedule
	case "NoExecute":
		effect = corev1.TaintEffectNoExecute
	default:
		effect = corev1.TaintEffectNoSchedule
	}

	for _, t := range daemonSet.Spec.Template.Spec.Tolerations {
		if t.Key == c.tolerationKey && t.Value == c.tolerationValue && t.Effect == effect {
			return true
		}
	}
	klog.Infof("DaemonSet %s/%s does not have the required toleration %s=%s:%s",
		daemonSet.Namespace, daemonSet.Name, c.tolerationKey, c.tolerationValue, c.tolerationEffect)
	return false
}
