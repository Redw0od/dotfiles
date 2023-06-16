
sh_source
_this="$( script_source )"
_sources+=("$(basename ${_this})")

UTILITIES+=("echo" "awk" "grep" "cat" "vault" "jq" "cut" "nc" )
abbr='vault'

# Create help function for this file
common-help "${abbr}" "${_this}"

# PS1 output for Vault profile
vault-ps1-color() {
  case $(lower "${VAULT_PROFILE}") in
    gov)
      echo -e "${ORANGE}${VAULT_PROFILE}${color[default]}"
      ;;
    test)
      echo -e "${color[yellow]}${VAULT_PROFILE}${color[default]}"
      ;;
    *)
      echo -e "${color[red]}${BOLD}${VAULT_PROFILE}${color[default]}"
      ;;
  esac
}

# Curl vault with token
# vault-curl <https://vault/path> [token]
vault-curl() {
  local cURL="${1}"
  local cToken="${2:-${VAULT_TOKEN}}"
  local action="${3}"
  if [ -z ${cURL} ]; then echo "need URL"; return 1;fi
  if [ -z ${cToken} ]; then echo "missing Token";fi
  local H1="'Content-Type: application/json'"
  local H2="X-Vault-Token: ${cToken}"
  cmd "curl -sk ${action} ${cURL} -H ${H1} -H \"${H2}\""
}

# Curl Vault with token
# vault-get </secret/path> [token]
vault-get() {
  local secret_path="${1}"
  local vToken="${2:-${VAULT_TOKEN}}"
  if [ -n "${secret_path}" ]; then
    vault-curl "${VAULT_ADDR}/v1/${secret_path#/*}" "${vToken}"
  fi
}

# Curl Vault with token
# vault-list </secret/path> [token]
vault-list () {
  local secret_path="${1}"
  local vToken="${2:-${VAULT_TOKEN}}"
  if [ -n "${secret_path}" ]; then
    vault-curl "${VAULT_ADDR}/v1/${secret_path#/*}" "${vToken}" "--request LIST"
  fi
}

# Copy vault secret from current vault cluster to another cluster
# vault-sync <target-vault-profile> </secret/path>
vault-sync() {
  local target_vault=${1}
  local full_secret_path="${2}"
  local source_vault=${3:-$VAULT_PROFILE}
    if [ -z ${full_secret_path} ]; then
      echo "must provide secret path"
      return 1
    fi
    vault-profile ${source_vault}

    # Check if path is list of endpoints and recursively parse each
    local list_json=$( vault list -format=json ${full_secret_path} 2>/dev/null | jq -r '.[]' )
    if [[ "${list_json[@]}" ]]; then
      for secret_path in ${list_json[@]}; do
        local vault_path="$(echo "/${full_secret_path}/${secret_path}/" | sed 's/\/\//\//g' )"
        echo -e "\n${source_vault}->${target_vault} ${vault_path}"
        vault-sync "${target_vault}" "${vault_path}" "${source_vault}"
      done
      return
    fi

    # Check if endpoint is empty
    local read_json=$( vault read -format=json ${full_secret_path} 2>/dev/null | jq -r '.data' )    
    if [[ -z "${read_json[@]}" ]]; then
      echo "No values found for ${full_secret_path}"
      return 1
    fi

    # Read secrets from endpoint
    local endpoint_engine="$( vault read -format=json /sys/mount/${full_secret_path} 2>/dev/null | jq -r '.data.type' )"

    vault-profile ${target_vault}
    local synced="true"
    local secrets=""
    local vault_key=""
    local vault_value""
    local target_json=$( vault read -format=json ${full_secret_path} 2>/dev/null | jq -r '.data' )
    if [[ ! $(jq-diff "${read_json}" "${target_json}") ]]; then 
      echo "${color[info]}SYNCED:${color[default]} ${full_secret_path}"
      vault-profile ${source_vault}
      return
    fi

    while read line; do
      if [[ "${line}" =~ '{' || "${line}" =~ '}' ]]; then continue; fi
      local quotes=${line//[^\"]/}
      if (( ${#quotes} != 4 )); then echo "${color[error]}ERROR:${color[default]} ${line}"; continue; fi

      vault_key="$(echo ${line} | cut -d '"' -f 2)"
      vault_value="$(echo ${line} | cut -d '"' -f 4)"
      if [[ -z "${target_json}" ]]; then 
        synced="false"
      elif [[ ! $(echo "${target_json}" | grep -q "${vault_key}.*${vault_value}") ]]; then
        echo -e "${color[warn]}DIFFERENT:${color[default]} $(echo "${target_json}" | grep "${vault_key}")"
      fi
      secrets="${secrets} ${vault_key}=${vault_value}"

    done <<<$(echo "${read_json[@]}" | jq -r 'to_entries[] | [.key, .value] | @csv' )
    vault-set-endpoint "${full_secret_path%secret/*}secret/" "${endpoint_engine:-generic}" "${target_vault}"
    vault write ${full_secret_path} ${secrets}
    vault-profile ${source_vault}
}

# Check for secret endpoint and enable if missing
# vault-set-endpoint <Path for Endpoint> <Enpoint Engine Type>
vault-set-endpoint() {
  local endpoint="${1}"
  local engine="${2}"
  local original_profile="${VAULT_PROFILE}"
  local profile="${3:-$VAULT_PROFILE}"
  if [[ -z ${endpoint} ]] || [[ -z ${engine} ]]; then
    echo "must provide endpoint and secret engine"
    return 1
  fi
  vault-profile "${profile}"
  # Needs updated for older versions of vault < 1.0
  if [[ -z "$( v read -format=json /sys/mounts/${endpoint} 2>/dev/null | jq -r '.data.type' )" ]]; then
    echo "${color[warn]}MISSING:${color[default]} ${endpoint} ${engine}"
    v secrets enable -path=${endpoint} ${engine}
  fi
  vault-profile "${original_profile}"
}

# Set Vault ENV variables per $VAULTS[?] index
# vault-profile <profile_name>
vault-profile() {
  local profile="$(upper ${1})"
  export VAULT_ADDR="${VAULTS[${profile}]}"
  export VAULT_TOKEN="${TOKENS[${profile}]}"
  export VAULT_PROFILE="${profile}"
}

# Get the password field from a secret
# vault-rds-lookup [customerId] [env]
vault-rds-lookup() {
  local key_path=${1:-respond}
  local env=${2:-prod}
      rds_secret=$(v read ${env}/${key_path}/secret/rds | awk /'password/ {print $2}' 2> /dev/null)
  echo "${rds_secret}"
}

# Iterate through VAULTS and check for port access
# vault-status-report
vault-status-report() {
  for vault in ${!VAULTS[@]}; do
    echo -n "${vault} : ${VAULTS[${vault}]} "
    vault-profile ${vault}
    if [ $(nc -z -w5 $(echo ${VAULTS[${vault}]#*//} | sed 's/:/ /')) ]; then
      echo "${color[good]}OPEN${color[default]}"
    else
      echo "${color[bad]}OPEN${color[default]}"
    fi
  done
}

# Get IP addresses of vault nodes 
# vault-nodes [region]
vault-nodes() {
  local region=${1:-"us-west-2"}
  local name=${2:-"*vault_asg_node"}
  aws ec2 describe-instances --region ${region} --filter Name=tag:Name,Values=${name} | jq -r '.Reservations[].Instances[].PrivateIpAddress'
}

# Get IP addresses of vault nodes 
# vault-debug-logs [region]
vault-debug-logs() {
  local region=${1:-"us-west-2"}
  local name=${2:-"*vault_asg_node"}
  local nodes=$(vault-nodes ${region} ${name})
  for n in ${nodes[@]}; do
    ssh -i ${VAULT_SSH} ec2-user@$n 'sudo journalctl -b --no-pager -u vault | gzip -9 > /tmp/"$(hostname)-$(date +%Y-%m-%dT%H-%M-%SZ)-vault.log.gz"'
    scp -i ${VAULT_SSH} ec2-user@$n:/tmp/*vault.log.gz ~/tmp/
  done
}

# Pull vault secrets and add values
# vault-append-secret [full secret path] [key] [value]
vault-append-secret() {
  local v_path="${1}"
  local v_key="${2}"
  local v_value="${3}"
  local v_json="$(v read -format json -field data ${v_path})"
  local v_current="$(echo "${v_json}" | jq \"."${v_key}"\")"
  if [ -n "${v_current}" ] && [ "${v_current}" != "${v_value}" ]; then
    # echo "Overwriting existing secret key: ${v_key}"    
    # read -p "continue? (y/n) " confirm
    # if [ "${confirm}" != "y" ] && [ "${confirm}" != "Y" ]; then
    #   echo "quit" 
    #   return
    # fi
    echo "${v_json}" | jq ".${v_key} = \"${v_value}\"" | v write ${v_path} -
  fi
}

# Check for new update to vault
vault-check-binary() {
  if [ -n "$(common-utilities 'vault' )" ]; then return 1; fi
  local version="$(vault version | awk '{print $2}')"
  local latest="$(brew info vault | grep stable | awk '{print $3}')"  
  if [ "${version}" != "v${latest}" ]; then
    echo "New vault version available. Current: ${version}, Latest: v${latest}"
  fi
}

# Read secrets and then base64 encode them. Usefule for k8s secrets
# vault-base64 </secret/path/>
vault-base64() {
  local secret_path=${1:-"/usw2/respond/secret/elastic-logs"}
  v read -format json -field data "${secret_path}" | jq -r '. | map_values(@base64)'
}


# Compare default vault version to server version
# Then attempt to download and run commands on matching versions
vault-check-server-binary() {
  local server="$(vault status --tls-skip-verify -format=json | jq -r '.version' | cut -d+ -f1)"
  local client="$(vault version | awk '{print $2}' | sed 's/v//' )"
  local version
  if [ "${server}" != "${client}" ]; then
    if [ ! "$(command -v vault${server})" ]; then
      wget -q -P /tmp/ https://releases.hashicorp.com/vault/${server}/vault_${server}_linux_amd64.zip
      if [ -f "/tmp/vault_${server}_linux_amd64.zip" ]; then
        unzip /tmp/vault_${server}_linux_amd64.zip -d /tmp
        sudo mv /tmp/vault /usr/local/bin/vault${server}
      else
        \vault $@
        return
      fi
    fi
    \vault${server} $@
  else
    \vault $@
  fi
}

# Apply proxy settings temporarily to run vault command
# vault-proxy [subcommand] [addtional arguments]
vault-proxy() {
  case $(lower "${VAULT_PROFILE}") in
    apse1|apse2|euw1) 
      proxy-set 10101;;
    *)
      proxy-set 10100;;
  esac
  if [[ -f "${HOME}/vault-${VAULT_PROFILE}.pem" ]]; then
    local subcommand=$1
    shift
    vault-check-server-binary ${subcommand} -ca-cert ${HOME}/vault-${VAULT_PROFILE}.pem $@ 
  else
    vault-check-server-binary $@ 
  fi
  if [ -n ${PROXY} ]; then
    eval ${PROXY}
  else
    noproxy
  fi
}

# Save the CA cert of a trusted host to a file
# vault-pull-cert [file save path] [URI without protocol]
vault-pull-cert() {
  local filepath=${1:-${HOME}/vault-${VAULT_PROFILE}.pem}
  local host=${2:-${VAULT_ADDR##*/}}
  local cert=$(proxychains openssl s_client -showcerts \
                    -connect ${host} \
                    -servername ${host} </dev/null 2>/dev/null | \
                    openssl x509 -outform pem)
  if [[ -n "${cert}" ]]; then
    echo -n "${cert}" > ${filepath}
  fi
}

# Safely report your vault environment variables
# vault-env
vault-env() {
  local varname varvalue
  for e in $(env | grep VAULT); do
    if [[ -n "$(echo $e | grep TOKEN)" ]]; then
      varname=$(echo $e | cut -d= -f1)
      varvalue=$(echo $e | cut -d= -f2 | sed 's/./\*/g')
      echo "${varname}=${varvalue}"
    else 
      echo $e
    fi
  done
}

alias v='vault-proxy'
alias vt='vault-profile'

# If you source this file directly, apply the overwrites.
if [ -z "$(echo "$(script_origin)" | grep -F "shrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi