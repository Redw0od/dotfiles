THIS="$( basename ${BASH_SOURCE[0]} )"
SOURCE[$THIS]="${THIS%/*}"
echo "RUNNING ${THIS}"

UTILITIES+=("echo" "awk" "grep" "rev" "git" "cut" )

# Gives details on functions in this file
# Call with a function's name for more information
git-help () {
  local func="${1}"
  local func_names="$(cat ${BASH_SOURCE[0]} | grep '^git-' | awk '{print $1}')"
  if [ -z "${func}" ]; then
    echo "Helpful git functions."
    echo "For more details: ${GREEN}git-help [function]${NORMAL}"
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

# PS1 output for git profile
git-ps1-color () {
  local main=$(git-origin 2>/dev/null)
  if [[ ! "${main}" ]]; then return; fi
  local branch=$(git rev-parse --abbrev-ref HEAD)
  echo -e -n "(${LIGHTMAGENTA}git${GRAY}["
  if [[ "${branch}" == "${main}" ]]; then 
    echo -e -n "${RED}${branch}${GRAY}"
  else
    echo -e -n "${NORMAL}${branch}${GRAY}"
  fi
  echo -e "]${DARKGRAY})-"
}

# Pulls the current git repo.
# git-call git-pull 
git-pull () {
  local result="$(git pull)"
  echo "${result}"
}

# Returns main git branch of repo
# git-call git-origin
git-origin () {
  local result="$(git remote show origin | grep 'HEAD branch:' | rev | cut -d ' ' -f 1 | rev )"
  echo "${result}"
}

# Returns current git branch of repo. 
# git-call git-branch
git-branch () {
  local result="$(git status | grep 'On branch' | rev | cut -d ' ' -f 1 | rev )"
  echo "${result}"
}

# Changes directory to git repo, performs function then returns
# to origional directory
# git-call [function] [git path]
git-call () {  
  local active_dir="$(pwd)"
  local dir="${2:-${active_dir}}"
  local function="${1}"
  if [ ! -d "${dir}/.git" ]; then return 1; fi
  cd "${dir}"
  local account="$(git config --get remote.origin.url | grep -o -P '(?<=:).*?(?=/)')"
  ssh-git-account "${account}"
  local value="$(eval ${function})"
  local code=$?
  if [ ! -z "${value}" ]; then echo "${value}"; else return ${code}; fi
  cd "${active_dir}"
}

# Update cached main branch for specified repo
# git-latest-main [git path]
git-latest-main () {
  local git_dir=${1:-$(pwd)}
  local origin="$(git-call git-origin ${git_dir})"
  local branch="$(git-call git-branch ${git_dir})"
  banner " origin: ${origin}, branch: ${branch} "
  if [ "${origin}" = "${branch}" ]; then 
    git-call git-pull "${git_dir}"
  else
    git-call "git fetch origin ${origin}:${origin}" "${git_dir}"
  fi
}

# Update cached main branch for all repos in $GITHOME
# git-latest-main [$GITHOME]
git-update-main () {
  local git_dir="${1:-$GITHOME}"
  for d in $(dirname $(find ${git_dir} -type d -name ".git" )); do 
    echo -e "\nRepo: ${d}"
    git-latest-main ${d}
  done
}

alias gitpull='git-call git-pull'
alias g='git-call; git'


# If you source this file directly, apply the overwrites.
if [ -z "$(echo "${BASH_SOURCE[*]}" | grep -F "bashrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi