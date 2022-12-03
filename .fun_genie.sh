
sh_source
_this="$( script_source )"
_sources+=("$(basename ${_this})")

UTILITIES+=("echo" "awk" "grep" "cat" "curl" "base64" "tr" "printf" "wc" "sort" "kubectl" "pkill" "sleep")
abbr='genie'

# Create help function for this file
common-help "${abbr}" "${_this}"

# Curl Elasticsearch with API key
# genie-curl [url] [ApiKey]
genie-curl() {
  local cURL="${1}"
  local cAPI="${2}"
  QUIET=true
  if [ -z "${cURL}" ]; then echo "need URL"; return 1;fi
  local H1="'Content-Type: application/json'"
  local H2="Authorization: GenieKey ${cAPI}"
  cmd "curl -sk ${cURL} -H ${H1} -H \"${H2}\""
  return ${LAST_STATUS}
}

# Curl Elasticsearch with API key
# genie-get [team] [api endpoint]
genie-get() {
  local team="${1}"
  local endpoint="${2#/}"
  local genie_key="${3:-${GENIE[${team}]}}"
  local eURL="${GENIE_URL[US]}/${endpoint}"
  genie-curl "${eURL}" "${genie_key}"
}

# Curl PUT Elasticsearch with API key
# genie-put [team] [api endpoint] [data]
genie-put() {
  local team="${1}"
  local endpoint="${2#/}"
  local eDATA="${3}"
  local eURL="${GENIE_URL[US]}/${endpoint}"
  local H1="Content-Type: application/json"
  local H2="Authorization: GenieKey ${GENIE[${team}]}"
  curl -sk -XPUT "${eURL}" -H "${H1}" -H "${H2}" -d "${eDATA}"
}

# Curl DELETE Elasticsearch with API key
# genie-delete [team] [api endpoint] [data]
genie-delete() {
  local team="${1}"
  local endpoint="${2#/}"
  local eDATA="${3}"
  local eURL="${GENIE_URL[US]}/${endpoint}"
  local H1="Content-Type: application/json"
  local H2="Authorization: GenieKey ${GENIE[${team}]}"
  curl -sk -XDELETE "${eURL}" -H "${H1}" -H "${H2}"
}

# Curl POST Elasticsearch with API key
# genie-post [team] [api endpoint] [data]
genie-post() {
  local team="${1}"
  local endpoint="${2#/}"
  local eDATA="${3}"
  local eURL="${GENIE_URL[US]}/${endpoint}"
  local H1="Content-Type: application/json"
  local H2="Authorization: GenieKey ${GENIE[${team}]}"
  curl -sk -XPOST "${eURL}" -H "${H1}" -H "${H2}" -d "${eDATA}"
}

# List users on team
# genie-list-users <team> 
genie-list-users() {
  local team="${1}"
  local team_id="$(genie-get-team-id ${team})" 
  if [ -z "${team_id}" ]; then echo "Unable to find team id for ${team}"; return; fi
  genie-get "MCP" "/v2/teams/${team_id}" 
}

# List users on team
# genie-list-users <team> 
# example: for u in $(genie-list-users Validation | jq -c '.data.members[]'); do genie-add-team-member mcp-tenant-msv "$(echo $u | jq -r .user.username)" "$(echo $u | jq -r .role)"; done
genie-add-team-member() {
  local team="${1}"
  local user="${2}"
  local role="${3:-user}"
  local team_id="$(genie-get-team-id ${team})" 
  if [ -z "${team_id}" ]; then echo "Unable to find team id for ${team}"; return; fi
  local json="{\"user\": {\"username\": \"${user}\" },\"role\": \"${role}\" }"
  genie-post "MCP" "/v2/teams/${team_id}/members" "${json}"
}

# List teams nicknames
# genie-list-team-nicknames
genie-list-team-nicknames() {
  local team="${1}"
  array-indices GENIE
}

# List teams
# genie-list-teams <team> 
genie-list-teams() {
  local team="${1:-MCP}"
  genie-get "${team}" '/v2/teams'
}

# Get Team Id
# genie-get-team-id <team> <team_full_name>
genie-get-team-id() {
  local team="${1}"
  if [ -z "${team}" ]; then echo "Team Nickname Required."; return; fi
  genie-list-teams | jq -r '.data[] | select(.name=="'${team}'") | .id'
}

# List team notification policies
# genie-list-notify-policies <team> <team_id> 
genie-list-notify-policies() {
  local team="${1}"
  local team_id="${2}"
  if [ -z "${team}" ]; then echo "Team Nickname Required."; return; fi
  genie-get "${team}" "/v2/policies/notification?teamId=${team_id}"
}

# List team notification policies
# genie-get-notify-policy <team> <team_id> 
genie-get-notify-policy() {
  local team="${1}"
  local team_id="${2}"
  local policy_id="${3}"
  if [ -z "${team}" ]; then echo "Team Nickname Required."; return; fi
  genie-get "${team}" "/v2/policies/${policy_id}?teamId=${team_id}" | jq '.data'
}

# List team notification policies
# genie-put-notify-policy <team> <team_id> <json_data>
# genie-list-notify-policies MCP $(genie-get-team-id MCP mcp-tenant-aip) | jq
# JSON=$(genie-get-notify-policy MCP $(genie-get-team-id MCP mcp-tenant-aip) a8502ab1-371c-4d41-97bd-49d350d398e7 | jq 'del(.id)')
# genie-put-notify-policy MCP "$JSON" $(genie-get-team-id MCP mcp-tenant-abi) 
genie-put-notify-policy() {
  local team="${1}"
  local data="${2}"
  local team_id="${3/#/?teamId=}"
  if [ -z "${team}" ]; then echo "Team Nickname Required."; return; fi
  echo "team: $team, team_id: $team_id, url:/v2/policies${team_id}"
  genie-post "${team}" "/v2/policies${team_id}" "${data}"
}

# If you source this file directly, apply the overwrites.
if [ -z "$(echo "$(script_origin)" | grep -F "shrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi
