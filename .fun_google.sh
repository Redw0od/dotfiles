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
	case "${cluster,,}" in
		legion|apse2)
			echo "respond proxy"
			proxy-set 10100;;
		*)
			echo "rampart proxy"
			proxy-set 10101;;
	esac
}


alias proxy-check="goog-proxy"
alias respond5h="export PROXY=respond5h;proxy-set 10101 socks5h"
alias respond="export PROXY=respond;proxy-set 10101"
alias rampart5h="export PROXY=rampart5h;proxy-set 10101 socks5h"
alias rampart="export PROXY=rampart;proxy-set 10100"
alias noproxy='unset https_proxy HTTPS_PROXY HTTP_PROXY http_proxy PROXY'

# If you source this file directly, apply the overwrites.
if [ -z "$(echo "$(script_origin)" | grep -F "shrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi
