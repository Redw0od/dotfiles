
sh_source
_this="$( script_source )"
_sources+=("$(basename ${_this})")

UTILITIES+=("openssl" "tar" "bunzip" "rar" "unzip" "7z" "uncompress" "gunzip" "wget" "strace")

# Returns Argument Name if not found in shell paths
shell_utility_status() {
	local utility="${1}"
	if [ -z "$(which ${utility})" ]; then
		echo "${utility}"
	fi
}

# Report which utilities in an Array are not found in shell paths
shell_utilities() {
    local programs=("$@")
	local unique=($(array_unique "${programs[@]}"))
	for program in "${unique[@]}"; do
		if [ -n "$(shell_utility_status ${program})" ]; then
			echo "$program"
		fi
	done
}

shell_utility_check() {
	local utility="${1}"
	if [ -n "$(shell_utility_status ${utility})" ]; then 
		echo "Missing command line utility: ${utility}"
	fi
}
	   
			  
array_unique() {
	local u_array=("$@")
	declare -a s_array
	for element in "${u_array[@]}"; do
		if [ ! "$(printf '%s\n' "${s_array[@]}" | grep -F -x ${element} )" ]; then
			s_array+=("${element}")
		fi
	done
	printf '%s\n' "${s_array[@]}"
}

# Curl with bearer token
# curl_bearer [url] [token]
curl_bearer() {
  local cURL="${1}"
  local cToken="${2}"
  if [ -z ${cURL} ]; then echo "need URL"; return;fi
  local H1="'Content-Type: application/json'"
  local H2="Authorization: Bearer ${cToken}"
  curl -sk ${cURL} -H ${H1} -H "${H2}"
}

pause() {
	read -s -n 1 -p "Press any key to continue . . ."
	echo ""
}


cmd() {
    local command="${1}"
    local wet="${2:-$DRY}"
    echos "${color[info]}${command}${color[default]}"
    if [ ! "${wet}" = true ]; then
        eval $command; fi
    LAST_STATUS=$?
    if [ ! "${LAST_STATUS}" = "0" ]; then
      echos "ERROR: $LAST_STATUS"; fi
}

echos() {
    local message="${1}"
    local escapes="${2}"
	if [ ! "${QUIET}" = true ]; then
		if [ -z ${escapes+x} ]; then 
			echo "$message"
		else 
			echo -e "$message"
		fi
	fi
}

grep1() {
	local text="${1}"
	local field="\$${2:-1}"
	grep "${text}" | awk '{print $1}'
}

jq_diff() {
	local json_1="${1}"
	local json_2="${2}"
	diff \
  <(echo "${json_1}" | jq -S 'def post_recurse(f): def r: (f | select(. != null) | r), .; r; def post_recurse: post_recurse(.[]?); (. | (post_recurse | arrays) |= sort)' ) \
  <(echo "${json_2}" | jq -S 'def post_recurse(f): def r: (f | select(. != null) | r), .; r; def post_recurse: post_recurse(.[]?); (. | (post_recurse | arrays) |= sort)' )
}

quick_test() {
	local test_condition="${1}"
	#eval $(eval_test () { if [ "${test_condition}" ]; then echo "TRUE"; else echo "FALSE"; fi })
	#eval_test
	#unset eval_test
	if [ ${test_condition} ]; then echo "TRUE"; else echo "FALSE"; fi 
}

# Generate randmon 32char string, takes length as argument
randpw() {
  local len=${1:-32}
  openssl rand -base64 $(( ${len} * 2 )) | tr -dc A-Za-z0-9 | head -c${len}
}

# Print Text with ASCII banner, takes width as second argument
banner() {
  local width=${2:-80}
  local _c1=${3:-${color[banner]}}
  local _c2=${4:-${color[bannertext]}}
  local margin=$(( ($width-${#1})/2 ))
  local left="";right=""
  for ((i = 0 ; i < $margin ; i++)); do
    left="${left}<"
    right="${right}>"
  done
  echo -e "${_c1}${left}${_c2}${1}${_c1}${right}${color[default]}"
}

# Extracts any archive(s) (if unp isn't installed)
extract() {
	local archive="$(resolve_relative_path ${1})"
	local output=${2}
	pushd ${output} > /dev/null
	if [ -f $archive ] ; then
		case $archive in
			*.tar.bz2)	shell_utility_check "tar"; 		tar xjf $archive    ;;
			*.tar.gz)	shell_utility_check "tar"; 		tar xzf $archive    ;;
			*.bz2)		shell_utility_check "bunzip2"; 	bunzip2 $archive     ;;
			*.rar)		shell_utility_check "rar"; 		rar x $archive       ;;
			*.gz)		shell_utility_check "gunzip"; 	gunzip $archive      ;;
			*.tar)		shell_utility_check "tar"; 		tar xf $archive     ;;
			*.tbz2)		shell_utility_check "tar"; 		tar xjf $archive    ;;
			*.tgz)		shell_utility_check "tar"; 		tar xzf $archive    ;;
			*.zip)		shell_utility_check "unzip"; 	unzip -q $archive    ;;
			*.Z)		shell_utility_check "uncompress"; uncompress $archive  ;;
			*.7z)		shell_utility_check "7z"; 		7z x $archive        ;;
			*)          echo "don't know how to extract '$archive'..." ;;
		esac
	else
		echo "'$archive' is not a valid file!"
	fi
	popd > /dev/null
}

resolve_relative_path() (
    # If the path is a directory, we just need to 'cd' into it and print the new path.
    if [ -d "$1" ]; then
        cd "$1" || return 1
        pwd
    # If the path points to anything else, like a file or FIFO
    elif [ -e "$1" ]; then
        # Strip '/file' from '/dir/file'
        # We only change the directory if the name doesn't match for the cases where
        # we were passed something like 'file' without './'
        if [ ! "${1%/*}" = "$1" ]; then
            cd "${1%/*}" || return 1
        fi
        # Strip all leading slashes upto the filename
        echo "$(pwd)/${1##*/}"
    else
        return 1 # Failure, neither file nor directory exists.
    fi
)

# Searches for text in all files in the current folder
ftext() {
	# -i case-insensitive
	# -I ignore binary files
	# -H causes filename to be printed
	# -r recursive search
	# -n causes line number to be printed
	# optional: -F treat search term as a literal, not a regular expression
	# optional: -l only print filenames and not the matching lines ex. grep -irl "$1" *
	grep -iIHrn --color=always "$1" . | less -r
}

# Copy file with a progress bar
cpp() {
	set -e
	strace -q -ewrite cp -- "${1}" "${2}" 2>&1 \
	| awk '{
	count += $NF
	if (count % 10 == 0) {
		percent = count / total_size * 100
		printf "%3d%% [", percent
		for (i=0;i<=percent;i++)
			printf "="
			printf ">"
			for (i=percent;i<100;i++)
				printf " "
				printf "]\r"
			}
		}
	END { print "" }' total_size=$(stat -c '%s' "${1}") count=0
}

# Copy and go to the directory
cpg() {
	if [ -d "$2" ];then
		cp $1 $2 && cd $2
	else
		cp $1 $2
	fi
}

# Move and go to the directory
mvg() {
	if [ -d "$2" ];then
		mv $1 $2 && cd $2
	else
		mv $1 $2
	fi
}

# Create and go to the directory
mkdirg() {
	mkdir -p $1
	cd $1
}

# Goes up a specified number of directories  (i.e. up 4)
up() {
	local d=""
	limit=$1
	for ((i=1 ; i <= limit ; i++))
		do
			d=$d/..
		done
	d=$(echo $d | sed 's/^\///')
	if [ -z "$d" ]; then
		d=..
	fi
	cd $d
}

# Returns the last 2 fields of the working directory
pwdtail() {
	pwd|awk -F/ '{nlast = NF -1;print $nlast"/"$NF}'
}

# Show the current distribution
distribution() {
	local dtype
	# Assume unknown
	dtype="unknown"

	# First check for Macos
	if [ "$(uname -s)" = "Darwin" ]; then
		dtype="darwin"

	# First test against Fedora / RHEL / CentOS / generic Redhat derivative
	elif [ -r /etc/rc.d/init.d/functions ]; then
		source /etc/rc.d/init.d/functions
		[ zz`type -t passed 2>/dev/null` = "zzfunction" ] && dtype="redhat"

	# Then test against SUSE (must be after Redhat,
	# I've seen rc.status on Ubuntu I think? TODO: Recheck that)
	elif [ -r /etc/rc.status ]; then
		source /etc/rc.status
		[ zz`type -t rc_reset 2>/dev/null` = "zzfunction" ] && dtype="suse"

	# Then test against Debian, Ubuntu and friends
	elif [ -r /lib/lsb/init-functions ]; then
		source /lib/lsb/init-functions
		[ zz`type -t log_begin_msg 2>/dev/null` = "zzfunction" ] && dtype="debian"

	# Then test against Gentoo
	elif [ -r /etc/init.d/functions.sh ]; then
		source /etc/init.d/functions.sh
		[ zz`type -t ebegin 2>/dev/null` = "zzfunction" ] && dtype="gentoo"

	# For Mandriva we currently just test if /etc/mandriva-release exists
	# and isn't empty (TODO: Find a better way :)
	elif [ -s /etc/mandriva-release ]; then
		dtype="mandriva"

	# For Slackware we currently just test if /etc/slackware-version exists
	elif [ -s /etc/slackware-version ]; then
		dtype="slackware"

	fi
	echo "${dtype}"
}

# Show the current version of the operating system
ver() {
	local dtype
	dtype=$(distribution)

	case ${dtype} in
		"darwin")
			uname -v ;;
		"redhat")
			if [ -s /etc/redhat-release ]; then
				cat /etc/redhat-release && uname -a
			else
				cat /etc/issue && uname -a
			fi
			;;
		"suse")
			cat /etc/SuSE-release ;;
		"debian")
			lsb_release -a ;;
		"gentoo")
			cat /etc/gentoo-release ;;
		"mandriva")
			cat /etc/mandriva-release ;;
		"slackware")
			cat /etc/slackware-version ;;
		*)
			if [ -s /etc/issue ]; then
				cat /etc/issue
			else
				echo "Error: Unknown distribution"
				return 1
			fi
			;;
	esac
}

# Automatically install the needed support files for this .bashrc file
install_bashrc_support() {
	local dtype
	dtype=$(distribution)

	case ${dtype} in
		"redhat")
			sudo yum install multitail tree 
			;;
		"suse")
			sudo zypper install multitail
			sudo zypper install tree
			;;
		"debian")
			sudo apt-get install multitail tree net-tools
			;;
		"gentoo")
			sudo emerge multitail
			sudo emerge tree
			;;
		"mandriva")
			sudo urpmi multitail
			sudo urpmi tree
			;;
		"slackware")
			echo "No install support for Slackware"
			;;
		*)
			echo "Error: Unknown distribution"
			return 1
			;;
	esac
}

# Show current network information
netinfo() {
	local dtype=$(distribution)
	local fmt="%-7s%s"
	banner "Network Information"
	case ${dtype} in
		"debian")
			for inf in $(ip addr show up | grep ' mtu ' | awk '{print substr($2, 1, length($2)-1)}'); do
				local details="$(ip addr show ${inf})"
				echo "${details}" | awk -v INF="${inf}" /'inet / {printf "%-7s%-20s%-20s\n", INF, $2, $4}'
				echo "${details}" | awk -v INF="${inf}" /'inet6/ {printf "%-7s%s\n", INF, $2}'
			done
			;;
		*)
			echo "$(/sbin/ifconfig | awk /'inet addr/ {print $2}')"
			echo "$(/sbin/ifconfig | awk /'Bcast/ {print $3}')"
			echo "$(/sbin/ifconfig | awk /'inet addr/ {print $4}')"
			echo "$(/sbin/ifconfig | awk /'HWaddr/ {print $4,$5}')"
			;;
	esac
	banner
}

# IP address lookup
alias whatismyip="whatsmyip"
whatsmyip() {
	# External IP Lookup
	echo "External IP: $(wget http://checkip.dyndns.org -O - -q | grep -Eo '([0-9]{1,3}[\.]){3}[0-9]{1,3}')"
}

# For some reason, rot13 pops up everywhere
rot13() {
	if [ $# -eq 0 ]; then
		tr '[a-m][n-z][A-M][N-Z]' '[n-z][a-m][N-Z][A-M]'
	else
		echo $* | tr '[a-m][n-z][A-M][N-Z]' '[n-z][a-m][N-Z][A-M]'
	fi
}

# Trim leading and trailing spaces (for scripts)
trim() {
	local var=$@
	var="${var#"${var%%[![:space:]]*}"}"  # remove leading whitespace characters
	var="${var%"${var##*[![:space:]]}"}"  # remove trailing whitespace characters
	echo -n "$var"
}

path_append() {
	local new_path="${1}"
	if [[ -z "$(echo ${PATH} | sed 's/:/\n/g' | grep "^${new_path}$")" ]]; then
		export PATH="${PATH+$PATH:}${new_path}"
	fi
}

path_prepend() {
	local new_path="${1}"
	if [[ -z "$(echo ${PATH} | sed 's/:/\n/g' | grep "^${new_path}$")" ]]; then
		export PATH="${new_path}${PATH+:$PATH}"
	fi
}

path_reset() {
	local new_path=""
	if [[ -f /etc/paths ]]; then
		while read -r; do
			new_path="${new_path:+$new_path:}${REPLY}"
		done < /etc/paths
	else
		new_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
	fi
	export PATH="${new_path}"
}

version_test() {
	local test_version="${1}"
	local condition="${2}"
	local condition_version="${3}"
	local sorted="$(echo -e "${test_version}\n${condition_version}" | sort -V | head -n 1 | grep ${test_version})"
	local equals=$(if [ "${test_version}" = "${condition_version}" ]; then echo "${test_version}"; fi )
	case "${condition}" in
		eq) if [ -n "${equals}" ]; then return 0;  fi;;
		gt) if [ -z "${sorted}"  ] && [ -z "${equals}" ]; then return 0; fi;;
		lt) if [ -n "${sorted}"  ] && [ -z "${equals}" ]; then return 0; fi;;
		ge) if [ -z "${sorted}"  ] || [ -n "${equals}" ]; then return 0; fi;;
		le) if [ -n "${sorted}"  ] || [ -n "${equals}" ]; then return 0; fi;;
	esac
	return 1
}

# Make directory stack manipulations quiet
pushd() {
	if [ -n "$(echo $@ | grep -w '\-q')" ]; then command pushd "$@" > /dev/null;
	else command pushd "$@"; fi
}

popd() {
	if [ -n "$(echo $@ | grep -w '\-q')" ]; then command popd "$@" > /dev/null;
	else command popd "$@"; fi
}

# Show all currently defined arrays in your shell
array_list() {
	declare -a | cut -d "=" -f 1 | cut -d ' ' -f 3
}

# Show all currently defined associative arrays in your shell
array_map_list() {
	declare -A | cut -d "=" -f 1 | cut -d ' ' -f 3
}

# Display all values stored in an array
array_dump() {
	unset -n array_name array_values
	local array_name=${1}
	local type="$(declare -p ${array_name} | cut -d ' ' -f 2)"
	if [ -n "$(echo ${type} | grep a )" ]; then
		eval "declare -a array_values=(\${${array_name}[@]})"
		printf "%s\n" "${array_values[@]}"
	else
		eval "declare -n array_values=${array_name}"

		for key in $(printf '%s\n' ${!array_values[@]} | sort ); do
			printf "%s %s\n" "${array_name}[${key}]" "${array_values[${key}]}"
		done | column -t
	fi
}

# If you source this file directly, apply the overwrites.
if [ -z "$(echo "$(script_origin)" | grep -F "shrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi

jobs_pause () {
	local job_list=$(jobs | grep -v Done | wc -l | awk '{print $1}')
	sleep 5s
	while [ -n "${job_list}" ] && [ ${job_list} != 0 ]; do
		sleep 1s
		job_list=$(jobs | grep -v Done | wc -l | awk '{print $1}')
		echo "${job_list} jobs remaining."
	done
}