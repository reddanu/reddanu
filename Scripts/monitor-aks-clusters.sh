#!/bin/bash
# monitor-aks-clusters.sh - Simplified AKS health monitoring with Teams notifications
# Created: June 2025

# Enable nounset and pipefail, but handle errors manually instead of exiting on first error
set -uo pipefail
IFS=$'\n\t'

# Trap SIGINT and SIGTERM to exit gracefully
trap 'log INFO "Script interrupted"; exit 1' INT TERM

# ----- Configuration -----
# Comma-separated list of subscription IDs (override with env FOCUS_SUBSCRIPTIONS)
FOCUS_SUBSCRIPTIONS=${FOCUS_SUBSCRIPTIONS:-}
# Enable notifications (true/false)
SEND_NOTIFICATIONS=${SEND_NOTIFICATIONS:-true}
# Power Automate workflow URL for Teams notifications
TEAMS_WEBHOOK_URL=${TEAMS_WEBHOOK_URL:-"https://prod-103.westus.logic.azure.com:443/workflows/495cab63c96441e7b556668c7e4757c5/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=kxO5tkpC44uTufXaVZ0rkJ-fRSBdwpIP-FxL4KhJhVo"}
# Log file
LOG_FILE="./aks-health-$(date +%Y%m%d-%H%M%S).log"

# Hard-coded subscription IDs to monitor
HARD_CODED_SUBS=(
  "c15330fb-8c3c-4d94-a1b5-65b49301f316"
  "ae405cb2-5216-4c2b-8e64-3395b86e6968"
  "0e798920-6ff3-40c3-8e78-732ed0a7a008"
  "566e24ab-22dd-4d94-a98a-aca24fdfccaf"
  "72661385-c651-4789-8ce4-7b12beb93f81"
  "f4e7afe6-046e-4176-9e3b-4bb848e61372"
  "774c1334-960b-48ab-8dba-61215daa3622"
)

# ----- Helpers -----
log() {
  local level=$1; shift
  echo "$(date '+%F %T') [$level] $*" | tee -a "$LOG_FILE"
}

error_exit() {
  log ERROR "$1"
  exit 1
}

check_deps() {
  for cmd in az jq curl; do
    command -v "$cmd" >/dev/null || error_exit "Missing dependency: $cmd"
  done
}

send_teams_notification() {
  local title="$1"
  local text="$2" 
  local themeColor="$3"
  local details="$4"
  
  if [[ "$SEND_NOTIFICATIONS" != true ]] || [[ -z "$TEAMS_WEBHOOK_URL" ]]; then
    log INFO "Teams notifications disabled or webhook URL not set"
    return
  fi

  local timestamp=$(date -u '+%Y-%m-%d %H:%M:%S')
  
  # Create Power Automate-friendly JSON payload
  local json_payload=$(cat <<EOF
{
  "title": "$title",
  "text": "$text",
  "themeColor": "$themeColor",
  "details": "$details",
  "timestamp": "$timestamp"
}
EOF
)

  # Send to Power Automate workflow
  local response=$(curl -s -X POST "$TEAMS_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$json_payload" \
    -w "%{http_code}")
  
  local http_code="${response: -3}"
  if [[ "$http_code" == "200" || "$http_code" == "202" ]]; then
    log INFO "Teams notification sent successfully (HTTP $http_code)"
  else
    log ERROR "Failed to send Teams notification. HTTP code: $http_code, Response: ${response%???}"
  fi
}

send_notify() {
  local cluster=$1 rg=$2 status=$3 detail=$4
  if [[ "$SEND_NOTIFICATIONS" == true ]]; then
    log INFO "Notify: $cluster in $rg is $status ($detail)"
    # Individual notifications can be sent here if needed
    # send_teams_notification "AKS Alert: $cluster" "$cluster in $rg is $status" "FF6600" "$detail"
  fi
}

get_subscriptions() {
  # Use either FOCUS_SUBSCRIPTIONS env var or hard-coded subscriptions
  if [[ -n "$FOCUS_SUBSCRIPTIONS" ]]; then
    # Split comma-separated subscription IDs into array
    IFS=',' read -r -a SUBS <<< "$FOCUS_SUBSCRIPTIONS"
  else
    # Use hard-coded subscriptions
    SUBS=("${HARD_CODED_SUBS[@]}")
  fi
}

# Arrays to collect failed checks for summary tables
CLUSTER_FAILED_ROWS=()
NODEPOOL_FAILED_ROWS=()

check_cluster() {
  local sub=$1
  if ! az account set --subscription "$sub" >/dev/null 2>&1; then
    log ERROR "Subscription $sub not found or inaccessible. Skipping."
    return
  fi
  local name=$(az account show --query name -o tsv)
  log INFO "Subscription: $name ($sub)"
  # Fetch clusters list and parse lines into array (portable on macOS)
  local clusters_raw=$(az aks list --subscription "$sub" --query "[].{name:name,rg:resourceGroup}" -o tsv)
  if [[ -z "$clusters_raw" ]]; then
    log INFO "No clusters in $name"
    return
  fi
  clusters=()
  while IFS=$'\t' read -r cname crg; do
    [[ -z "$cname" ]] && continue
    clusters+=("$cname"$'\t'"$crg")
  done <<< "$clusters_raw"
  [[ ${#clusters[@]} -gt 0 ]] || { log INFO "No clusters in $name"; return; }

  for entry in "${clusters[@]}"; do
    IFS=$'\t' read -r cluster rg <<<"$entry"
    log INFO "Checking $cluster in $rg"
    if ! data=$(az aks show -n "$cluster" -g "$rg" -o json 2>/dev/null); then
      log ERROR "Failed to fetch $cluster"
      send_notify "$cluster" "$rg" Failed "API error"
      CLUSTER_FAILED_ROWS+=("$name|$rg|$cluster|-|-|Failed to fetch cluster")
      continue
    fi
    local pwr=$(echo "$data" | jq -r '.powerState.code // "Unknown"')
    local prov=$(echo "$data" | jq -r '.provisioningState // "Unknown"')
    local status="Healthy"
    [[ "$pwr" == "Running" ]] || status="Unhealthy"
    [[ "$prov" == "Succeeded" ]] || status="Unhealthy"
    log "${status}" "$cluster: power=$pwr prov=$prov"
    if [[ "$status" == "Unhealthy" ]]; then
      send_notify "$cluster" "$rg" "$status" "power=$pwr prov=$prov"
      CLUSTER_FAILED_ROWS+=("$name|$rg|$cluster|$pwr|$prov|Cluster unhealthy")
    fi

    # Check nodepools for this cluster
    local nodepools_json=$(az aks nodepool list --cluster-name "$cluster" --resource-group "$rg" --query "[].{name:name,prov:provisioningState,pwr:powerState.code}" -o json 2>/dev/null)
    if [[ -z "$nodepools_json" || "$nodepools_json" == "[]" ]]; then
      log INFO "$cluster: No nodepools found"
      continue
    fi
    # Avoid subshell so we can update NODEPOOL_FAILED_ROWS in the main shell
    local np_count=$(echo "$nodepools_json" | jq 'length')
    for ((i=0; i<np_count; i++)); do
      local np_name=$(echo "$nodepools_json" | jq -r ".[$i].name")
      local np_prov=$(echo "$nodepools_json" | jq -r ".[$i].prov // \"Unknown\"")
      local np_pwr=$(echo "$nodepools_json" | jq -r ".[$i].pwr // \"Unknown\"")
      local np_status="Healthy"
      [[ "$np_pwr" == "Running" ]] || np_status="Unhealthy"
      [[ "$np_prov" == "Succeeded" ]] || np_status="Unhealthy"
      log "$np_status" "$cluster/$np_name: power=$np_pwr prov=$np_prov"
      if [[ "$np_status" == "Unhealthy" ]]; then
        NODEPOOL_FAILED_ROWS+=("$name|$rg|$cluster/$np_name|$np_pwr|$np_prov|Nodepool unhealthy")
      fi
    done
  done
}

# ----- Main -----
check_deps
# Ensure Azure CLI is logged in
if ! az account show >/dev/null 2>&1; then
  error_exit "Not logged into Azure CLI. Please run 'az login' before executing this script."
fi
get_subscriptions
for sub in "${SUBS[@]}"; do
  check_cluster "$sub"
done

# After all checks, print cluster and nodepool failures in table format
if [[ ${#CLUSTER_FAILED_ROWS[@]} -gt 0 ]]; then
  echo
  echo "=== CLUSTER FAILURES ==="
  printf "%-40s %-30s %-30s %-10s %-15s %-20s\n" "SUBSCRIPTION" "RESOURCE_GROUP" "CLUSTER" "POWER" "PROVISIONING" "DETAILS"
  printf "%-40s %-30s %-30s %-10s %-15s %-20s\n" "$(printf '=%.0s' {1..40})" "$(printf '=%.0s' {1..30})" "$(printf '=%.0s' {1..30})" "$(printf '=%.0s' {1..10})" "$(printf '=%.0s' {1..15})" "$(printf '=%.0s' {1..20})"
  for row in "${CLUSTER_FAILED_ROWS[@]}"; do
    # Split the tab-separated fields properly
    sub=$(echo "$row" | cut -d'|' -f1)
    rg=$(echo "$row" | cut -d'|' -f2)
    cl=$(echo "$row" | cut -d'|' -f3)
    pwr=$(echo "$row" | cut -d'|' -f4)
    prov=$(echo "$row" | cut -d'|' -f5)
    detail=$(echo "$row" | cut -d'|' -f6)
    printf "%-40s %-30s %-30s %-10s %-15s %-20s\n" "$sub" "$rg" "$cl" "$pwr" "$prov" "$detail"
  done
  echo
fi

if [[ ${#NODEPOOL_FAILED_ROWS[@]} -gt 0 ]]; then
  echo
  echo "=== NODEPOOL FAILURES ==="
  printf "%-40s %-30s %-35s %-10s %-15s %-20s\n" "SUBSCRIPTION" "RESOURCE_GROUP" "CLUSTER/NODEPOOL" "POWER" "PROVISIONING" "DETAILS"
  printf "%-40s %-30s %-35s %-10s %-15s %-20s\n" "$(printf '=%.0s' {1..40})" "$(printf '=%.0s' {1..30})" "$(printf '=%.0s' {1..35})" "$(printf '=%.0s' {1..10})" "$(printf '=%.0s' {1..15})" "$(printf '=%.0s' {1..20})"
  for row in "${NODEPOOL_FAILED_ROWS[@]}"; do
    # Split the tab-separated fields properly
    sub=$(echo "$row" | cut -d'|' -f1)
    rg=$(echo "$row" | cut -d'|' -f2)
    clnp=$(echo "$row" | cut -d'|' -f3)
    pwr=$(echo "$row" | cut -d'|' -f4)
    prov=$(echo "$row" | cut -d'|' -f5)
    detail=$(echo "$row" | cut -d'|' -f6)
    printf "%-40s %-30s %-35s %-10s %-15s %-20s\n" "$sub" "$rg" "$clnp" "$pwr" "$prov" "$detail"
  done
  echo
fi

# Send the final summary notification to Teams
if [[ ${#CLUSTER_FAILED_ROWS[@]} -eq 0 && ${#NODEPOOL_FAILED_ROWS[@]} -eq 0 ]]; then
  echo
  echo "✅ All clusters and nodepools are healthy."
  echo
  send_teams_notification \
    "✅ AKS Health Check - All Systems Healthy" \
    "All AKS clusters and nodepools are running normally." \
    "00FF00" \
    "Checked $(echo "${SUBS[@]}" | wc -w | tr -d ' ') subscriptions."
else
  # Fix: Don't use "local" outside of function
  summary="Found ${#CLUSTER_FAILED_ROWS[@]} cluster failure(s) and ${#NODEPOOL_FAILED_ROWS[@]} nodepool failure(s)"
  send_teams_notification \
    "🚨 AKS Health Check - Issues Detected" \
    "$summary" \
    "FF0000" \
    "Immediate attention required. Check the detailed log file for specific clusters and nodepools that need investigation."
fi

log INFO "Done. Log file: $LOG_FILE"
exit 0