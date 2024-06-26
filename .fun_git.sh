
sh_source
_this="$( script_source )"
_sources+=("$(basename ${_this})")

UTILITIES+=("echo" "awk" "grep" "rev" "git" "cut" "gh")
abbr='git'
# Gives details on functions in this file
# Call with a function's name for more information

# Create help function for this file
common-help "${abbr}" "${_this}"

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
  local result="$(git rev-parse --abbrev-ref HEAD )"
  echo "${result}"
}

# Changes directory to git repo, performs function then returns
# to origional directory
# git-call [function] [git path]
git-call () {
  local active_dir="$(pwd)"
  local dir="${2:-${active_dir}}"
  local function="${1}"
  local crd_set=${CHROME_REMOTE_DESKTOP_SESSION}
  unset CHROME_REMOTE_DESKTOP_SESSION
  if [ ! -d "${dir}/.git" ]; then return 1; fi
  pushd "${dir}" > /dev/null
  local account="$(git config --get remote.origin.url | sed 's/.*://' | sed 's/.*\.com\///')"
  ssh-git-account "${account%%/*}"
  local value="$(eval ${function})"
  local code=$?
  if [ "$crd_set" = "1" ]; then
    export CHROME_REMOTE_DESKTOP_SESSION=1
    export SSH_AUTH_SOCK="${FWD_SSH_AUTH_SOCK}"
  fi
  ssh-fix-sock
  if [ ! -z "${value}" ]; then echo "${value}"; else return ${code}; fi
  popd > /dev/null
}

# Update cached main branch for specified repo
# git-latest-main [git path]
git-latest-main () {
  local git_dir=${1:-$(pwd)}
  local origin="$(git-call git-origin ${git_dir})"
  local branch="$(git-call git-branch ${git_dir})"
  banner " $(basename ${git_dir}) "
  if [ "${origin}" = "${branch}" ]; then
    banner " origin: ${origin}, branch: ${branch} "
    git-call git-pull "${git_dir}"
  else
    banner " origin: ${origin}, branch: ${color[WARN]}${branch}${color[default]} "
    git-call "git fetch origin ${origin}:${origin}" "${git_dir}"
  fi
}

# Update cached main branch for all repos in $GITHOME
# git-update-main [$GITHOME]
git-update-main () {
  local git_dir="${1:-$GITHOME}"
  for d in $(dirname $(find ${git_dir} -type d -name ".git" )); do
    echo -e "\nRepo: ${d}"
    git-latest-main "${d}" &
  done
}

# Update cached main branch for all repos in $GITHOME
# git-status-report [$GITHOME]
git-status-report () {
  local git_dir="${1:-$GITHOME}"
  for d in $(dirname $(find ${git_dir} -type d -name ".git" )); do
    git-status "${d}" &
  done
}

# Update cached main branch for specified repo
# git-latest-main [git path]
git-status () {
  local git_dir=${1:-$(pwd)}

    echo -e "\nRepo: ${git_dir}\n$(git-call "git status --short" "${git_dir}")\n"
}

# Find all repos owned by a user and clone them
# git-clone-all <owner>
git-clone-all () {
  local owner="${1}"
  if [ -z "${owner}" ]; then return 1; fi
  if [ -n "$(common-utilities 'gh' 'git' )" ]; then return 1; fi
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


# Print a list of projects owned by a group ID
# gitlab-list-projects <group Id>
gitlab-list-projects () {
  local group_id=${1}
  if [ -z "${group_id}" ]; then return;fi
  local projects=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" https://gitlab.com/api/v4/groups/${group_id} | jq -r '.projects[].path_with_namespace')
  for project in ${projects[@]}; do
    printf '%s\n' "${project}"
  done
}

# Print a list of subgroups owned by a group ID
# gitlab-list-groups <group Id>
gitlab-list-groups () {
  local group_id=${1:-11464447}
  local id_only=${2}
  local subgroups=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" https://gitlab.com/api/v4/groups/${group_id}/subgroups/ | jq '.[].id')
  if [ -z "${id_only}" ]; then
    curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" https://gitlab.com/api/v4/groups/${group_id}/subgroups/ | jq -r '.[] | [.id,.full_path] | @tsv' | sort | column  -t -s$'\t' -n -
  fi
  for group in ${subgroups[@]}; do
    if [ -n "${id_only}" ]; then
      printf '%s\n' "${group}"
    fi
    gitlab-list-groups ${group} ${id_only}
  done
}

# Print a list of all projects in group and subgroups
# gitlab-list-all-projects <root group Id>
gitlab-list-all-projects () {
  local group_id=${1:-11464447}
  local groups=$(gitlab-list-groups ${group_id})
  for group in ${groups[@]}; do
    gitlab-list-projects ${group}
  done
}

alias gitpull='git-call git-pull'
alias g='git-call; git'

# If you source this file directly, apply the overwrites.
if [ -z "$(echo "$(script_origin)" | grep -F "shrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi
