sh_source
_this="$( script_source )"
_sources+=("$(basename ${_this})")

ssh-git-account () {
  local account="${1}"
  case ${account} in
    *andiant*|DDPMCP) ssh-load-keys mandiant git;;
    opera) ssh-load-keys opera;;
    analyticsMD|Redw0od) ssh-load-keys stanton;;
    *) ssh-load-keys stanton;;
  esac
} 


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
			vault_profile primary dev
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

kube-profile () {
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

aws-mfa-token () {
  local profile="${1}"
  local token_code=""
  case "${profile}" in
    *)
      token_code="$(gauth | grep 'Respond AWS' | awk '{print $4}')";;
  esac
  echo "${token_code}"
}

vault_profile () {
  local profile="${1^^}"
  local stage="${2:-prod}"
  export VAULT_ADDR="${VAULTS[${profile}]}"
  export VAULT_TOKEN="${TOKENS[${profile}]}"
  export VAULT_SSH=~/.ssh/mandiant/mad-${stage,,}-${profile,,}-key.key
  export VAULT_PROFILE="${profile}"
}