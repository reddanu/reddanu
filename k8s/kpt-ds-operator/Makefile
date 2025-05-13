PACKAGE_NAME := kpt_ds_csi_operator
.DEFAULT_GOAL := help

.PHONY: help
help: ## Generates a help
	@grep '^[a-zA-Z]' $(MAKEFILE_LIST) | sort | awk -F ':.*?## ' 'NF==2 {printf "\033[36m  %-25s\033[0m %s\n", $$1, $$2}'

.PHONY: lint-docker
lint-docker: ## Run pre-commit linting against all files in docker
	@docker compose --profile dev run --build --rm app pre-commit run --all-files --show-diff-on-failure --verbose

.PHONY: setup
setup: ## Install required packages
	@go install golang.org/x/tools/cmd/deadcode@latest
	@go install golang.org/x/tools/cmd/goimports@latest
	@go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

.PHONY: run
run: build ## Build and run the application
	@./dist/main --namespace="kube-system" --daemonset="vsphere-csi-node" --toleration-key="dedicated" --toleration-value="prometheus" --toleration-effect="NoSchedule"

.PHONY: test
test: build ## Build and run the application
	@go test; deadcode .

build: ## Build the golang code
	@mkdir -p ./dist 2>/dev/null; go build -o ./dist/main ./main.go

fmt: ## Fmt the golang code
	@find internal pkg -name '*.go' | while read -r i; do go fmt $$i; done

.PHONY: run-docker
run-docker: ## Start the application in the background using docker
	@docker compose --profile dev up --build -d

.PHONY: logs
logs: ## Get the docker logs for the application
	@docker compose logs -f

.PHONY: shell
shell: ## Open a shell in the running docker container
	@docker compose exec app /bin/bash

.PHONY: test-docker
test-docker: ## Run unit tests using docker
	@docker compose --profile dev run --build --rm app go test ./...

.PHONY: clean-build
clean-build: ## Remove build artifacts
	rm -fr .helm/${PACKAGE_NAME}/charts/

docker: ## Build the docker image
	@docker build . -t chr/kpt-ds-csi-operator

.PHONY: test-install
test-install: ## install test
	@kubectx centralus-core-cd-sbx-aks-admin
	@kubens kube-system
	@helm upgrade --dependency-update --reset-values --debug --namespace kube-system --install --values .helm/values-dev-centralus.yaml --set image.tag=18-pull-request --wait --atomic --debug --timeout 2m0s kpt-ds-csi-operator .helm/

test-template: ## template install test
	@helm template --debug --namespace kube-system --values .helm/values-dev-centralus.yaml --set image.tag=18-pull-request --wait --debug --timeout 2m0s kpt-ds-csi-operator-pr18 .helm

test-upgrade-install: ## template install test
	@helm upgrade --install --debug --namespace kube-system --values .helm/values-dev-centralus.yaml --set image.tag=18-pull-request --wait --debug --timeout 2m0s kpt-ds-csi-operator-pr18 .helm

%: # NO-OP for unrecognized rules
	@: