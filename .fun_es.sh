
sh_source
_this="$( script_source )"
_sources+=("$(basename ${_this})")

UTILITIES+=("echo" "awk" "grep" "cat" "curl" "base64" "tr" "printf" "wc" "sort" "kubectl" "pkill" "sleep")
abbr='es'

# Create help function for this file
common-help "${abbr}" "${_this}"

# Curl Elasticsearch with API key
# es-curl [url] [ApiKey]
es-curl() {
  local cURL="${1}"
  local cAPI="${2}"
  vpn-check-apikey "${cURL}" "${cAPI}"
}


# Curl Kibana with API key
# es-kb-get [cluster] [api endpoint]
es-kb-get() {
  local cluster="${1}"
  local endpoint="${2}"
  local eKEY=$(echo -n "${APIKEYS[${cluster}]}" | base64 | tr -d \\r)
  local eURL="${KIBANA[${cluster}]}${endpoint}"
  proxy-check ${cluster}
  es-curl ${eURL} ${eKEY}
  proxy-restore
}

# Curl Kibana with API key
# es-kb-post [cluster] [api endpoint] [data]
es-kb-post() {
  local cluster="${1}"
  local endpoint="${2}"
  local eDATA="${3}"
  local eKEY=$(echo -n "${APIKEYS[${cluster}]}" | base64 | tr -d \\r)
  local eURL="${KIBANA[${cluster}]}${endpoint}"
  local H1="Content-Type: application/json"
  local H2="Authorization: ApiKey ${eKEY}"
  local H3="kbn-xsrf: true"
  proxy-check ${cluster}
  curl -sk -XPOST ${eURL} -H "${H1}" -H "${H2}" -H "${H3}" -d"${eDATA}"
  proxy-restore
}

# Curl Elasticsearch with API key
# es-get [cluster] [api endpoint]
es-get() {
  local cluster="${1}"
  local endpoint="${2}"
  local eKEY=$(echo -n "${APIKEYS[${cluster}]}" | base64 | tr -d \\r)
  local eURL="${ELASTIC[${cluster}]}${endpoint}"
  proxy-check ${cluster}
  es-curl "${eURL}" "${eKEY}"
  proxy-restore
}

# Curl PUT Elasticsearch with API key
# es-put [cluster] [api endpoint] [data]
es-put() {
  local cluster="${1}"
  local endpoint="${2}"
  local eDATA="${3}"
  local eKEY=$(echo -n "${APIKEYS[${cluster}]}" | base64 | tr -d \\r)
  local eURL="${ELASTIC[${cluster}]}${endpoint}"
  local H1="Content-Type: application/json"
  local H2="Authorization: ApiKey ${eKEY}"
  proxy-check ${cluster}
  curl -sk -XPUT ${eURL} -H "${H1}" -H "${H2}" -d "${eDATA}"
  proxy-restore
}

# Curl DELETE Elasticsearch with API key
# es-delete [cluster] [api endpoint]
es-delete() {
  local cluster="${1}"
  local endpoint="${2}"
  local eKEY=$(echo -n "${APIKEYS[${cluster}]}" | base64 | tr -d \\r)
  local eURL="${ELASTIC[${cluster}]}${endpoint}"
  local H1="Content-Type: application/json"
  local H2="Authorization: ApiKey ${eKEY}"
  proxy-check ${cluster}
  curl -sk -XDELETE ${eURL} -H "${H1}" -H "${H2}"
  proxy-restore
}

# Curl POST Elasticsearch with API key
# es-post [cluster] [api endpoint] [data]
es-post() {
  local cluster="${1}"
  local endpoint="${2}"
  local eDATA="${3}"
  local eKEY=$(echo -n "${APIKEYS[${cluster}]}" | base64 | tr -d \\r)
  local eURL="${ELASTIC[${cluster}]}${endpoint}"
  local H1="Content-Type: application/json"
  local H2="Authorization: ApiKey ${eKEY}"
  proxy-check ${cluster}
  curl -sk -XPOST ${eURL} -H "${H1}" -H "${H2}" -d "${eDATA}"
  proxy-restore
}

# Curl PUT Elasticsearch with User and Password
# es-put-user [cluster] [api endpoint] [data] [user:pass]
es-put-user() {
  local cluster="${1}"
  local endpoint="${2}"
  local eDATA="${3}"
  local AUTH="${4}"
  local eURL="${ELASTIC[${cluster}]}${endpoint}"
  local H1="Content-Type: application/json"
  proxy-check ${cluster}
  curl -u "${AUTH}" -k -XPUT ${eURL} -H "${H1}" -d "${eDATA}"
  proxy-restore
}

# Curl POST Elasticsearch with User and Password
# es-post-user [cluster] [api endpoint] [data] [user:pass]
es-post-user() {
  local cluster="${1}"
  local endpoint="${2}"
  local eDATA="${3}"
  local auth="${4}"
  local eURL="${ELASTIC[${cluster}]}${endpoint}"
  local H1="Content-Type: application/json"
  #echo "curl -u \"${auth}\" -k -XPOST ${eURL} -H \"${H1}\" -d \"${eDATA}\""
  proxy-check ${cluster}
  curl -u "${auth}" -sk -XPOST ${eURL} -H "${H1}" -d "${eDATA}"
  proxy-restore
}

# Curl POST Elasticsearch with User and Password
# es-create-apikey <cluster> <user:pass> [key_name]
es-create-apikey() {
  local cluster="${1}"
  local auth="${2}"
  local name="${3:-curl}"
  local eURL="${ELASTIC[${cluster}]}"
  es-post-user "${cluster}"  '/_security/api_key' "{ \"name\":\"${name}\" }" "${auth}"
}

# Curl POST Elasticsearch with User and Password
# es-create-apikey-restricted <cluster> <user:pass> <json_policy>
es-create-apikey-restricted() {
  local cluster="${1}"
  local auth="${2}"
  local policy="${3}"
  local eURL="${ELASTIC[${cluster}]}"
  es-post-user "${cluster}"  '/_security/api_key' "${policy}" "${auth}"
}

# Report list of clusters
es-list-clusters() {
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
es-list-users() {
  local cluster="${1}"
  local reserved="${2:-false}"
  if [ -z ${cluster} ]; then echo "Cluster Nickname Required."; return; fi
  if [ ${reserved} != "false" ]; then
    es-get ${cluster} /_security/user | jq -r 'keys[]'
  else
    es-get ${cluster} /_security/user | jq -r 'select(.metadata._reserved != true) | keys[]'
  fi
}

# List aliases on cluster, similar to list indices
# es-list-aliases <cluster>
es-list-aliases() {
  local cluster="${1}"
  if [ -z ${cluster} ]; then echo "Cluster Nickname Required."; return; fi
  local indices=$(es-get ${cluster} /_cat/aliases?h=alias | sort -u )
  printf "%s\n" ${indices[@]}
}

# List all indices on cluster
# es-list-indices <cluster>
es-list-indices() {
  local cluster="${1}"
  if [ -z ${cluster} ]; then echo "Cluster Nickname Required."; return; fi
  local indices=$(es-get ${cluster} /_cat/indices?h=index | sort -u )
  printf "%s\n" ${indices[@]}
}


# Get index creation date
# es-get-index-creation <cluster> <index>
es-get-index-creation() {
  local cluster="${1}"
  local index="${2}"
  if [ -z ${cluster} ] || [ -z ${index} ] ; then echo "Cluster Nickname Required."; return; fi
  local creation_date=$(es-get "${cluster}" "/${index}" | jq -r '.[].settings.index.creation_date')
  printf "%s\n" $((${creation_date}))
}

# Get index rollover alias
# es-get-index-alias <cluster> <index>
es-get-index-alias() {
  local cluster="${1}"
  local index="${2}"
  if [ -z ${cluster} ] || [ -z ${index} ] ; then echo "Cluster Nickname Required."; return; fi
  local alias=$(es-get "${cluster}" "/${index}" | jq -r '.[].settings.index.lifecycle.rollover_alias')
  printf "%s\n" ${alias}
}

# Get index size in kilobytes
# es-get-index-size <cluster> <index>
es-get-index-size() {
  local cluster="${1}"
  local index="${2}"
  if [ -z ${cluster} ] || [ -z ${index} ] ; then echo "Cluster Nickname and Index Name Required."; return; fi
  local bytes=$(es-get "${cluster}" "/${index}/_stats" | jq -r '._all.primaries.store.size_in_bytes')
  printf "%s\n" $((${bytes}/1024))
}

# Get index size in kilobytes
# es-get-task <cluster> <task_id>
es-get-task() {
  local cluster="${1}"
  local task_id="${2}"
  if [ -z ${cluster} ]; then echo "Cluster Nickname Required."; return; fi
  local status=$(es-get ${cluster} /_tasks/${task_id} )
  echo "${status}"
}

es-delete-retry() {
  local cluster="${1}"
  local index="${2}"
  if [ -z ${cluster} ]; then echo "Cluster Nickname Required."; return; fi
  while [[ -n "$(es-delete "${cluster}" "/${index}" | jq -r '.error[]' 2> /dev/null )" ]]; do
    echo "Error while deleting ${index}"
    sleep 10
  done
}

es-set-ilm-date() {
  local cluster="${1}"
  local index="${2}"
  local date="${3}"
  local json='{
    "settings": {
        "index": {
          "lifecycle.origination_date": '${date}'
        }
    }}'
  if [ -z ${cluster} ]; then echo "Cluster Nickname Required."; return; fi
  es-put "${cluster}" "/${index}/_settings" "${json}"
}

es-set-ilm-alias() {
  local cluster="${1}"
  local index="${2}"
  local alias="${3}"
  local json='{
    "actions": [
    {
      "add": {
        "index": "'${index}'",
        "alias": "'${alias}'"
      }
    }
  ]}'
  if [ -z ${cluster} ]; then echo "Cluster Nickname Required."; return; fi
  es-post "${cluster}" "/_aliases" "${json}"
}

# Reindex and drop documents that match $INDEX_FILTER
# Use this function to reduce an index size buy deleteing documents
# es-reduce-index <cluster> <[index_array]> [new_index_name] [$INDEX_FILTER]
es-reduce-index() {
  local cluster="${1}"
  local indicies=(${2})
  local index_name="${3:-${indicies[0]}-reindex}"
  local index_json="${4:-$(echo ${INDEX_FILTER} | jq)}"
  local index_created=$(es-get-index-creation ${cluster} ${indicies[0]})
  local index_alias=$(es-get-index-alias ${cluster} ${indicies[0]})
  local index task
  local waiting="true"
  local json='{
    "conflicts": "proceed",
    "source": {
        "index": [ ]
    },
    "dest": {
        "index": "name",
        "op_type": "create"
    }}'
  if [ -z ${cluster} ] || [ -z ${indicies} ] ; then echo "Cluster Nickname and Index Pattern Required."; return; fi
  echo "index_name: ${index_name}"
  json=$(echo ${json} | jq '.dest.index = "'${index_name}'"')
  for index in ${indicies[@]}; do
    echo "index: ${index}"
    json=$(echo ${json} | jq '.source.index += ["'${index}'"]')
  done
    echo "json: ${json}"
  if [[ -n "${index_json}" ]]; then
    json=$(echo "${json}" "${index_json}" | jq -s '.[0] * .[1]')
  fi
  echo "es-post \"${cluster}\" /_reindex?wait_for_completion=false \"${json}\""
  local task=$(es-post "${cluster}" '/_reindex?wait_for_completion=false' "${json}" | jq -r '.task')
  echo "task: ${task}"
  echo -n "Waiting."
  while [[ "${waiting}" == "true" ]]; do
    reindexing=$(es-get "${cluster}" "/_tasks?actions=*reindex" | jq -r '.nodes[]')
    result=$(es-get "${cluster}" "/_tasks/${task}" | jq -r '.completed')
    if [[ "${result}" == "true" ]] || [[ -z "${reindexing}" ]]; then
      waiting="false"
    fi
    sleep 30
    echo -n "."
  done
  echo ""
  es-set-ilm-alias "${cluster}" "${index_name}" "${index_alias}"
  es-set-ilm-date "${cluster}" "${index_name}" ${index_created}
  if [[ -z "$(echo $result | jq '.failures[]' )" ]]; then
    for index in ${indicies[@]}; do
      es-delete-retry ${cluster} ${index}
    done
  else
    echo "Error!"
    echo ${result} | jq '.failures[]'
  fi
}

# Reindex indicies and drop documents that match filter
# Use this function to reduce multiple indicies sizes by deleting documents
# es-reduce-indicies <cluster> <index_pattern> [minimum age days] [$INDEX_FILTER]
es-reduce-indicies() {
  local cluster="${1}"
  local index_pattern="${2}"
  local today=$(date +%s)
  local min_age=$((${3:-7}*24*60*60))
  local index_json="${4:-$(echo ${INDEX_FILTER} | jq)}"
  local index_created index_age index_size  index
  local index_group=()
  if [ -z ${cluster} ] || [ -z ${index_pattern} ] ; then echo "Cluster Nickname and Index Pattern Required."; return; fi
  local index_list=$(es-list-indices ${cluster} | grep "${index_pattern}" | grep -v reindex )
  for index in ${index_list}; do
    index_created=$(es-get-index-creation ${cluster} ${index})
    index_age=$((today-(index_created/1000)))
    echo -n "index: ${index}, today: ${today}, min_age: ${min_age}, created: ${index_created}; age: ${index_age}"
    if [ ${index_age} -lt ${min_age} ] ; then echo "";continue; fi
    echo -n ", $((index_age/(24*60*60))) days old"
    index_size=$(es-get-index-size "${cluster}" "${index}")

    echo ", size: ${index_size}, Creating New Index: "
    es-reduce-index "${cluster}" "${index}" &
    while (( (( $(jobs -p | wc -l) )) >= 12 ));do
      echo -n "."
      sleep 120
    done
    sleep 5
    echo ""
  done
}


# Reindex multiple indicies into 1 index
# es-merge-indicies <cluster> <[index_array]> [new_index_name] [index_pattern_filter]
es-merge-indicies() {
  local cluster="${1}"
  local indicies=(${2})
  local index_name="${3:-${indicies[0]}-reindexed}"
  local index_filter=${4:-$INDEX_FILTER}
  local index_alias=$(es-get-index-alias ${cluster} ${indicies[0]})
  local index task index_created result reindexing
  local waiting="true"
  local json='{
    "conflicts": "proceed",
    "source": {
        "index": [ ]
    },
    "dest": {
        "index": "name",
        "op_type": "create"
    }}'
  if [ -z ${cluster} ] || [ -z ${index_pattern} ] ; then echo "Cluster Nickname and Index Pattern Required."; return; fi
  json=$(echo ${json} | jq '.dest.index = "'${index_name}'"')
  for index in ${indicies[@]}; do
    json=$(echo ${json} | jq '.source.index += ["'${index}'"]')
    index_created=$(es-get-index-creation ${cluster} ${index})
  done
  if [[ -n "${index_filter}" ]]; then
    json=$(echo ${json} | jq '.source.query = "${index_filter}"')
  fi
  echo "es-post \"${cluster}\" /_reindex?wait_for_completion=false \"${json}\""
  local task=$(es-post "${cluster}" '/_reindex?wait_for_completion=false' "${json}" | jq -r '.task')
  echo "task: ${task}"
  echo -n "Waiting."
  while [[ "${waiting}" == "true" ]]; do
    reindexing=$(es-get "${cluster}" "/_tasks?actions=*reindex" | jq -r '.nodes[]')
    result=$(es-get "${cluster}" "/_tasks/${task}" | jq -r '.completed')
    if [[ "${result}" == "true" ]] || [[ -z "${reindexing}" ]]; then
      waiting="false"
    fi
    sleep 30
    echo -n "."
  done
  echo ""
  es-set-ilm-alias "${cluster}" "${index_name}" "${index_alias}"
  es-set-ilm-date "${cluster}" "${index_name}" ${index_created}
  if [[ -z "$(echo $result | jq '.failures[]' )" ]]; then
    for index in ${indicies[@]}; do
      es-delete-retry ${cluster} ${index}
    done
  else
    echo "Error!"
    echo ${result} | jq '.failures[]'
  fi
}

# Compact indicies to reduce shard counts
# es-compact-index <cluster> <index> [size kb limit] [minimum age days]
es-compact-index() {
  local cluster="${1}"
  local index_pattern="${2}"
  local max_size="${3:-$((50*1024*1024))}"
  #local max_size="${3:-40000}"
  local min_age=$((${4:-90}*24*60*60))
  local today=$(date +%s)
  local index_created index_age index_size reindex_size index
  local index_group=()
  if [ -z ${cluster} ] || [ -z ${index_pattern} ] ; then echo "Cluster Nickname and Index Pattern Required."; return; fi
  local index_list=$(es-list-indices ${cluster} | grep "${index_pattern}" | grep -v reindex)
  for index in ${index_list}; do
    index_created=$(es-get-index-creation ${cluster} ${index})
    index_age=$((today-(index_created/1000)))
    echo -n "index: ${index}, today: ${today}, min_age: ${min_age}, created: ${index_created}; age: ${index_age}"
    if [ ${index_age} -lt ${min_age} ] ; then echo "";continue; fi
    echo -n ", $((index_age/(24*60*60))) days old"
    index_size=$(es-get-index-size "${cluster}" "${index}")

    if [ ${index_size} -gt ${max_size} ]; then
      echo ", OVERSIZED"
      reindex_size=0
      index_group=()
      continue
    fi

    if [ $((index_size+reindex_size)) -gt ${max_size} ]; then
      if [ ${#index_group[@]} -gt 1 ]; then
        echo ", size: ${index_size}, Creating New Index: , size:${reindex_size}"
        es-merge-indicies "${cluster}" "${index_group[*]}"
      else
        echo ", size: ${index_size}, Skip previous index"
      fi
      reindex_size=${index_size}
      index_group=("${index}")
      continue
    fi
    reindex_size=$((reindex_size+index_size))
    echo ", size: ${index_size}, reindex size: ${reindex_size}"
    index_group+=("${index}")
  done
  if [ ${#index_group[@]} -gt 0 ]; then
    echo "Creating New Index: size:${reindex_size}"
    es-merge-indicies "${cluster}" "${index_group[*]}"
  fi
}

# Report user account details
# es-report-users <cluster>
es-report-users() {
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
es-cluster-report() {
  local cluster="${1}"
  local query="${2}"
  if [ "${query}" == "shards" ]; then
    echo "$(es-get ${cluster} /_cat/shards)"
  fi
  if [ "${query}" == "shardstats" ]; then
    local shards=$(es-get ${cluster} /_cat/shards)
    local fmt="%-15s %5s %9s %9s\n"
    printf "${fmt}" "Action" "Total" "Primaries" "Replicas"
    for i in "UNASSIGNED" "RELOCATING" "INITIALIZING"; do
      printf "${fmt}" "${i}" $(echo "${shards}" | grep ${i} | wc -l) $(echo "${shards}" | grep ${i}  | grep ' p '| wc -l) $(echo "${shards}" | grep ${i} | grep ' r ' | wc -l)
    done
    printf "${fmt}" "Total" $(echo "${shards}" | grep -v STARTED | wc -l) $(echo "${shards}" | grep -v STARTED | grep ' p '| wc -l) $(echo "${shards}" | grep -v STARTED | grep ' r '| wc -l)

  fi
  if [ "${query}" == "nodes" ]; then
    echo "$(es-get ${cluster} '/_cat/nodes\?v=true\&h=name,cpu,heapPercent,ramPercent,ramCurrent,diskTotal,diskAvail')" | (read -r; printf "%s\n" "$REPLY"; sort)
  fi
}

# Report master ES instance recognized by each node
# es-query-master [nodes[@]]
es-query-master() {
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
es-get-template-names() {
  local cluster="${1}"
  local pattern="${2}"
  es-get "${cluster}" "/_cat/templates/${pattern}" | awk '{print $1}' | sort -u
}

# Get a list of index templates that match a pattern
# es-get-index-templates-names < CLUSTER_NAME >
es-get-index-template-names() {
  local cluster="${1}"
  es-get "${cluster}" "/_index_template" | jq -r '.index_templates[].name' | sort -u
}

# Get a list of index templates that match a pattern
# es-get-component-templates-names < CLUSTER_NAME >
es-get-component-template-names() {
  local cluster="${1}"
  es-get "${cluster}" "/_component_template" | jq -r '.component_templates[].name' | sort -u
}

# Get a current template json
# TEMPLATES=$(es-get-template-names ${CLUSTER_NAME} cases*)
# es-get-template < CLUSTER_NAME > < template_name >
es-get-template() {
  local cluster="${1}"
  local template="${2}"
  es-get "${cluster}" "/_template/${template}"
}

# Get a current template json
# TEMPLATES=$(es-get-index-template-names ${CLUSTER_NAME} | grep cases )
# es-get-index-template < CLUSTER_NAME > < template_name >
es-get-index-template() {
  local cluster="${1}"
  local template="${2}"
  es-get "${cluster}" "/_index_template/${template}" | jq -r '.index_templates[].index_template'
}

# Get a current template json
# TEMPLATES=$(es-get-component-template-names ${CLUSTER_NAME} | grep cases )
# es-get-component-template < CLUSTER_NAME > < template_name >
es-get-component-template() {
  local cluster="${1}"
  local template="${2}"
  es-get "${cluster}" "/_component_template/${template}" | jq -r '.component_templates[].component_template'
}

# Get a current templates lifecycle policy
# for name in ${TEMPLATES[@]}; do es-get-template-lifecycle ${CLUSTER_NAME} "${name}" >> /tmp/${CLUSTER_NAME}-template-policies & done
# es-get-template-lifecycle < CLUSTER_NAME > < template_name >
es-get-template-lifecycle() {
  local cluster="${1}"
  local template="${2}"
  local policy="$(es-get "${cluster}" "/_template/${template}" | jq -r '.[].settings.index.lifecycle.name' )"
  echo "${policy} ${template}"
}

# Update an existing index template with preferred data tier
# INDICES=$(cat /tmp/${CLUSTER_NAME}-template-policies | grep -v '^ ' | awk '{print $2}' | grep -v '^\.' | sort)
# for name in ${INDICES[@]}; do es-set-template-tier ${CLUSTER_NAME} "${name}" ; done
# es-set-template-tier  < CLUSTER_NAME > < template_name > [data_warm]
es-set-template-tier() {
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
es-list-role-mappings() {
  local cluster="${1}"
  if [ -z ${cluster} ]; then echo "Cluster Nickname Required."; return; fi
  es-get "${cluster}" '/_security/role_mapping' | jq -r 'keys[]'
}

# Get specific role mapping
# es-get-role-mapping <cluster_nickname> <role_name>
es-get-role-mapping() {
  local cluster="${1}"
  local mapping="${2}"
  if [ -z ${cluster} ]; then echo "Cluster Nickname Required."; return; fi
  if [ -z ${mapping} ]; then echo "Name of Role Mapping Required."; return; fi
  es-get ${cluster} "/_security/role_mapping/${mapping}"
}

# Disable specific role mapping
# es-disable-role-mapping <cluster_nickname> <role_name>
es-disable-role-mapping() {
  local cluster="${1}"
  local mapping="${2}"
  if [ -z ${cluster} ]; then echo "Cluster Nickname Required."; return; fi
  if [ -z ${mapping} ]; then echo "Name of Role Mapping Required."; return; fi
  local role_json="$(es-get-role-mapping ${cluster} ${mapping} | jq -r '.[].enabled = false | .[]')"
  es-put ${cluster} "/_security/role_mapping/${mapping}" "${role_json}"
}

# Get Elasticsearch role
# es-get-role <cluster_nickname> <role_name>
es-get-role() {
  local cluster="${1}"
  local role="${2}"
  if [ -z ${cluster} ]; then echo "Cluster Nickname Required."; return; fi
  if [ -z ${role} ]; then echo "Name of Role Required."; return; fi
  es-get "${cluster}" "/_security/role/${role}"
}

# Push Elasticsearch user role
# es-put-role <cluster_nickname> <role_json_file> [force]
es-put-role() {
  local cluster="${1}"
  local file="${2}"
  local overwrite="${3}"
  local filename="${file##*/}"
  local json="$(jq -r '.[]' ${file})"
  if [[ -n "$(es-get-role ${cluster} ${filename} | jq .[])" ]]; then
    if [[ ${overwrite} != "force" ]]; then
      echo "Role already exists."
      return
    fi
    es-post "${cluster}" "/_security/role/${filename%%\.*}" "$(echo ${json})"
  else
    es-put "${cluster}" "/_security/role/${filename%%\.*}" "$(echo ${json})"
  fi
}

# Get specific user details from Elastic server
# es-get-user <cluster_nickname> <user_name>
es-get-user() {
  local cluster="${1}"
  local username="${2}"
  if [ -z ${cluster} ]; then echo "Cluster Nickname Required."; return; fi
  if [ -z ${username} ]; then echo "Name of User Required."; return; fi
  es-get ${cluster} "/_security/user/${username}"
}

# Create New Elastic User
# roles must be a string including quotes and commas, eg. '"new","user","roles"'
# es-create-user <cluster_nickname> <user_name> <user_password> [roles] [email] [full_name]
es-create-user() {
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


# Dump Elasticsearch configurations
# es-dump-all-configs <cluster_nickname> <output_folder>
es-dump-all-configs() {
  local cluster=${1}
  local folder=${2}
  mkdir -p "${folder}/index_templates"
  for p in $(es-get ${cluster} /_template | jq -r 'keys[]');do echo "template: $p";es-get "${cluster}" "/_template/$p" > "${folder}/index_templates/$p.json" ;done
  mkdir -p "${folder}/aliases"
  es-get ${cluster} /_cat/aliases | awk '{print $1}' | grep -v '^\.' | sort -u > "${folder}/aliases/aliases"
  mkdir -p "${folder}/ilm"
  for p in $(es-get ${cluster} /_ilm/policy | jq -r 'keys[]');do echo "ilm: $p";es-get "${cluster}" "/_ilm/policy/$p" > "${folder}/ilm/$p.json" ;done
  mkdir -p "${folder}/index_patterns"
  for p in $(es-kb-get ${cluster} /api/saved_objects/_find?type=index-pattern | jq -r '.saved_objects[] | @base64');do
    title=$(echo "$p"| base64 --decode | jq -r .attributes.title);
    echo "index_pattern: ${title}"
    echo "$p" | base64 --decode | jq . > "${folder}/index_patterns/${title%\*}.json"
  done
  mkdir -p "${folder}/roles"
  for p in $(es-get ${cluster} /_security/role | jq -r 'keys[]');do echo "role: $p";es-get "${cluster}" "/_security/role/$p" > "${folder}/roles/$p.json" ;done
  mkdir -p "${folder}/users"
  for p in $(es-get ${cluster} /_security/user | jq -r 'keys[]');do echo "user: $p";es-get "${cluster}" "/_security/user/$p" > "${folder}/users/$p.json" ;done
  mkdir -p "${folder}/snapshots"
  for p in $(es-get ${cluster} /_snapshot | jq -r 'keys[]');do echo "snapshot: $p";es-get "${cluster}" "/_snapshot/$p" > "${folder}/snapshots/$p.json" ;done
}

# Push Elasticsearch index-patterns
# es-put-index-pattern <cluster_nickname> <input_json_file>
es-put-index-pattern() {
  local cluster="${1}"
  local file="${2}"
  local title="$(jq -r '.attributes.title' ${file})"
  local timeFieldName="$(jq -r '.attributes.timeFieldName' ${file})"
  #local fields="$(jq '.attributes.fields | fromjson |.' ${file})"
  local json="{\"index_pattern\": { \"title\" : \"${title}\",\"timeFieldName\" : \"${timeFieldName}\"}}"
  local pattern="$(es-kb-get ${cluster} /api/saved_objects/_find?type=index-pattern | jq -r '.saved_objects[].attributes.title')"
  local kibana_version="$(es-kb-get ${cluster} /api/status | jq -r '.version.number')"
  echo "title: ${title}"
  version-test ${kibana_version} lt "7.10"
  if [[ $? == 0 ]]; then
    echo "Kibana version must be 7.10 or higher to use index_pattern api"
    return 1
  fi
  echo "${pattern}" | grep -F "${title}"
  if [[ -n "$(echo "${pattern}" | grep -F "${title}")" ]]; then
    echo "Index pattern ${title} exists"
    return
  fi
  local index="$(es-get ${cluster} /${title} | jq -r 'keys[0]')"
  if [[ "${index}" == "error" ]] || [[ "${index}" == "null" ]]; then
    echo "No indices match ${title}"
    return
  fi
  es-kb-post ${cluster} /api/index_patterns/index_pattern "$(echo ${json})"
}

# Push Elasticsearch legacy index-template
# es-put-template <cluster_nickname> <input_json_file>
es-put-template() {
  local cluster="${1}"
  local file="${2}"
  local filename="${file##*/}"
  local json="$(jq -r '.[].mappings |= { _doc: . } | .[]' ${file})"
  json="$( echo ${json} | jq '.settings.index += { "number_of_shards":"3","number_of_replicas":"1" }')"
  es-put "${cluster}" "/_template/${filename%%\.*}?include_type_name" "$(echo ${json})"
}

# Push Elasticsearch index-template
# es-put-index-template <cluster_nickname> <input_json_file>
es-put-index-template() {
  local cluster="${1}"
  local file="${2}"
  local filename="${file##*/}"
  local json="$(cat ${file})"
  es-put "${cluster}" "/_index_template/${filename%%\.*}" "$(echo ${json})"
}

# Push Elasticsearch component-template
# es-put-component-template <cluster_nickname> <input_json_file>
es-put-component-template() {
  local cluster="${1}"
  local file="${2}"
  local filename="${file##*/}"
  local json="$(cat ${file})"
  es-put "${cluster}" "/_component_template/${filename%%\.*}" "$(echo ${json})"
}

# Push Elasticsearch aliases after templates and ilm exists
# es-put-alias <cluster_nickname> <alias>
es-put-alias() {
  local cluster="${1}"
  local alias="${2}"
  if [[ -n "$(es-get ${cluster} /_cat/aliases/${alias} | awk '{print $1}')" ]]; then
    echo "Alias ${alias} already exists"
    return
  fi
  local index="$(es-get ${cluster} /${alias} | jq -r 'keys[0]')"
  if [[ "${index}" != "error" ]] && [[ "${index}" != "null" ]]; then
    echo "Index ${alias} name conflict."
    return
  fi
  es-put "${cluster}" "/%3C${alias}-%7Bnow%2Fd%7D-000001%3E" "{\"aliases\":{\"${alias}\": {\"is_write_index\":\"true\"}}}"
}

# Push Elasticsearch Index Lifecycle Management
# es-put-ilm <cluster_nickname> <input_json_file>
es-put-ilm() {
  local cluster="${1}"
  local file="${2}"
  local filename="${file##*/}"
  local json="$(jq -r '{ policy: .[].policy}' ${file})"
  es-put "${cluster}" "/_ilm/policy/${filename%%\.*}" "$(echo ${json})"
}

# PUT _slm/policy/double-daily-snapshots
# {
#   "name": "<dayly-snap-{now{yyyy.MM.dd.HH}}>",
#   "schedule": "0 1 */12 * * ?",
#   "repository": "prod-s3-001",
#   "config": {
#     "indices": [],
#     "ignore_unavailable": true,
#     "partial": true
#   },
#   "retention": {
#     "expire_after": "3d",
#     "min_count": 2,
#     "max_count": 5
#   }
# }

# Update secrets file with new cluster IP
# ees-update-dps <cluster_nickname>
es-update-dps() {
  local cluster="${1}"
  local name="fic-mad-prod-$(lower ${cluster})-elasticsearch-db-c-1"
  local ipaddress=$(aws-ec2-name ${name} | jq -r '.Reservations[].Instances[].PrivateIpAddress')
  cat ${HOME}/.secrets.sh | sed "s/ELASTIC\[${cluster}\].*/ELASTIC\[${cluster}\]=\"https:\/\/${ipaddress}:9200\"/g" > ${HOME}/tmp/.secrets.sh
  mv ${HOME}/tmp/.secrets.sh ${HOME}/.secrets.sh
}

# If you source this file directly, apply the overwrites.
if [ -z "$(echo "$(script_origin)" | grep -F "shrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi
