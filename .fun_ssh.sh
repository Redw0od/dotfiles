
sh_source
_this="$( script_source )"
_sources+=("$(basename ${_this})")

UTILITIES+=("echo" "awk" "grep" "cat" "ssh" "ssh-agent" "sed" "cut" "ssh-keygen" "ssh-add" "nc")
abbr='ssh'

# Create help function for this file
common-help "${abbr}" "${_this}"

# ssh-check-agent will check if SSH_AGENT_PID is set then
# check the process exists with kill -s 0, then check the sock file exists
# If any check fails, then the agent is started
# Then cleans up any ssh-agent processes that aren't associated with a profile
ssh-check-agent () {
	if [ -z "${SSH_AGENT_PID}" ]; then
		ssh-start-agent
	elif ! kill -s 0 ${SSH_AGENT_PID} 2>/dev/null; then
		ssh-start-agent
	elif [ ! -e "${SSH_AUTH_SOCK}" ]; then
    echo "${SSH_AUTH_SOCK}"
		ssh-start-agent
	fi
  local agents=($(ps aux | grep '[s]sh-agent' | awk '{print $2}' | sort -u | grep -v ${SSH_AGENT_PID}))
  for p in $(find $HOME/.ssh/*/agent.sh); do
    source $p
    agents=($(printf '%s\n' "${agents[@]}" | grep -v ${SSH_AGENT_PID}))
    if ! kill -s 0 ${SSH_AGENT_PID} 2>/dev/null ; then
      rm -f $p
    fi
  done
  if [[ -n "${agents[*]}" ]]; then
    printf '%s\n' "${agents[@]}" | xargs kill
  fi
  if [[ -e "${HOME}/.ssh/${SSH_PROFILE}/agent.sh" ]]; then
    source ${HOME}/.ssh/${SSH_PROFILE}/agent.sh
  fi
}

# Start ssh-agent and save shell variables to .ssh/profile/agent.sh
# then source the variables into the shell
ssh-start-agent () {
	local folder="${HOME}/.ssh"
	local config="${folder}/${SSH_PROFILE}/agent.sh"
    echo "Initialising new SSH agent..."
    /usr/bin/ssh-agent | sed 's/^echo/#echo/' > "${config}"
    chmod 600 "${config}"
    source "${config}" > /dev/null
}

# Load all SSH keys in ~/.ssh subfolder into ssh-agent
ssh-load-keys () {
	local folder="${HOME}/.ssh/${1}"
	local filter="${2}"
	if [[ -n "${SSH_AUTH_SOCK}" ]] && [[ -z "${FWD_SSH_AUTH_SOCK}" ]]; then
		export FWD_SSH_AUTH_SOCK="${SSH_AUTH_SOCK}"
	fi
  if [ ! -d "${folder}" ];then
    echo "SSH profile folder ${folder} doesn't exist"
    return 1
  elif [ -f "${folder}/agent.sh" ]; then
    source "${folder}/agent.sh"
  else
    unset $(export | grep ' SSH_' | awk '{print $3}' | cut -d '=' -f 1)
  fi
	export SSH_PROFILE="${1}"
	ssh-check-agent
	local fingerprints=$(ssh-add -l 2> /dev/null | awk '{print $2}')
	for object in ${folder}/*; do
		if [[ -n "${filter}" ]] && [[ -z "$(echo ${object} | grep ${filter})" ]]; then continue; fi
		if [[ -f ${object} ]] && [[ ! -z "$( head -n 1 ${object} | grep "PRIVATE KEY")" ]]; then
			local fingerprint="$(ssh-keygen -lf ${object} | awk '{print $2}' )"
			if [[ ! "${fingerprints[@]}" =~ "${fingerprint}" ]]; then
				ssh-add ${object} > /dev/null 2>&1
			fi
		fi
	done
}

# Unload all keys in ssh-agent
ssh-unload-keys () {
	ssh-check-agent
	ssh-add -D > /dev/null
}

# Intended to automate changing SSH keys when you have more than 1 github account
# Modify this function to set company1, etc to the git account name
# Modify folder1, ect to a sub folder of your .ssh folder where your keys are
ssh-git-account () {
  local account="${1}"
  case ${account} in
    #company1) ssh-load-keys folder1;;
    #company2) ssh-load-keys folder2;;
    #personal) ssh-load-keys home;;
    *) ssh-load-keys "";;
  esac
}

# Test connectivity to port 22 on host
# ssh-ping [host] [count] [delay]
ssh-ping () {
	declare -i count="${2}"
	declare -i delay=${3:-60}
	declare -i i=0
	while true; do
		nc -zv ${1} 22
		sleep ${delay}
		if [ -n ${count} ]; then ((i++)); fi
		if [ ${i} -ge ${count} ]; then return; fi
	done
}

# List ssh tunnels defined in config file
# ssh-list-tunnels [path_to_config]
ssh-list-tunnels () {
	local config=${1:-"${HOME}/.ssh/config"}
	local host port
	while read; do
		if [ -n "$(echo "${REPLY}"| grep '^Host ' )" ]; then
			host="$(echo "${REPLY}"| awk '{print $2}')"
		elif [ -n "$(echo "${REPLY}"| grep 'DynamicForward ' )" ]; then
			port="$(echo "${REPLY}"| awk '{print $2}')"
		fi
		if [ -n "${host}" ] && [ -n "${port}" ]; then
			echo "${host} ${port}"
			host=""
			port=""
		fi
	done <<<$(cat ${config})
}

# Cycle through SSH sockets and export active socket
# ssh-fix-sock
ssh-fix-sock() {
	local socket
  local found
	for i in $(find /tmp/ssh-* -type s); do
    found="false"
		if [[ -n "$(SSH_AUTH_SOCK=${i} timeout 10s ssh-add -l | grep 'corp/normal')" ]]; then
			socket=$i
      export SSH_AUTH_SOCK="${socket}"
      continue
		fi
    for p in $(find $HOME/.ssh/*/agent.sh); do
      source $p
      if [[ "${i}" == "${SSH_AUTH_SOCK}" ]]; then
        found="true"
        continue
      fi
    done
    if [[ "${found}" == "true" ]]; then continue; fi
    rm -rf ${i%/*}
	done
  if [[ -n "${SSH_PROFILE}" ]] && [[ -f "${HOME}/.ssh/${SSH_PROFILE}/agent.sh" ]]; then
    source ${HOME}/.ssh/${SSH_PROFILE}/agent.sh
  fi
  if [[ -e "$HOME/.tmp/.${USER}.ssh_auth_sock" ]]; then
    export FWD_SSH_AUTH_SOCK="$HOME/.tmp/.${USER}.ssh_auth_sock"
  else
    export FWD_SSH_AUTH_SOCK="${socket}"
  fi
}

# Verify an ssh tunnel is listening by name
# ssh-check-tunnel [host_name_from_config] [path_to_config]
ssh-check-tunnel() {
	local hostname=${1}
	local config=${2:-"${HOME}/.ssh/config"}
	local host port
	while read tunnel; do
		host="$(echo ${tunnel} | awk '{print $1}')"
		port="$(echo ${tunnel} | awk '{print $2}')"
		if [ "${hostname}" = "${host}" ]; then
			echo "$(netstat -tulpn 2> /dev/null | grep ":${port} ")"
			return
		elif [ -z "${hostname}" ]; then
			echo "$(netstat -tulpn 2> /dev/null | grep ":${port} ")"
		fi
	done <<<$(ssh-list-tunnels ${config})
}

# Verify an ssh tunnel is listening by name
# ssh-start-tunnel [host_name_from_config] [path_to_config]
ssh-start-tunnel() {
	local hostname=${1}
	local config=${2:-"${HOME}/.ssh/config"}
	local host port
	while read tunnel; do
		host="$(echo ${tunnel} | awk '{print $1}')"
		port="$(echo ${tunnel} | awk '{print $2}')"
		if [ "${hostname}" = "${host}" ] && [ -z "$(ssh-check-tunnel ${host})" ]; then
			ssh -fN ${host}
			return
		fi
		if [ -z "${hostname}" ] && [ -z "$(ssh-check-tunnel ${host})" ]; then
			ssh -fN ${host}
		fi
	done <<<$(ssh-list-tunnels ${config})
}

# Kill an ssh tunnel
# ssh-kill-tunnel [host_name_from_config] [path_to_config]
ssh-kill-tunnel() {
	local hostname=${1}
	local config=${2:-"${HOME}/.ssh/config"}
	local host port pid
	while read tunnel; do
		host="$(echo ${tunnel} | awk '{print $1}')"
		port="$(echo ${tunnel} | awk '{print $2}')"
		if [ "${hostname}" = "${host}" ]; then
			pid="$(ps | grep "[s]sh.*${host}" | awk '{print $2}')"
			if [ -n "${pid}" ]; then
				kill "${pid}"
			fi
			return
		elif [ -z "${hostname}" ]; then
			pid="$(ps | grep "[s]sh.*${host}" | awk '{print $2}')"
			if [ -n "${pid}" ]; then
				kill "${pid}"
			fi
		fi
	done <<<$(ssh-list-tunnels ${config})
}

# Keep tunnels up function
# ssh-tunnels [host_name_from_config] [path_to_config]
ssh-tunnels() {
	local sleep=${1:-30}
	local timeout=${2:-$((60*60*8))}
	local hostname=${3}
	local config=${1:-"${HOME}/.ssh/config"}
	local timer=$(date +%s)
	while true; do
		ssh-ps1-tunnels
		sleep 3
		ssh-start-tunnel "${hostname}" "${config}"
		sleep ${sleep}
		if [ $(($(date +%s)-timer)) -gt ${timeout} ]; then
			break
		fi
	done
}

# Verify an ssh tunnel is listening by name
# ssh-check-tunnel [host_name_from_config] [path_to_config]
ssh-ps1-tunnels() {
	local config=${1:-"${HOME}/.ssh/config"}
	local host port
	while read tunnel; do
		host="$(echo ${tunnel} | awk '{print $1}')"
		port="$(echo ${tunnel} | awk '{print $2}')"
		if [ -n "$(netstat -tulpn 2> /dev/null | grep ":${port} ")" ]; then
			echo -n "${color[bright]}${color[success]}↑${color[default]}"
		else
			echo -n "${color[fail]}${color[bright]}↓${color[default]}"
		fi
	done <<<$(ssh-list-tunnels ${config})
}

# If you source this file directly, apply the overwrites.
if [ -z "$(echo "$(script_origin)" | grep -F "shrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi
