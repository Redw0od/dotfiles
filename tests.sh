#!/usr/bin/env bash
shopt -s expand_aliases
echo DIR=$(pwd)
TMP_DIR="/tmp/tests"
source "./.bashrc"
SSH_HOST="github.com"
cleanup () {
	cd ${DIR}
	rm -rf ${TMP_DIR} > /dev/null
	exit
}

trap "cleanup" SIGINT
trap "cleanup" EXIT

echos "echos () plain"
echos "${color[green]}echos () colored ${color[default]}; setting QUIET" +
QUIET="true"
echos "QUIET is ${QUIET}" 
echos "QUIET is ${QUIET}" +; echos ""
QUIET="false"
cmd "mkdir -p ${TMP_DIR}"; echos "\n" +
echos "setting QUIET, running version"
QUIET="true"
cmd "uname -a"; echos "\n\n" +
cmd "echo 'QUIET OVERRIDE'" +; echos "\n" +
QUIET="false"

cmd "pause"; echos ""

cmd "common-utility-status echo"; echos ""
cmd "common-utility-status FAILS"; echos ""
cmd "common-utilities \${UTILITIES[@]}"; echos ""
cmd "array-unique \${UTILITIES[@]}"; echos ""
cmd "curl-bearer ${KIBANA[LEGION]} ${APIKEYS[LEGION]}"; echos ""
cmd "randpw"; echos "\n" +
cmd "randpw 80"; echos "\n" +
cmd "banner ' BANNER TEXT '"; echos ""
cmd "resolve_relative_path ~/.profile"; echos ""
cmd "resolve_relative_path ./tests.sh"; echos ""
cmd "resolve_relative_path /home/mike/.profile"; echos ""
cmd "extract ../../../awscliv2.zip ${TMP_DIR}"; echos ""
cmd "extract ../../../awscliv2.7z ${TMP_DIR}"; echos ""
cmd "extract ~/helm-v2.14.0-linux-amd64.tar.gz ${TMP_DIR}"; echos ""
cmd "ftext bash"; echos ""
cmd "cpp ~/awscliv2.zip ${TMP_DIR}/awscliv2.zip"; echos ""
cmd "cpg ~/helm-v2.14.0-linux-amd64.tar.gz ${TMP_DIR}/"; echos ""
cmd "pwd"; echos ""
cmd "cd ${DIR}"
cmd "pwd"; echos ""
cmd "mvg ~/helm-v2.16.12-linux-amd64.tar.gz ${TMP_DIR}/"; echos ""
cmd "pwd"; echos ""
cmd "mvg ${TMP_DIR}/helm-v2.16.12-linux-amd64.tar.gz ~"; echos ""
cmd "pwd"; echos ""
cmd "mkdirg ${TMP_DIR}/go/deeper"; echos ""
cmd "pwd"; echos ""
cmd "pwdtail"; echos ""
cmd "up 2"; echos ""
cmd "pwd"; echos ""
cmd "distribution"; echos ""
cmd "ver"; echos ""
#cmd "install-bashrc-support"
cmd "netinfo"; echos ""
cmd "whatsmyip"; echos ""
cmd "rot13 $(rot13 'SHIFT ME')"; echos ""
cmd "trim '     5 leading spaces'"; echos ""
cmd "trim '5 trailing spaces     '"; echos ""
cmd "trim '     5 margin spaces     '"; echos ""
cmd "cpu"; echos ""
banner " Testing all Help Functions "
declare -F | grep help | awk '{print $3}' | while read helper; do 
	FUNCTIONS="$(eval ${helper} | tail -n +3)"
	echo "${FUNCTIONS[@]}" | \
		while read fun_name; do 
			echo ""
			eval ${helper} ${fun_name}
		done
done
cmd "ssh-unload-keys"; echos ""
echo "\n" +
banner " RUNNING git-update-main "
echo "This command runs the following functions:"
echo "git-latest-main git-call git-origin git-branch git-pull"
echo "ssh-git-account ssh-load-keys ssh-check-agent ssh-start-agent"
cmd "git-update-main"

cmd "ssh-ping ${SSH_HOST} 1 2"

echo "This command applys multiple profiles and runs these functions:"
echo "ssh-load-keys ssh-check-agent ssh-start-agent"
echo "aws-apply-profile aws-load aws-assume-role aws-save aws-extract-role-arn"
echo "kube-profile vault_profile"
cmd "mad-assume corp"; echos ""
PODS=$(kube-safe-apply -n shared get pods --no-headers | head -n 2 | awk '{print $1}')
kube-pods-top $(echo $PODS | awk '{print $2}') "shared"




cleanup