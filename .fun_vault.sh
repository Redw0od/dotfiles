
sh_source
_this="$( script_source )"
_sources+=("$(basename ${_this})")

UTILITIES+=("echo" "awk" "grep" "cat" "vault" "jq" "cut" "nc" )

# Gives details on functions in this file
# Call with a function's name for more information
vault-help () {
  local func="${1}"
  local func_names="$(cat ${_this} | grep '^vault-' | awk '{print $1}')"
  if [ -z "${func}" ]; then
    echo "Helpful vault functions."
    echo "For more details: ${color[green]}vault-help [function]${color[default]}"
    echo "${func_names[@]}"
    return
  fi
  cat "${_this}" | \
  while read line; do
		if [ -n "$(echo "${line}" | grep -F "${func} ()" )" ]; then
      banner " function: $func " "" ${color[gray]} ${color[green]}
      echo -e "${comment}"
    fi
    if [ ! -z "$(echo ${line} | grep '^#')" ]; then 
      if [ ! -z "$(echo ${comment} | grep '^#')" ]; then
        comment="${comment}\n${line}"
      else
        comment="${line}"
      fi
    else
      comment=""
    fi
  done  
  banner "" "" ${color[gray]}
}


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


vault-sync () {
  local source_vault=${1}
  local target_vault=${2}
  local full_secret_path=${3}
   if [ -z ${full_secret_path} ]; then
     echo "must provide CustomerID"
     return 1
   fi
   #vault-profile ${source_vault}
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
}

vault-profile () {
  local profile="${1^^}"
  export VAULT_ADDR="${VAULTS[${profile}]}"
  export VAULT_TOKEN="${TOKENS[${profile}]}"
  export VAULT_PROFILE="${profile}"
}

vault-rds-lookup () {
  local env=${2:-prod}
  vault-profile primary
  local rds_secret=$(vault kv get -field=password ${2}/${1}/secret/rds/ 2> /dev/null)
  if [ -z "${rds_secret}" ]; then 
      vault-profile legacy
      rds_secret=$(vault read ${2}/${1}/secret/rds/ | awk /'password/ {print $2}' 2> /dev/null)
      vault-profile primary
  fi
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

# If you source this file directly, apply the overwrites.
if [ -z "$(echo "$(script_origin)" | grep -F "shrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi