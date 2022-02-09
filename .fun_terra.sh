THIS="$( basename ${BASH_SOURCE[0]} )"
SOURCE[$THIS]="${THIS%/*}"
echo "RUNNING ${THIS}"

UTILITIES+=("echo" "awk" "grep" "cat" "terraform" "terragrunt" "brew" )

# Gives details on functions in this file
# Call with a function's name for more information
tg-help () {
  local func="${1}"
  local func_names="$(cat ${BASH_SOURCE[0]} | grep '^tg-' | awk '{print $1}')"
  if [ -z "${func}" ]; then
    echo "Helpful Terraform functions."
    echo "For more details: ${GREEN}tg-help [function]${NORMAL}"
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

# Set module source var for local modules
tgsource () {
  export TG_SOURCE="--terragrunt-source $1/$2"
}

# Check if terraform tools are installed and up to date
tg-check-binary () {
  if [[ -z "$(which terraform)" ]]; then
    echo "install terraform"
    return 1
  fi
  if [[ -z "$(which terragrunt)" ]]; then
    echo "install terragrunt"
    return 1
  fi
  local tversion="$(terraform version -json | jq -r '.terraform_version')" 
  if [[ "$(terraform version -json | jq -r '.terraform_outdated')" == "true" ]]; then
    echo "New terraform version available. Current: ${tversion}"
    echo "brew upgrade terraform"
  fi
  local tgversion="$(terragrunt -version | awk '{print $3}' )" 
  if [[ "$(brew outdated terragrunt )" ]]; then
    echo "New terragrunt version available. Current: ${tgversion}"
    echo "brew upgrade terragrunt"
  fi
}

# If you source this file directly, apply the overwrites.
if [ -z "$(echo "${BASH_SOURCE[*]}" | grep -F "bashrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi