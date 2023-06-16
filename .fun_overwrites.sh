sh_source
_this="$( script_source )"
_sources+=("$(basename ${_this})")

ssh-git-account() {
  local account="${1}"
  case ${account} in
    *andiant*|DDPMCP) ssh-load-keys mandiant;;
    Redw0od) ssh-load-keys stanton;;
    *) ssh-load-keys mandiant;;
  esac
}

kube-profile() {
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
# PS1 output for Kubernets Context
kube-ps1-color() {
  local k8s_cluster="${CK8S_ALIAS}"
  case "${k8s_cluster}" in
    *gov)
      echo -e "${ORANGE}${k8s_cluster}${color[default]}"
      ;;
    *dev*)
      echo -e "${color[yellow]}${k8s_cluster}${color[default]}"
      ;;
    *stage*)
      echo -e "${color[gray]}${k8s_cluster}${color[default]}"
      ;;
    *)
      echo -e "${color[red]}${BOLD}${k8s_cluster}${color[default]}"
      ;;
  esac
}

mad-assume() {
	local name="${1}"
	local force="${2}"
	export MAD_PROFILE="${name}"
	case "${name}" in
		grunt|prod)
			ssh-load-keys mandiant git
			aws-apply-profile respond-prod ${force}
			kube-profile prod
			vault-profile primary
			;;
		usw2)
			ssh-load-keys mandiant git
			aws-apply-profile respond-prod ${force}
			kube-profile ${name}
			vault-profile primary
			;;
		apse1|apse2|euw1)
			ssh-load-keys mandiant git
			aws-apply-profile respond-prod ${force}
			kube-profile ${name}
			vault-profile ${name}
			;;
		mordin|dev)
			ssh-load-keys mandiant git
			aws-apply-profile respond-dev ${force}
			kube-profile dev
			vault-profile primary dev
			;;
		legion|corp)
			ssh-load-keys mandiant git
			aws-apply-profile respond ${force}
			kube-profile corp
			vault-profile primary
			;;
		gov)
			ssh-load-keys mandiant git
			aws-apply-profile respond-${name} ${force}
			kube-profile ${name}
			vault-profile ${name}
			;;
		ops)
			ssh-load-keys mandiant git
			aws-apply-profile respond-${name} ${force}
			kube-profile ${name}
			vault-profile primary
			;;
		sso)
			ssh-load-keys mandiant git
			aws-apply-profile respond-${name} ${force}
			kube-profile prod
			vault-profile primary
			;;
		sec)
			ssh-load-keys mandiant git
			aws-apply-profile respond-${name} ${force}
			;;
		stanton)
			ssh-load-keys stanton
			aws-apply-profile ${name} ${force}
			kube-profile ${name}
			;;
		tag)
			ssh-load-keys tag
			aws-apply-profile ${name} ${force}
			;;
		*)
			aws-apply-profile ${name} ${force}
			;;
   	esac
}

kube-profile() {
   export KUBECONFIG=${HOME}/.kube/conubectl:${HOME}/.kube/config/kubecfg.yaml
   source ${GITHOME}/mandiant/dev-ops/k8s/env.sh
   case "$1" in
       prod)
           export KOPS_CLUSTER_NAME=${KUBE[GRUNT]}
           kubectl config use-context grunt
           ;;
       apse1)
           export KOPS_CLUSTER_NAME=${KUBE[APSE1]}
           kubectl config use-context mad-prod-apse1-eks
           ;;
       apse2)
           export KOPS_CLUSTER_NAME=${KUBE[APSE2]}
           kubectl config use-context mad-prod-apse2-eks
           ;;
       euw1)
           export KOPS_CLUSTER_NAME=${KUBE[EUW1]}
           kubectl config use-context mad-prod-euw1-eks
           ;;
       usw2)
           export KOPS_CLUSTER_NAME=${KUBE[USW2]}
           kubectl config use-context mad-prod-usw2-eks
           ;;
       dev)
           export KOPS_CLUSTER_NAME=${KUBE[MORDIN]}
           kubectl config use-context mordin
           ;;
       corp)
           export KOPS_CLUSTER_NAME=${KUBE[LEGION]}
           kubectl config use-context legion.k8s.corp.respond-ops.com
           ;;
       gov)
           export KOPS_CLUSTER_NAME=
           kubectl config use-context mas-gov-001
           ;;
       *)
           export KOPS_CLUSTER_NAME=
           ;;
   esac
   export KUBE_ENV="${1}"
   echo "Current k8s Context: $(kubectl config current-context)"
}

aws-mfa-token() {
  local profile="${1}"
  local token_code=""
  case "${profile}" in
    *)
      token_code="$(gauth | grep 'Respond AWS' | awk '{print $4}')";;
  esac
  echo "${token_code}"
}

vault-profile() {
  local profile="$(upper ${1})"
  local stage="${2:-prod}"
  case $profile in
    GRUNT|MORDIN|LEGION) profile="PRIMARY";;
  esac
  export VAULT_ADDR="${VAULTS[${profile}]}"
  export VAULT_TOKEN="${TOKENS[${profile}]}"
  export VAULT_SSH=~/.ssh/mandiant/mad-$(lower ${stage})-$(lower ${profile})-key.key
  export VAULT_PROFILE="${profile}"
}

kafka-sgs() {
  aws-ec2-name '*kafka*' | jq -r '.[] | .[].Instances[].NetworkInterfaces[].Groups[].GroupId'
}
kafka-instances() {
  aws-ec2-name '*kafka*' | jq -r '.[] | .[].Instances[].InstanceId'
}

zookeeper-sgs() {
  aws-ec2-name '*zookeeper*' | jq -r '.[] | .[].Instances[].NetworkInterfaces[].Groups[].GroupId'
}

zookeeper-instances() {
  aws-ec2-name '*zookeeper*' | jq -r '.[] | .[].Instances[].InstanceId'
}


zookeeper-brokers() {
  local server=${1:-$ZOOKEEPER_ADDRESS}
  zkcli -server ${server} ls /brokers/ids
}

zookeeper-broker() {
  local id=${1}
  local server=${2:-$ZOOKEEPER_ADDRESS}
  zkcli -server ${server} get /brokers/ids/${id}
}

path-prepend "/usr/local/google"

# color[ps1day]=${color[red]}
# color[ps1date]=${color[orange]}
# color[ps1time]=${color[mustard]}
# color[ps1param]=${color[darkgray]}
# color[ps1dash]=${color[darkgray]}
# color[ps1cpu]=${color[yellow]}
# color[ps1cpuval]=${color[lime_yellow]}
# color[ps1job]=${color[lightgreen]}
# color[ps1vault]=${color[green]}
# color[ps1bracket]=${color[gray]}
# color[ps1aws]=${color[cerulean]}
# color[ps1awsval]=${color[red]}
# color[ps1kube]=${color[blue]}
# color[ps1kubeval]=${color[red]}
# color[ps1user]=${color[purple]}
# color[ps1dir]=${color[lightmagenta]}
# color[ps1files]=${color[purple]}
# color[ps1size]=${color[burgandy]}
# color[ps1error]=${color[red]}
# color[ps1errorval]=${color[lightred]}
