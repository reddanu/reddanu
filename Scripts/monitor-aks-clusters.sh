send_teams_notification() {
  local title="$1"
  local text="$2" 
  local themeColor="$3"
  local details="$4"
  
  if [[ "$SEND_NOTIFICATIONS" != true ]] || [[ -z "$TEAMS_WEBHOOK_URL" ]]; then
    log INFO "Teams notifications disabled or webhook URL not set"
    return
  fi

  # Format using MessageCard format that Teams/Power Automate expects
  local json_payload=$(cat << EOF
{
  "@type": "MessageCard",
  "@context": "http://schema.org/extensions",
  "themeColor": "$themeColor",
  "summary": "$title",
  "title": "$title",
  "text": "$text\n\n$details"
}
EOF
)

  log INFO "Sending notification to Teams"
  log INFO "Using webhook URL: $TEAMS_WEBHOOK_URL"

  # Send to Teams webhook using Power Automate
  local response=$(curl -s -X POST "$TEAMS_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$json_payload" \
    -w "%{http_code}")
  
  local http_code="${response: -3}"
  local response_body="${response%???}"
  
  if [[ "$http_code" == "200" || "$http_code" == "201" || "$http_code" == "202" ]]; then
    log INFO "Teams notification sent successfully (HTTP $http_code)"
    if [[ -n "$response_body" ]]; then
      log INFO "Response body: $response_body"
    fi
  else
    log ERROR "Failed to send Teams notification. HTTP code: $http_code, Response: $response_body"
    log ERROR "Webhook URL: $TEAMS_WEBHOOK_URL"
    log ERROR "Payload: $json_payload"
  fi
}