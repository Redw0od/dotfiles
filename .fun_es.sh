THIS="$( basename ${BASH_SOURCE[0]} )"
SOURCE[$THIS]="${THIS%/*}"
echo "RUNNING ${THIS}"

UTILITIES+=("echo" "awk" "grep" "cat" "curl" "base64" "tr" "printf" "wc" "sort" "kubectl" "pkill" "sleep")

# Gives details on functions in this file
# Call with a function's name for more information
es-help () {
  local func="${1}"
  local func_names="$(cat ${BASH_SOURCE[0]} | grep '^es-' | awk '{print $1}')"
  if [ -z "${func}" ]; then
    echo "Helpful Elasticsearch functions."
    echo "For more details: ${GREEN}es-help [function]${NORMAL}"
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

# Curl Elasticsearch with API key
# es-curl [url] [ApiKey]
es-curl () {
  local cURL="${1}"
  local cAPI="${2}"
  if [ -z ${cURL} ]; then echo "need URL"; return;fi
  local H1="'Content-Type: application/json'"
  local H2="Authorization: ApiKey ${cAPI}"
  curl -sk ${cURL} -H ${H1} -H "${H2}"
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

# Curl PUT Elasticsearch with API key
# es-put-user [cluster] [api endpoint] [data]
es-put-user () {
  local cluster="${1}"
  local endpoint="${2}"
  local eDATA="${3}"
  local AUTH="${4}"
  local eKEY=$(echo -n "${APIKEYS[${cluster}]}" | base64 | tr -d \\r)
  local eURL="${ELASTIC[${cluster}]}${endpoint}"
  local H1="Content-Type: application/json"
  curl -u "${AUTH}" -sk -XPUT ${eURL} -H "${H1}" -d "${eDATA}"
}

# Curl POST Elasticsearch with API key
# es-post-user [cluster] [api endpoint] [data]
es-post-user () {
  local cluster="${1}"
  local endpoint="${2}"
  local eDATA="${3}"
  local AUTH="${4}"
  local eKEY=$(echo -n "${APIKEYS[${cluster}]}" | base64 | tr -d \\r)
  local eURL="${ELASTIC[${cluster}]}${endpoint}"
  local H1="Content-Type: application/json"
  curl -u "${AUTH}" -sk -XPOST ${eURL} -H "${H1}" -d "${eDATA}"
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

# If you source this file directly, apply the overwrites.
if [ -z "$(echo "${BASH_SOURCE[*]}" | grep -F "bashrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi