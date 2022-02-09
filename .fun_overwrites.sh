THIS="$( basename ${BASH_SOURCE[0]} )"
SOURCE[$THIS]="${THIS%/*}"
echo "RUNNING ${THIS}"

ssh-git-account () {
  local account="${1}"
  case ${account} in
    corp) ssh-load-keys corp;;
    personal) ssh-load-keys ;;
    school) ssh-load-keys college;;
    *) ssh-load-keys ${account};;
  esac
} 

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

mad-assume () { 
	local name="${1}"
	local force="${2}"
	case "${name}" in
		prod)
			ssh-load-keys new_prod
			aws-apply-profile prod ${force}
			kube-profile 
			vault-profile primary
			;;
		dev)
			ssh-load-keys dev
			aws-apply-profile dev ${force}
			kube-profile dev
			vault-profile dev
			;;
		*)
			aws-apply-profile ${name} ${force}
			ssh-load-keys ${name}
			aws-apply-profile ${name} ${force}
			kube-profile ${name}
			vault-profile ${name}
			;;
   	esac
}
