
sh_source
_this="$( script_source )"
_sources+=("$(basename ${_this})")

UTILITIES+=("echo" "awk" "grep" "cat" "terraform" "terragrunt" "brew" )
abbr='tg'

# Create help function for this file
common-help "${abbr}" "${_this}"

# Set module source var for local modules
# tgsource [path to repo] [module]
tgsource () {
  export TG_SOURCE="--terragrunt-source $1/$2"
}

# Check if terraform tools are installed and up to date
tg-check-binary () {
  if [[ -z "$(command -v terraform)" ]]; then
    echo "install terraform"
    return 1
  fi
  if [[ -z "$(command -v terragrunt)" ]]; then
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

alias tg='terragrunt'
alias tgplan='rm -rf .terragrunt-cache;tg plan'

# If you source this file directly, apply the overwrites.
if [ -z "$(echo "$(script_origin)" | grep -F "shrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi