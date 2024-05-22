sh_source
_this="$( script_source )"
_sources+=("$(basename ${_this})")

abbr='goog'

# Create help function for this file
common-help "${abbr}" "${_this}"

export CLOUDTOP_PROXY=true

# Set shell proxy by cluster name
# goog-proxy [cluster]
goog-proxy() {
	local cluster=${1}
	case "$(lower ${cluster})" in
		legion|apse2)
			proxy-set 10100;;
		*)
			proxy-set 10101;;
	esac
}

sso-expect() {
	local script="${1}"
	local passcode="$(cat ${HOME}/.expect)"
	local stamp="$(date '+%s')"
	local expect_file="${HOME}/tmp/exp-${stamp}.exp"
	local script_file="${HOME}/tmp/scr-${stamp}.sh"
	echo -e "#!/usr/bin/env bash\nsource ${HOME}/.profile\n${script}" > "${script_file}"
  	chmod 777 "${script_file}"
  	echo "set timeout -1
spawn ${script_file}
match_max 100000
expect -exact \"SSO password for ${USER}: \"
send -- \"${passcode}\\r\"
expect eof" > "${expect_file}"
	chmod 700 "${expect_file}"
	expect "${expect_file}"
	rm -f "${expect_file}"
	rm -f "${script_file}"
}

cs-find() {
  local folder=$(cs --local -l -color never -a "$1" 2> /dev/null | fzf )
  cd $(dirname ${folder})
}


alias goodmorning="ck8s -p charlie14/home1; ck8s -p core-cf-prod/cloudferry-prod"
alias tf="/google/data/ro/teams/terraform/bin/terraform"
alias prodspec="/google/bin/releases/rollouts/prodspec/prodspec"
alias annealing='/google/bin/releases/rollouts/annealing/annealing'
alias proxy-check="goog-proxy"
alias respond5h="export PROXY=respond5h;proxy-set 10101 socks5h"
alias respond="export PROXY=respond;proxy-set 10101"
alias rampart5h="export PROXY=rampart5h;proxy-set 10101 socks5h"
alias rampart="export PROXY=rampart;proxy-set 10100"
alias mesa-gcp="export PROXY=mesa-gcp;proxy-set 10102"
alias uplink="export PROXY=uplink;proxy-set 999 http"
alias noproxy='proxy-clear'
alias proxy='export | grep socks'
#alias ssh="kitty +kitten \ssh"
alias vault-ssh="ssh -o \"ProxyCommand=nc -X 5 -x localhost:10101 %h %p\" -i \${VAULT_SSH}"
alias rampart-ssh="ssh -o \"ProxyCommand=nc -X 5 -x localhost:10100 %h %p\""
alias respond-ssh="ssh -o \"ProxyCommand=nc -X 5 -x localhost:10101 %h %p\""
alias custom-uplink='/google/data/rw/users/mg/mgooderum/uplink/custom_uplink'
alias tmux-respond='tmux -CC new-session -A -t Respond'
alias tmux-mandiant='tmux -CC new-session -A -t Mandiant'
alias tmux-google='tmux -CC new-session -A -t Google'
alias ck8s-mandiant='ck8s -p abi-mcp-dev-01/abi-dev;ck8s -p madlegion/legion'
alias ck8s-google='ck8s -p aip-cf-dev/aip-cf-dev-01'
alias ewok-shuttle='/google/bin/releases/sma-eng-team/ewokshuttle/ewokshuttle'
alias ewokshuttle='/google/bin/releases/sma-eng-team/ewokshuttle/ewokshuttle'
alias podman-login-gcp='gcloud auth configure-docker us-docker.pkg.dev'
alias podman-auth-ecr='aws ecr get-login-password --region us-west-2 | podman login --username AWS --password-stdin $(aws ecr describe-repositories | jq -r ".repositories[0].repositoryUri" | cut -d/ -f1)'
# If you source this file directly, apply the overwrites.
if [ -z "$(echo "$(script_origin)" | grep -F "shrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi
