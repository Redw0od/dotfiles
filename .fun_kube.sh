THIS="$( basename ${BASH_SOURCE[0]} )"
SOURCE[$THIS]="${THIS%/*}"
echo "RUNNING ${THIS}"

UTILITIES+=("echo" "awk" "grep" "cat" "kubectl" "pkill" "printf" "base64" "jq" "curl" "wget")

# Gives details on functions in this file
# Call with a function's name for more information
kube-help () {
  local func="${1}"
  local func_names="$(cat ${BASH_SOURCE[0]} | grep '^kube-' | awk '{print $1}')"
  if [ -z "${func}" ]; then
    echo "Helpful kubernetes functions."
    echo "For more details: ${GREEN}kube-help [function]${NORMAL}"
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

# PS1 output for Kubernets Context
kube-ps1-color () {
  case "${KUBE_ENV}" in
    gov)
      echo -e "${ORANGE}${KUBE_ENV}${NORMAL}"
      ;;
    dev)
      echo -e "${YELLOW}${KUBE_ENV}${NORMAL}"
      ;;
    corp)
      echo -e "${GRAY}${KUBE_ENV}${NORMAL}"
      ;;
    *)
      echo -e "${RED}${BOLD}${KUBE_ENV}${NORMAL}"
      ;;
  esac
}

# Change kubernetes context and update session variables
kube-profile () {
   export KUBECONFIG=${HOME}/.kube/conubectl:${HOME}/.kube/config/kubecfg.yaml
   case "$1" in
       prod)
           export KOPS_CLUSTER_NAME=${KUBE[PRODCLUSTER]}
           kubectl config use-context PRODCLUSTER
           ;;
       dev)
           export KOPS_CLUSTER_NAME=${KUBE[DEVCLUSTER]}
           kubectl config use-context DEVCLUSTER
           ;;
       *)
           export KOPS_CLUSTER_NAME=${KUBE[${1}]}
           kubectl config use-context ${1}
           ;;
   esac
   export KUBE_ENV="${1}"
   echo "Current k8s Context: $(kubectl config current-context)" 
}

# Port forward rabbit-mq and display connection details
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
kube-safe-apply () {
  if [[ " ${@} " =~ "apply" ]] || [[ " ${@} " =~ "delete" ]]; then 
    echo -e -n "Running on cluster: ${YELLOW_BG}$(echo $(kubectl config current-context)| awk '{print toupper($0)}')${NORMAL}, "
    read -p "continue? (y/n) " CONFIRM
     [[ $CONFIRM != "y" ]] && echo "quit" && return
  fi
  #kubectl $*
  kube-check-server-binary $*
}

# Report resource usage inside pods
kube-pod-top () {  
  local nodes=${1}
  local fmt="%6s %5s %7s %-12s\n"
  local top=""
  if [ ! -z "${nodes}" ]; then
    printf "$fmt" "CPU" "Mem" "Process" "Node" 
    for n in ${nodes}; do
      top=$(kubectl -n shared exec $n -c elasticsearch -- top -b -n 1 | grep -A 1 PID | grep -v PID)
      printf "$fmt" $(echo $top | awk '{print $9}') $(echo $top | awk '{print $10}')  $(echo $top | awk '{print $12}') ${n}
    done
  else 
    echo "nodes: $nodes"
  fi
}

# Access kubernetes secret for elasticsearch api keys
# kube-es-key [secret] [namespace]
kube-es-key () {
  local keyname=${1}
  local ns=${2:-shared}
  local secret_json=$(kubectl -n ${ns} get secret ${keyname} -o json | jq .data)
  local api_key=$(echo ${secret_json} | jq -r .api_key | base64 --decode)
  local id=$(echo ${secret_json} | jq -r .id | base64 --decode)
  echo "${id}:${api_key}"
}

# Access kubernetes secret for elasticsearch user credentials
# kube-es-creds [secret] [namespace]
kube-es-creds () {
  local keyname=${1}
  local ns=${2:-shared}
  local secret_json=$(kubectl -n ${ns} get secret ${keyname} -o json | jq .data)
  local user=$(echo ${secret_json} | jq -r .username | base64 --decode)
  local pass=$(echo ${secret_json} | jq -r .password | base64 --decode)
  echo "${user}:${pass}"
}
####### RDS FUNCTIONS

kube-check-binary () {
  if [[ -z "$(which kubectl)" ]]; then
    echo "install kubectl"
    return 1
  fi
  local version="$(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')"
  local latest="$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)"  
  if [[ "${version}" != "${latest}" ]]; then
    echo "New kubectl version available. Current: ${version}, Latest: ${latest}"
  fi
}

kube-check-server-binary () {
  local server="$(kubectl version -o json 2> /dev/null | jq -r '.serverVersion.gitVersion')"
  local client="$(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')"
  if [[ "${server}" != "${client}" ]]; then
    if [[ ! "$(which kubectl${server})" ]]; then
      wget -q -P /tmp/ https://storage.googleapis.com/kubernetes-release/release/${server}/bin/linux/amd64/kubectl
      chmod +x /tmp/kubectl
      sudo mv /tmp/kubectl /usr/local/bin/kubectl${server}
    fi
    kubectl${server} $*
  else
    kubectl $*
  fi
}

# If you source this file directly, apply the overwrites.
if [ -z "$(echo "${BASH_SOURCE[*]}" | grep -F "bashrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi