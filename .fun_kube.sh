
sh_source
_this="$( script_source )"
_sources+=("$(basename ${_this})")

UTILITIES+=("echo" "awk" "grep" "cat" "kubectl" "pkill" "printf" "base64" "jq" "curl" "wget")
abbr='kube'
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

# PS1 output for Kubernets Context
kube-ps1-color () {
  case "${KUBE_ENV}" in
    gov)
      echo -e "${ORANGE}${KUBE_ENV}${color[default]}"
      ;;
    dev)
      echo -e "${color[yellow]}${KUBE_ENV}${color[default]}"
      ;;
    corp)
      echo -e "${color[gray]}${KUBE_ENV}${color[default]}"
      ;;
    *)
      echo -e "${color[red]}${BOLD}${KUBE_ENV}${color[default]}"
      ;;
  esac
}

# Change kubernetes context and update session variables
# kube-profile [cluster name]
kube-profile () {
  local cluster_name="${1}"
   export KUBECONFIG=${HOME}/.kube/conubectl:${HOME}/.kube/config/kubecfg.yaml
   case "${cluster_name}" in
       prod)
           export KOPS_CLUSTER_NAME=${KUBE[PROD_CLUSTER]}
           kubectl config use-context PRODCLUSTER
           ;;
       dev)
           export KOPS_CLUSTER_NAME=${KUBE[DEV_CLUSTER]}
           kubectl config use-context DEVCLUSTER
           ;;
       *)
           export KOPS_CLUSTER_NAME=${KUBE[${cluster_name}]}
           kubectl config use-context ${cluster_name}
           ;;
   esac
   export KUBE_ENV="${cluster_name}"
   echo "Current k8s Context: $(kubectl config current-context)" 
}

# Port forward rabbit-mq and display connection details
# kube-forward-rabbit <k8s namespace> [k8s service name]
kube-forward-rabbit () {
   local namespace=${1}
   local service=${2:-rabbitmq}
   echo "kubectl port-forward -n ${namespace} service/${service} 15672:15672"
   echo 'use kube-stop to kill port-forward'
   kubectl port-forward -n ${namespace} service/${service} 15672:15672 > /dev/null 2>&1 &
}

# Kill all port-forward sessions
kube-stop () {
   pkill kubectl
}

# Confirm all apply and deletes are against the correct cluster
# kube-safe-apply <kubectl arguments>
kube-safe-apply () {
  if [[ " ${@} " =~ "apply" ]] || [[ " ${@} " =~ "delete" ]]; then 
    echo -e -n "Running on cluster: ${color[yellow_bg]}$(echo $(kubectl config current-context)| awk '{print toupper($0)}')${color[default]}, "
    read -p "continue? (y/n) " CONFIRM
     [ ${CONFIRM} != "y" ] && echo "quit" && return
  fi
  #kubectl $*
  kube-check-server-binary $*
}

# Change init container tag for all deployments in a namespace
# kube-deploy-init-change <tag name> [namespace]
kube-deploy-init-change () {
  local tag=${1}
  local namespace=${2:-default}
  for d in $(kube-check-server-binary -n ${namespace} get deploy --no-headers | awk '{print $1}' ); do 
    img=$(kube-check-server-binary -n ${namespace} get deploy/$d -o json | jq -er '.spec.template.spec.initContainers[].image' 2> /dev/null)
    if [ $? != 0 ]; then echo "${color[fail]}deploy/$d has no init container${color[default]}"; continue; fi
    kube-check-server-binary -n ${namespace} get deploy/$d -o json | jq ".spec.template.spec.initContainers[].image = \"${img%%:*}:${tag}\"" | kubectl apply -f -
  done
}

# Report resource usage inside pod
# kube-pod-top <pod name> [namespace] [container] [header bool]
kube-pod-top () {  
  local pod=${1}
  local namespace="${2:+"-n ${2}"}"
  local container="${3:+"-c ${3}"}"
  local header="${4:-true}"
  local fmt="%6s %5s %7s %-12s\n"
  if [ -z "${pod}" ]; then return 1; fi
  if [ -n "$(shell_utilities 'kubectl' )" ]; then return 1; fi
  if [ "${header}" == "true" ]; then printf "$fmt" "CPU" "Mem" "Process" "Node" ; fi  
  local top=$(kubectl ${namespace} exec "${pod}" ${container} -- top -b -n 1 2> /dev/null | grep -A 1 PID | grep -v PID) 
  if [ $? != 0 ]; then echo "ERROR running top on ${namespace}:${pod}"; return; fi
  printf "$fmt" $(echo $top | awk '{print $9}') $(echo $top | awk '{print $10}')  $(echo $top | awk '{print $12}') ${pod}
}

# Report resource usage inside pods
# kube-pods-top < "${PODS[@]}" > [namespace] [container] [header bool]
kube-pods-top () {  
  local pods=${1}
  local namespace=${2}
  local container=${3}
  local header="${4:-true}"
  local fmt="%6s %5s %7s %-12s\n"
  if [ -z "${pods}" ]; then return 1; fi
  if [ "${header}" == "true" ]; then printf "$fmt" "CPU" "Mem" "Process" "Node" ; fi  
  for pod in ${pods}; do
    kube-pod-top ${pod} "${namespace}" "${container}" "false"
  done
}

# Access kubernetes secret for elasticsearch api keys
# kube-es-key <secret> [namespace]
kube-es-key () {
  local keyname="${1}"
  local ns="-n ${2}"
  if [ -z "${keyname}" ]; then return 1; fi
  local secret_json=$(kubectl ${ns} get secret "${keyname}" -o json | jq .data)
  local api_key=$(echo ${secret_json} | jq -r .api_key | base64 --decode)
  local id=$(echo ${secret_json} | jq -r .id | base64 --decode)
  echo "${id}:${api_key}"
}

# Access kubernetes secret for elasticsearch user credentials
# kube-es-creds [secret] [namespace]
kube-es-creds () {
  local keyname="${1}"
  local ns="-n ${2}"
  if [ -z "${keyname}" ]; then return 1; fi
  local secret_json=$(kubectl ${ns} get secret "${keyname}" -o json | jq .data)
  local user=$(echo ${secret_json} | jq -r .username | base64 --decode)
  local pass=$(echo ${secret_json} | jq -r .password | base64 --decode)
  echo "${user}:${pass}"
}

# Check for new update to kubectl
kube-check-binary () {
  if [ -n "$(shell_utilities 'kubectl' )" ]; then return 1; fi
  local version="$(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')"
  local latest="$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)"  
  if [[ "${version}" != "${latest}" ]]; then
    echo "New kubectl version available. Current: ${version}, Latest: ${latest}"
  fi
}

# Compare default kubectl version to k8s server version
# Then attempt to download and run commands on matching versions
kube-check-server-binary () {
  local server="$(kubectl version -o json 2> /dev/null | jq -er '.serverVersion.gitVersion' | cut -d '-' -f 1)"
  if [ "${server}" = "null" ]; then echo "Failed to query server. Check VPN or reauthenticate.";return; fi
  local client="$(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')"
  if [ "${server}" != "${client}" ]; then
    if [ ! "$(which kubectl${server})" ]; then
      echo "Server version [${server}] mismatch client [${client}]"
      wget -q -P /tmp/ https://storage.googleapis.com/kubernetes-release/release/${server}/bin/linux/amd64/kubectl
      if [ -f "/tmp/kubectl" ]; then
        chmod +x /tmp/kubectl
        sudo mv /tmp/kubectl /usr/local/bin/kubectl${server}
      else
        echo "Failed to download matching kubectl version. Using default"
        kubectl $*
      fi
    fi
    kubectl${server} $*
  else
    kubectl $*
  fi
}

# Pass object json and strip out ephemeral details
# echo jsonfile > kube-export
kube-export () {
  jq 'del(.metadata.namespace,.metadata.resourceVersion,.metadata.uid) | .metadata.creationTimestamp=null'
}

kube-export-yaml () {
  yq 'del(.metadata.namespace,.metadata.resourceVersion,.metadata.uid,.metadata.annotations."kubectl.kubernetes.io/last-applied-configuration") | .metadata.creationTimestamp=null'
}

# Decode base64 encoded values in .data object
# kube-show-secret <namespace> <secret name>
kube-show-secret () {
  local namespace="${1}"
  local secret_name="${2}"
  kube-safe-apply -n "${namespace}" get secret "${secret_name}" -o json | jq -r '.data | map_values(@base64d)'
}

# Get all pods over a specified number of days old
# kube-list-old-pods [days]
kube-list-old-pods () {
  local days=${1:-0}
  local seniors=$(kubectl get pod --all-namespaces | awk 'match($6,/d/) {print $0}')
  local age=0
  IFS_BACKUP=$IFS; IFS=$'\n'
  for pod in ${seniors[@]}; do 
    age=$(echo "${pod}" | awk '{print $6}' | cut -dd -f1)
    if [ ${days} -lt ${age} ]; then
      echo "${pod}"
    fi
  done
  IFS=$IFS_BACKUP
}

# Take a list of pods and terminate them
# kube-list-old-pods 6 | grep 'event\|resource' | kube-rollover-pods
# kubectl get pods | kube-rollover-pods <namespace>
kube-rollover-pods () {
  local namespace="${1}"
  local deathnote deathqueue pod 
  local backup_ifs=$IFS
  IFS=$'\n'
  for list in $(cat - ); do
    fields="$(echo $list | awk '{print NF}')"
    if [ "${fields}" == "5" ]; then
      if [ -z "${namespace}" ]; then echo "Missing Namespace.";return;fi
      pod="$(echo $list | awk '{print $1}')"
    fi
    if [ "${fields}" == "6" ]; then
      namespace="$(echo $list | awk '{print $1}')"
      pod="$(echo $list | awk '{print $2}')"
    fi
    echo "kubectl -n ${namespace} delete pod/${pod}"
    kubectl -n ${namespace} delete pod/${pod} &
  done
  IFS=$backup_ifs
}

# If you source this file directly, apply the overwrites.
if [ -z "$(echo "$(script_origin)" | grep -F "shrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi

# jq patch configmap with setting
# for ns in ${NS[@]}; do k -n $ns get configmap logstash-metrics-pipeline -o json | jq '.data."input_main.conf" |= sub("}\n}";"    security_protocol => \"SSL\"\n  }\n}")' | kubectl -n $ns apply -f -; done
# for ns in ${NS[@]}; do k -n $ns get configmap logstash-onprem-logs-pipeline -o json | jq '.data."input_main.conf" |= sub("}\n}";"    security_protocol => \"SSL\"\n  }\n}")' | kubectl -n $ns apply -f -; done