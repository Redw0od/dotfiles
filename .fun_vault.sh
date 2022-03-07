
sh_source
_this="$( script_source )"
_sources+=("$(basename ${_this})")

UTILITIES+=("echo" "awk" "grep" "cat" "vault" "jq" "cut" "nc" )
abbr='vault'
# Gives details on functions in this file
# Call with a function's name for more information
eval "${abbr}-help () {
  local func=\"\${1}\"
  local func_names=\"\$(cat ${_this} | grep '^${abbr}-' | awk '{print \$1}')\"
  if [ -z \"\${func}\" ]; then
    echo \"Helpful Elasticsearch functions.\"
    echo \"For more details: \${color[green]}${abbr}-help [function]\${color[default]}\"
    echo \"\${func_names[@]}\"
    return
  fi
  cat \"${_this}\" | \
  while read line; do
		if [ -n \"\$(echo \"\${line}\" | grep -F \"\${func} ()\" )\" ]; then
      banner \" function: \$func \" \"\" \${color[gray]} \${color[green]}
      echo -e \"\${comment}\"
    fi
    if [ ! -z \"\$(echo \${line} | grep '^#')\" ]; then 
      if [ ! -z \"\$(echo \${comment} | grep '^#')\" ]; then
        comment=\"\${comment}\n\${line}\"
      else
        comment=\"\${line}\"
      fi
    else
      comment=\"\"
    fi
  done  
  banner \"\" \"\" \${color[gray]}
}"


# PS1 output for Vault profile
vault-ps1-color () {
  case "${VAULT_PROFILE}" in
    gov)
      echo -e "${ORANGE}${VAULT_PROFILE}${color[default]}"
      ;;
    test)
      echo -e "${color[gray]}${VAULT_PROFILE}${color[default]}"
      ;;
    *)
      echo -e "${color[red]}${BOLD}${VAULT_PROFILE}${color[default]}"
      ;;
  esac
}


# Curl vault with token
# vault-curl <https://vault/path> [token]
vault-curl () {
  local cURL="${1}"
  local cToken="${2:-${VAULT_TOKEN}}"
  if [ -z ${cURL} ]; then echo "need URL"; return 1;fi
  if [ -z ${cToken} ]; then echo "missing Token";fi
  local H1="'Content-Type: application/json'"
  local H2="X-Vault-Token: ${cToken}"
  #echo "curl -sk ${cURL} -H ${H1} -H \"${H2}\""
  cmd "curl -sk ${cURL} -H ${H1} -H \"${H2}\""
}

# Curl Vault with token
# vault-get </secret/path> [token]
vault-get () {
  local secret_path="${1}"
  local vToken="${2:-${VAULT_TOKEN}}"
  echo "secretpath: ${secret_path}"
  echo "VAULT_ADDR: ${VAULT_ADDR}"
  if [ -n "${secret_path}" ]; then
  echo "path: ${VAULT_ADDR}/v1/${secret_path#/*}"
    vault-curl "${VAULT_ADDR}/v1/${secret_path#/*}" "${vToken}"
  fi
}

# Copy vault secret to another cluster
# vault-sync <vault-profile> </secret/path>
vault-sync () {
  local source_vault=${VAULT_PROFILE}
  local target_vault=${1}
  local full_secret_path="${2}"
   if [ -z ${full_secret_path} ]; then
     echo "must provide secret path"
     return 1
   fi
   local json=$( vault read ${full_secret_path} -format=json | jq -r '.data' )
   if [ -z "${json[@]}" ]; then
     echo "No values found for ${full_secret_path}"
     return 1
   fi
   IFS=$'\n'
   local secrets=""
   for line in $(echo ${json} | jq); do
      if [[ "${line}" =~ '{' || "${line}" =~ '}' ]]; then continue; fi
      echo $line
      local quotes=${line//[^\"]/}
      if (( ${#quotes} != 4 )); then echo "ERROR: ${line}"; continue; fi
      secrets="${secrets} $(echo ${line} | cut -d '"' -f 2)=$(echo ${line} | cut -d '"' -f 4)"
   done
   IFS=${IFS_BACKUP}
   vault-profile ${target_vault}
   vault write ${full_secret_path} ${secrets}
   vault-profile ${source_vault}
}

# Set Vault ENV variables per $VAULTS[?] index
# vault-profile <profile_name>
vault-profile () {
  local profile="${1^^}"
  export VAULT_ADDR="${VAULTS[${profile}]}"
  export VAULT_TOKEN="${TOKENS[${profile}]}"
  export VAULT_PROFILE="${profile}"
}

# Get the password field from a secret
# vault-rds-lookup <env> [customerId]
vault-rds-lookup () {
  local key_path=${1:-respond}
  local env=${2:-prod}
      rds_secret=$(vault read ${2}/${1}/secret/rds | awk /'password/ {print $2}' 2> /dev/null)
  echo "${rds_secret}"
}

vault-status-report () {
  for vault in ${!VAULTS[@]}; do
    echo "${vault} : ${VAULTS[${vault}]}"
    vault-profile ${vault}
    nc -zv $(echo ${VAULTS[${vault}]} )
  done
}

vault-append-secret () {
  local v_path="${1}"
  local v_key="${2}"
  local v_value="${3}"
  local v_json="$(vault read -format json -field data ${v_path})"
  local v_current="$(echo "${v_json}" | jq \"."${v_key}"\")"
  if [ -n "${v_current}" ] && [ "${v_current}" != "${v_value}" ]; then
    echo "Overwriting existing secret key: ${v_key}"    
    read -p "continue? (y/n) " confirm
    if [ "${confirm}" != "y" ] || [ "${confirm}" != "Y" ]; then
      echo "quit" 
      return
    fi
    echo "${json}" | jq ".${v_key} = \"${v_value}\""
    echo "vault write ${v_path} -"
  fi
}

# Check for new update to vault
vault-check-binary () {
  if [ -n "$(shell-utilities 'vault' )" ]; then return 1; fi
  local version="$(vault --version | awk '{print $2}')"
  local latest="$(brew info vault | grep stable | awk '{print $3}')"  
  if [ "${version}" != "v${latest}" ]; then
    echo "New vault version available. Current: ${version}, Latest: v${latest}"
  fi
}

# Read secrets and then base64 encode them. Usefule for k8s secrets
# vault-base64 </secret/path/>
vault-base64 () {
  local secret_path=${1:-"/usw2/respond/secret/elastic-logs"}
  vault read -format json -field data "${secret_path}" | jq -r '. | map_values(@base64)'
}


# Compare default vault version to server version
# Then attempt to download and run commands on matching versions
vault-check-server-binary () {
  local server="$(kubectl version -o json 2> /dev/null | jq -r '.serverVersion.gitVersion' | cut -d '-' -f 1)"
  local client="$(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')"
  if [ "${server}" != "${client}" ]; then
    if [ ! "$(which kubectl${server})" ]; then
      echo "Server version [${server}] mismatch client [${client}]"
      wget -q -P /tmp/ https://storage.googleapis.com/kubernetes-release/release/${server}/bin/linux/amd64/kubectl
      if [ -f "/tmp/kubectl" ]; then
        chmod +x /tmp/kubectl
        sudo mv /tmp/kubectl /usr/local/bin/kubectl${server}
      else
        echo "Failed to download matching kubectl version. Using default"
        kubectl $*
      fi
    fi
    kubectl${server} $*
  else
    kubectl $*
  fi
}

# If you source this file directly, apply the overwrites.
if [ -z "$(echo "$(script_origin)" | grep -F "shrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi