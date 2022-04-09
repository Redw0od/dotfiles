
sh_source
_this="$( script_source )"
_sources+=("$(basename ${_this})")

UTILITIES+=("echo" "awk" "grep" "cat" "ssh" "ssh-agent" "sed" "cut" "ssh-keygen" "ssh-add" "nc")
abbr='ssh'
# Gives details on functions in this file
# Call with a function's name for more information
eval "${abbr}-help () {
  local func=\"\${1}\"
  local func_names=\"\$(cat ${_this} | grep '^${abbr}.*()' | awk '{print \$1}')\"
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


# Start ssh-agent if its not running
ssh-check-agent () {
	if [ -z "${SSH_AGENT_PID}" ]; then
		ssh-start-agent
	elif ! kill -s 0 ${SSH_AGENT_PID} 2>/dev/null; then
		ssh-start-agent
	elif [ ! -e "${SSH_AUTH_SOCK}" ]; then
		ssh-start-agent
	fi
}

# Start ssh-agent and export the shell variables
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
	if [ "${SSH_PROFILE}" != "${1}" ]; then
		if [ ! -d "${folder}" ];then
			echo "SSH profile folder ${folder} doesn't exist"
			return 1
		elif [ -f "${folder}/agent.sh" ]; then
			source "${folder}/agent.sh"
		else
			unset $(export | grep SSH_ | awk '{print $3}' | cut -d '=' -f 1)
		fi
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

# If you source this file directly, apply the overwrites.
if [ -z "$(echo "$(script_origin)" | grep -F "shrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi