sh_source
_this="$( script_source )"
_sources+=("$(basename ${_this})")
declare -A REGISTRIES
declare -A RDS

abbr='mad'
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

# Read customer-configuration environments js and strip out unneeded lines
# mad-environments-js
mad-environments-js () {
    local config_repo="customer-configuration"
    local config_path="src/environments.js"
    local config_dir="$(find ${GITHOME} -type d -name ${config_repo} -print -quit)"
    declare -a js
    #git-latest-main "${config_dir}"
    cat "${config_dir}/${config_path}" | \
    while read line; do
        if [ -n "$(echo ${line} | grep -F '=')" ]; then continue;fi
        if [ -n "$(echo ${line} | grep -F '//')" ]; then continue;fi
        if [ -n "$(echo ${line} | grep -F ';')" ]; then echo -e "${js[@]}"; return;fi
        js+=("${line}\n")
    done
	echo "${js[@]}"
}

# Build Bash Arrays of RDS and Registries
# mad-parse-environments
mad-parse-environments () {
	local id=""
	local env=""
	local db="false"
	local registry="false"
	declare -i nest=0
	local details=""
	while read lines; do
		if [ "${db}" == "true" ]; then
			if [ -n "${db_name}" ] && [ -n "${db_address}" ]; then
				RDS[${db_name:0:-1}]="${db_address}"
				echo "RDS[${db_name:0:-1}]=${RDS[${db_name:0:-1}]}"
				db_name=""
				db_address=""
			fi
			if [ -z "${db_name}" ] && [ -z "${db_address}" ]; then
				db_name="$(echo $lines | grep ':' | awk '{print $1}')"
				db_address="$(echo $lines | grep ',' | awk -F'"' '{print $2}' )"
			elif [ -z "${db_name}" ]; then
				db_name="$(echo $lines | grep ':' | awk '{print $1}')"
				continue
			else
				db_address="$(echo $lines | grep ',' | awk -F'"' '{print $2}')"
				continue
			fi
		fi
		if [ -n "$(echo $lines | grep '^registries: ' )" ]; then 
			registry="true"			
		fi
		if [ "${registry}" == "true" ]; then
			registry_address="$(echo $lines | grep ',' | awk -F'"' '{print $2}')"
			if [ -n "${registry_address}" ] && [ -n "${REGISTRIES[${id}]}" ]; then
				REGISTRIES[${id}]="${REGISTRIES[${id}]},${registry_address}"
				echo "REGISTRIES[${id}]=${REGISTRIES[${id}]}"
			elif [ -n "${registry_address}" ]; then 
				REGISTRIES[${id}]="${registry_address}"
				echo "REGISTRIES[${id}]=${REGISTRIES[${id}]}"
			fi
				registry_address=""
		fi
		if [ -n "$(echo $lines | grep '^databases: ' )" ]; then 	
			db="true"
			continue
		fi	
		if [ -n "$(echo $lines | grep '^id: ' )" ]; then 
			id="$(echo $lines | awk -F'"' '{print $2}' )"	
			continue
		fi		
		
		if [ -n "$(echo $lines | grep '{' )" ] || [ -n "$(echo $lines | grep '\[' )" ]; then 
			((nest++))
			continue		
		fi
		if [ -n "$(echo $lines | grep '}' )" ] || [ -n "$(echo $lines | grep ']' )" ]; then 
			((nest--))
			db="false"
			registry="false"
			db_name=""
			db_address=""
			continue 
		fi
	done <<< "$( mad-environments-js )"
}

# Print Mandiant Array Values
# mad-dump-arrays
mad-dump-arrays () {
	declare -a ARRAYS=("RDS" "REGISTRIES" "VAULTS" "TOKENS" "APIKEYS" "ELASTIC" "KIBANA" "KUBE")
	for ARR in ${ARRAYS[@]}; do
		declare -n NAME=$ARR
		for index in "${!NAME[@]}"; do
			echo "$ARR[$index]=${NAME[$index]}"
		done
		echo ""
	done
}

# Apply shell configurations by environment
# mad-assume <environment> [-force]
mad-assume () { 
	local name="${1}"
	local force="${2}"
	export MAD_PROFILE="${name}"
	case "${name}" in
		grunt|prod)
			ssh-load-keys mandiant git
			aws-apply-profile respond-prod ${force}
			kube-profile prod
			vault_profile primary
			;;
		usw2)
			ssh-load-keys mandiant git
			aws-apply-profile respond-prod ${force}
			kube-profile ${name}
			vault_profile primary
			;;
		apse1|apse2|euw1)
			ssh-load-keys mandiant git
			aws-apply-profile respond-prod ${force}
			kube-profile ${name}
			vault_profile ${name}
			;;
		mordin|dev)
			ssh-load-keys mandiant git
			aws-apply-profile respond-dev ${force}
			kube-profile dev
			vault_profile primary
			;;
		legion|corp)
			ssh-load-keys mandiant git
			aws-apply-profile respond ${force}
			kube-profile corp
			vault_profile primary
			;;
		gov)
			ssh-load-keys mandiant git
			aws-apply-profile respond-${name} ${force}
			kube-profile ${name}
			vault_profile ${name}
			;;
		ops)
			ssh-load-keys mandiant git
			aws-apply-profile respond-${name} ${force}
			kube-profile ${name}
			vault_profile primary
			;;
		sso)
			ssh-load-keys mandiant git
			aws-apply-profile respond-${name} ${force}
			kube-profile prod
			vault_profile primary
			;;
		sec)
			ssh-load-keys mandiant git
			aws-apply-profile respond-${name} ${force}
			;;
		*)
			aws-apply-profile ${name} ${force}
			;;
   	esac
}

# Port forward rabbit-mq and display connection details
# kube-rabbit [namespace] [service]
kube-rabbit () {
    local namespace=${1:-shared}
    local service=${2:-rabbitmq}
    vault_profile primary
    vault read prod/respond/secret/provisioner/rabbitmq
    kube-forward-rabbit ${namespace} ${service}
}

# No DNS resolution over VPN, add to hosts file
# mad-inject-hosts
mad-inject-hosts () {
	sudo echo "10.17.148.166   es.dev.mad-ops.net" >> /etc/hosts
}

# Run docker build tags for all sidecar containers in sub-directories
# mad-docker-build-sidecars <tag> [old_tag] [root folder]
mad-docker-build-sidecars () {
	local new_tag=${1}
	local old_tag=${2}
	local folder=${3:-"${GITHOME}/mandiant/main"}
	local profile="${MAD_PROFILE:-corp}"
	pushd "${folder}" > /dev/null
	for file in $(find . -type f | grep Dockerfile | grep sidecar); do 
		pushd ${file%/*} > /dev/null
		local service=$(echo "${file%/*}"|rev|cut -d '/' -f 2|rev)
		if [ "${service}" = "incident-mu-service" ]; then service=incidents;fi;
		if [ "${service}" = "ui-server" ]; then service=analyst;fi; 
		if [ "${service}" = "big-monolithic-app" ]; then service=big-monolith;fi;   
		docker build -t 785540879854.dkr.ecr.us-west-2.amazonaws.com/respond-init-${service}:${new_tag} . & 
		popd  > /dev/null
	done
	popd  > /dev/null
	jobs_pause
	if [ -n "${old_tag}" ]; then
		docker rmi $(docker images | grep ${old_tag} | awk '{print $1":"$2}')
		docker rmi $(docker images | grep none | awk '{print $3}')
	fi
	mad-assume corp
	aws-ecr-login
	for image in $(docker images | grep 785540879854 | awk '{print $1":"$2}'); do 
		docker push ${image} & 
	done
	if [ "${profile}" != "corp" ]; then
		mad-assume ${profile}
	fi
	jobs_pause
}

# Change sidecar FROM to specific image
# mad-dockerfile-local [image:tag] [parent_path_of_dockerfiles]
mad-dockerfile-local () {
	local from=${1:-"785540879854.dkr.ecr.us-west-2.amazonaws.com/respond-init:stanton"}
	local folder=${2:-"$(pwd)"}
	pushd ${folder} > /dev/null
	for file in $(find . -type f | grep Dockerfile | grep sidecar); do 
		echo "updating $file"
		echo "FROM ${from}" > "${file}2"
		cat ${file} | tail -n +2 >> "${file}2"
		mv -f "${file}2" "${file}"
	done
	popd > /dev/null
}

# Insert line 2 into non-sidecar dockerfiles
# mad-dockerfile-component [line_2] [parent_path_of_dockerfiles]
mad-dockerfile-component () {
	local insert=${1:-"USER respond"}
	local folder=${2:-"$(pwd)"}
	pushd ${folder} > /dev/null
	for file in $(find . -type f | grep Dockerfile | grep -v sidecar); do 
		echo "updating $file"
		cat ${file} | head -n 1 > "${file}2"
		echo "${insert}" >> "${file}2"
		cat ${file} | tail -n +2 >> "${file}2"
		mv -f "${file}2" "${file}"
	done
	popd > /dev/null
}

# If you source this file directly, apply the overwrites.
if [ -z "$(echo "$(script_origin)" | grep -F "shrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi
