
sh_source
_this="$( script_source )"
_sources+=("$(basename ${_this})")

UTILITIES+=("echo" "awk" "grep" "cat" "curl" "base64" "tr" "printf" "wc" "sort" "kubectl" "pkill" "sleep")
abbr='es'
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

# Curl Elasticsearch with API key
# es-curl [url] [ApiKey]
es-curl () {
  local cURL="${1}"
  local cAPI="${2}"
  if [ -z ${cURL} ]; then echo "need URL"; return 1;fi
  local H1="'Content-Type: application/json'"
  local H2="Authorization: ApiKey ${cAPI}"
  #echo "curl -sk ${cURL} -H ${H1} -H \"${H2}\""
  cmd "curl -sk ${cURL} -H ${H1} -H \"${H2}\""
  return ${LAST_STATUS}
}


# Curl Kibana with API key
# es-kb-get [cluster] [api endpoint]
es-kb-get () {
  local cluster="${1}"
  local endpoint="${2}"
  local eKEY=$(echo -n "${APIKEYS[${cluster}]}" | base64 | tr -d \\r)
  local eURL="${KIBANA[${cluster}]}${endpoint}"
  es-curl ${eURL} ${eKEY}
}

# Curl Elasticsearch with API key
# es-get [cluster] [api endpoint]
es-get () {
  local cluster="${1}"
  local endpoint="${2}"
  local eKEY=$(echo -n "${APIKEYS[${cluster}]}" | base64 | tr -d \\r)
  local eURL="${ELASTIC[${cluster}]}${endpoint}"
  es-curl "${eURL}" "${eKEY}"
}

# Curl PUT Elasticsearch with API key
# es-put [cluster] [api endpoint] [data]
es-put () {
  local cluster="${1}"
  local endpoint="${2}"
  local eDATA="${3}"
  local eKEY=$(echo -n "${APIKEYS[${cluster}]}" | base64 | tr -d \\r)
  local eURL="${ELASTIC[${cluster}]}${endpoint}"
  local H1="Content-Type: application/json"
  local H2="Authorization: ApiKey ${eKEY}"
  curl -sk -XPUT ${eURL} -H "${H1}" -H "${H2}" -d "${eDATA}"
}

# Curl POST Elasticsearch with API key
# es-post [cluster] [api endpoint] [data]
es-post () {
  local cluster="${1}"
  local endpoint="${2}"
  local eDATA="${3}"
  local eKEY=$(echo -n "${APIKEYS[${cluster}]}" | base64 | tr -d \\r)
  local eURL="${ELASTIC[${cluster}]}${endpoint}"
  local H1="Content-Type: application/json"
  local H2="Authorization: ApiKey ${eKEY}"
  curl -sk -XPOST ${eURL} -H "${H1}" -H "${H2}" -d "${eDATA}"
}

# Curl PUT Elasticsearch with User and Password
# es-put-user [cluster] [api endpoint] [data] [user:pass]
es-put-user () {
  local cluster="${1}"
  local endpoint="${2}"
  local eDATA="${3}"
  local AUTH="${4}"
  local eURL="${ELASTIC[${cluster}]}${endpoint}"
  local H1="Content-Type: application/json"
  curl -u "${AUTH}" -k -XPUT ${eURL} -H "${H1}" -d "${eDATA}"
}

# Curl POST Elasticsearch with User and Password
# es-post-user [cluster] [api endpoint] [data] [user:pass]
es-post-user () {
  local cluster="${1}"
  local endpoint="${2}"
  local eDATA="${3}"
  local auth="${4}"
  local eURL="${ELASTIC[${cluster}]}${endpoint}"
  local H1="Content-Type: application/json"
  echo "curl -u \"${auth}\" -k -XPOST ${eURL} -H \"${H1}\" -d \"${eDATA}\""
  curl -u "${auth}" -k -XPOST ${eURL} -H "${H1}" -d "${eDATA}"
}

# Curl POST Elasticsearch with User and Password
# es-create-apikey <cluster> <user:pass> [key_name]
es-create-apikey () {
  local cluster="${1}"
  local auth="${2}"
  local name="${3:-curl}"
  local eURL="${ELASTIC[${cluster}]}"
  es-post-user "${cluster}"  '/_security/api_key' "{ \"name\":\"${name}\" }" "${auth}"
}

# Curl POST Elasticsearch with User and Password
# es-create-apikey-restricted <cluster> <user:pass> <json_policy> 
es-create-apikey-restricted () {
  local cluster="${1}"
  local auth="${2}"
  local policy="${3}"
  local eURL="${ELASTIC[${cluster}]}"
  es-post-user "${cluster}"  '/_security/api_key' "${policy}" "${auth}"
}



# Report list of clusters
es-list-clusters () {
  if [ -z "${ELASTIC[*]}" ]; then 
    echo "No clusters loaded. Create array of clusters with:\n \
    declare -A ELASTIC\n    ELASITC[<CLUSTER_NAME>]=<URL>"
    return
  fi
  local fmt='%-10s%s\n'
  for cluster in "${!ELASTIC[@]}"; do
    printf "${fmt}" "${cluster}" "${ELASTIC[${cluster}]}"
  done
}

# List users on cluster
# es-list-users <cluster> 
es-list-users () {
  local cluster="${1}"
  local reserved="${2:-false}"
  if [ -z ${cluster} ]; then echo "Cluster Nickname Required."; return; fi
  if [ ${reserved} != "false" ]; then 
    es-get ${cluster} /_security/user | jq -r 'keys[]'
  else
    es-get ${cluster} /_security/user | jq -r 'select(.metadata._reserved != true) | keys[]'
  fi
}

# Report Cluster shard or node status
# es-report-users <cluster> 
es-report-users () {
  local cluster="${1}"
  if [ -z ${cluster} ]; then echo "Cluster Nickname Required."; return; fi
  local users_json=($(es-get ${cluster} /_security/user | jq -r '.[] | @base64'))
  local fmt="%-8s%-9s%-30s%-30s%-30s%s\n"
  printf "${fmt}" "Enabled" "Reserved"  "Name" "Full Name" "Email" "Roles"
  for user in "${users_json[@]}"; do
    username="$(echo ${user} | base64 --decode | jq -r '.username')"
    fullname="$(echo ${user} | base64 --decode | jq -r '.full_name')"
    email="$(echo ${user} | base64 --decode | jq -r '.email')"
    roles="$(echo ${user} | base64 --decode | jq -r '.roles[]')"
    enabled="$(echo ${user} | base64 --decode | jq -r '.enabled')"
    reserved="$(echo ${user} | base64 --decode | jq -r '.metadata._reserved')"
    for var in "fullname" "email" "roles" "reserved"; do
      if [ "$(eval "echo \$${var}")" = "null" ]; then eval "${var}='-'"; fi
    done
    printf "${fmt}" "${enabled}" "${reserved}" "${username}" "${fullname}" "${email}" "$(echo ${roles} | sed 's/ /,/g')" 
  done
}

# Report Cluster shard or node status
# es-cluster-report [cluster] [shards|shardstats|nodes]
es-cluster-report () {
  local cluster="${1}"
  local query="${2}"
  if [[ ${query} == "shards" ]]; then
    echo "$(es-get ${cluster} /_cat/shards)"
  fi
  if [[ ${query} == "shardstats" ]]; then
    local shards=$(es-get ${cluster} /_cat/shards) 
    local fmt="%-15s %5s %9s %9s\n"
    printf "${fmt}" "Action" "Total" "Primaries" "Replicas" 
    for i in "UNASSIGNED" "RELOCATING" "INITIALIZING"; do
      printf "${fmt}" "${i}" $(echo "${shards}" | grep ${i} | wc -l) $(echo "${shards}" | grep ${i}  | grep ' p '| wc -l) $(echo "${shards}" | grep ${i} | grep ' r ' | wc -l)
    done
    printf "${fmt}" "Total" $(echo "${shards}" | grep -v STARTED | wc -l) $(echo "${shards}" | grep -v STARTED | grep ' p '| wc -l) $(echo "${shards}" | grep -v STARTED | grep ' r '| wc -l)
  
  fi
  if [[ ${query} == "nodes" ]]; then
    echo "$(es-get ${cluster} /_cat/nodes\?v=true\&h=name,cpu,heapPercent,ramPercent,ramCurrent,diskTotal,diskAvail)" | (read -r; printf "%s\n" "$REPLY"; sort)
  fi
}

# Report master ES instance recognized by each node
# es-query-master [nodes[@]]
es-query-master () {  
  local eKEY=$(echo -n "${API_LEGION}" | base64 | tr -d \\r)
  local nodes=${1}
  if [ ! -z "${nodes}" ]; then
    for n in ${nodes}; do
      kubectl -n shared port-forward pod/$n 9200:9200 > /dev/null 2>&1 &
      sleep 1
      echo "node: ${n}"
      es-curl https://localhost:9200/_cat/master $eKEY
      pkill kubectl  > /dev/null 2>&1
      sleep 1
    done
  else 
    echo "nodes: $nodes"
  fi
}

# Get a list of index templates that match a pattern
# es-get-templates-names < CLUSTER_NAME > [index*]
es-get-template-names () {
  local cluster="${1}"
  local pattern="${2}"
  es-get "${cluster}" "/_cat/templates/${pattern}" | awk '{print $1}'  
}

# Get a current template json
# TEMPLATES=$(es-query-templates ${CLUSTER_NAME} cases*)
# es-get-template < CLUSTER_NAME > < template_name >
es-get-template () {
  local cluster="${1}"
  local template="${2}"
  es-get "${cluster}" "/_template/${template}"  
}

# Get a current templates lifecycle policy
# for name in ${TEMPLATES[@]}; do es-get-template-lifecycle ${CLUSTER_NAME} "${name}" >> /tmp/${CLUSTER_NAME}-template-policies & done
# es-get-template-lifecycle < CLUSTER_NAME > < template_name >
es-get-template-lifecycle () {
  local cluster="${1}"
  local template="${2}"
  local policy="$(es-get "${cluster}" "/_template/${template}" | jq -r '.[].settings.index.lifecycle.name' )"
  echo "${policy} ${template}"
}

# Update an existing index template with preferred data tier
# INDICES=$(cat /tmp/${CLUSTER_NAME}-template-policies | grep -v '^ ' | awk '{print $2}' | grep -v '^\.' | sort)
# for name in ${INDICES[@]}; do es-set-template-tier ${CLUSTER_NAME} "${name}" ; done
# es-set-template-tier  < CLUSTER_NAME > < template_name > [data_warm]
es-set-template-tier () {
  local cluster="${1}"
  local template="${2}"
  local tier="${3:-data_hot}"
  banner " ${template} "
  local json="$(es-get-template "${cluster}" "${template}" | jq '.[].settings.index.routing.allocation.include += { "_tier_preference" : "'${tier}'" } | .[]')"
  echo "${json}" > "/tmp/${cluster}-${template}.json"
  local response="$(es-put "${cluster}" "/_template/${template}" "@/tmp/${cluster}-${template}.json")"
  echo "${response}"
}

# List all role mappings on the cluster
# es-list-role-mappings <cluster_nickname>
es-list-role-mappings () {
  local cluster="${1}"
  if [ -z ${cluster} ]; then echo "Cluster Nickname Required."; return; fi
  es-get "${cluster}" '/_security/role_mapping' | jq -r 'keys[]'
}

# Get specific role mapping
# es-get-role-mapping <cluster_nickname> <role_name>
es-get-role-mapping () {
  local cluster="${1}"
  local mapping="${2}"
  if [ -z ${cluster} ]; then echo "Cluster Nickname Required."; return; fi
  if [ -z ${mapping} ]; then echo "Name of Role Mapping Required."; return; fi
  es-get ${cluster} "/_security/role_mapping/${mapping}"
}

# Get specific role mapping
# es-disable-role-mapping <cluster_nickname> <role_name>
es-disable-role-mapping () {
  local cluster="${1}"
  local mapping="${2}"
  if [ -z ${cluster} ]; then echo "Cluster Nickname Required."; return; fi
  if [ -z ${mapping} ]; then echo "Name of Role Mapping Required."; return; fi
  local role_json="$(es-get-role-mapping ${cluster} ${mapping} | jq -r '.[].enabled = false | .[]')"
  es-put ${cluster} "/_security/role_mapping/${mapping}" "${role_json}"
}

# Get specific user
# es-get-user <cluster_nickname> <user_name>
es-get-user () {
  local cluster="${1}"
  local username="${2}"
  if [ -z ${cluster} ]; then echo "Cluster Nickname Required."; return; fi
  if [ -z ${username} ]; then echo "Name of User Required."; return; fi
  es-get ${cluster} "/_security/user/${username}"
}

# Create New Elastic User
# roles must be a string including quotes and commas, eg. '"new","user","roles"'
# es-create-user <cluster_nickname> <user_name> <user_password> [roles] [email] [full_name]
es-create-user () {
  local cluster="${1}"
  local username="${2}"
  local password="${3}"
  local roles="${4}"
  local email="${5}"
  local fullname="${6:-${username}}"
  if [ -z ${cluster} ]; then echo "Cluster nickname required."; return; fi
  if [ -z ${username} ]; then echo "Name of user required."; return; fi
  if [ -z ${password} ]; then echo "Password required."; return; fi
  local user_json="$(es-get-user ${cluster} ${username} | jq '.[].username' )"
  if [ "${user_json:-null}" != "null" ]; then echo "User already exists"; return 1; fi
  user_json="$(es-get-user ${cluster} $(es-list-users ${cluster} | head -n 1) | jq 'del(.[].username) | .[]')"
  user_json="$(echo ${user_json} | jq ".full_name = \"${fullname}\"")"
  user_json="$(echo ${user_json} | jq ".email = \"${email}\"")"
  user_json="$(echo ${user_json} | jq ".password = \"${password}\"")"
  user_json="$(echo ${user_json} | jq ".roles = [ ${roles} ] ")"
  es-put ${cluster} "/_security/user/${username}" "${user_json}"
}

# If you source this file directly, apply the overwrites.
if [ -z "$(echo "$(script_origin)" | grep -F "shrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi