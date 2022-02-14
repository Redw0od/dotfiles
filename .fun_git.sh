
sh_source
_this="$( script_source )"
_sources+=("$(basename ${_this})")

UTILITIES+=("echo" "awk" "grep" "rev" "git" "cut" "gh")

# Gives details on functions in this file
# Call with a function's name for more information
git-help () {
  local func="${1}"
  local func_names="$(cat ${_this} | grep '^git-' | awk '{print $1}')"
  if [ -z "${func}" ]; then
    echo "Helpful git functions."
    echo "For more details: ${color[green]}git-help [function]${color[default]}"
    echo "${func_names[@]}"
    return
  fi
  cat "${BASH_SOURCE[0]}" | \
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

# PS1 output for git profile
git-ps1-color () {
  local main=$(git-origin 2>/dev/null)
  if [[ ! "${main}" ]]; then return; fi
  local branch=$(git rev-parse --abbrev-ref HEAD)
  echo -e -n "(${color[lightmagenta]}git${color[gray]}["
  if [[ "${branch}" == "${main}" ]]; then 
    echo -e -n "${color[red]}${branch}${color[gray]}"
  else
    echo -e -n "${color[default]}${branch}${color[gray]}"
  fi
  echo -e "]${color[darkgray]})-"
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
  pushd "${dir}"
  local account="$(git config --get remote.origin.url | grep -o -P '(?<=:).*?(?=/)')"
  ssh-git-account "${account}"
  local value="$(eval ${function})"
  local code=$?
  if [ ! -z "${value}" ]; then echo "${value}"; else return ${code}; fi
  popd "${active_dir}"
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

git-clone-all () {
  local owner="${1}"
  if [ -z "${owner}" ]; then return 1; fi
  if [ -n "$(shell-utilities 'gh' 'git' )" ]; then return 1; fi
  if [ ! -d "${GITHOME}/${owner}" ]; then mkdir -p "${GITHOME}/${owner}"; fi
  pushd "${GITHOME}/${owner}" > /dev/null
  local repos=($(gh repo list "${owner}" | awk '{print $1}' ))
  for repo in "${repos[@]}"; do
    if [ ! -d "${GITHOME}/${repo}" ]; then 
      git clone git@github.com:${repo}.git
    else
      echo "${GITHOME}/${repo} already exists"
    fi
  done
  popd > /dev/null
}

alias gitpull='git-call git-pull'
alias g='git-call; git'


# If you source this file directly, apply the overwrites.
if [ -z "$(echo "$(script_origin)" | grep -F "shrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi