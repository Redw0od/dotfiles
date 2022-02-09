THIS="$( basename ${BASH_SOURCE[0]} )"
SOURCE[$THIS]="${THIS%/*}"
echo "RUNNING ${THIS}"

UTILITIES+=("echo" "awk" "grep" "cat" "vault" "jq" "cut" "nc" )

# Gives details on functions in this file
# Call with a function's name for more information
vault-help () {
  local func="${1}"
  local func_names="$(cat ${BASH_SOURCE[0]} | grep '^vault-' | awk '{print $1}')"
  if [ -z "${func}" ]; then
    echo "Helpful vault functions."
    echo "For more details: ${GREEN}vault-help [function]${NORMAL}"
    echo "${func_names[@]}"
    return
  fi
  cat "${BASH_SOURCE[0]}" | \
  while read line; do
		if [ -n "$(echo "${line}" | grep -F "${func} ()" )" ]; then
      banner " function: $func " "" ${GRAY} ${GREEN}
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
  banner "" "" ${GRAY}
}


# PS1 output for Vault profile
vault-ps1-color () {
  case "${VAULT_PROFILE}" in
    gov)
      echo -e "${ORANGE}${VAULT_PROFILE}${NORMAL}"
      ;;
    test)
      echo -e "${GRAY}${VAULT_PROFILE}${NORMAL}"
      ;;
    *)
      echo -e "${RED}${BOLD}${VAULT_PROFILE}${NORMAL}"
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

# If you source this file directly, apply the overwrites.
if [ -z "$(echo "${BASH_SOURCE[*]}" | grep -F "bashrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi