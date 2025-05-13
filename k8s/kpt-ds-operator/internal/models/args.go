package models

// Args defines the command-line arguments for the application
type Args struct {
	KubeConfig       string
	Namespace        string
	DaemonSetName    string
	TolerationKey    string
	TolerationValue  string
	TolerationEffect string
}
