#!/usr/bin/env bash
declare -a _sources

sh_source () { 
	eval   'script_source () { echo "${BASH_SOURCE[1]}"; }
			script_origin () { echo "${BASH_SOURCE[*]}"; }' 
}

sh_source
_this="$( script_source )"
_sources+=("$(basename ${_this})")

declare -a UTILITIES
UTILITIES=("date" "tty" "basename" "eval" "sed" "awk" "mpstat"
"tail" "vim" "grep" )

#######################################################
# SOURCED ALIAS'S AND SCRIPTS
#######################################################

# Source global definitions
if [ -f /etc/bashrc ]; then
	source /etc/bashrc
fi

# Enable bash programmable completion features in interactive shells
if [ -f /usr/share/bash-completion/bash_completion ]; then
	source /usr/share/bash-completion/bash_completion
elif [ -f /etc/bash_completion ]; then
	source /etc/bash_completion
fi

if [ -f "${HOME}/.secrets.sh" ]; then
	source "${HOME}/.secrets.sh"
fi

if [ -f "${HOME}/.fun_common.sh" ]; then
	source "${HOME}/.fun_common.sh"
fi

# Load all .fun_ scripts in home directory
for script in $(/bin/ls -a ${HOME} | grep '^.fun_.*\.sh$' | grep -v 'overwrites\|common' ); do
	source "${HOME}/${script}"
done

if [ -f "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi

version-test "${BASH_VERSION%%(*}" gt '4.0.0'
if [ $? = 1 ]; then
	echo "[WARN] These scripts may not work correctly on versions of bash"
	echo "older than version 4. Your bash version: ${BASH_VERSION}"
fi

#######################################################
# EXPORTS
#######################################################


export GITHOME="${HOME}/git"
export GPG_TTY=$(tty)
export SSH_PROFILE=""
export NPM_TOKEN=${SECRET_NPM_TOKEN}
export GITLAB_TOKEN=${NPM_TOKEN}
export GITLAB_NPM_TOKEN=${NPM_TOKEN}
export KUBECONFIG="${HOME}/.kube/conubectl:${HOME}/.kube/config/kubecfg.yaml"
export GOPATH="$HOME/go"
export LAST_STATUS=0
export DEBUG_LOG="${HOME}/tmp/debug.log"
# export VERBOSE=true
# export DEBUG=true

# Expand the history size
export HISTFILESIZE=10000
export HISTSIZE=500

# Don't put duplicate lines in the history and do not add lines that start with a space
export HISTCONTROL=erasedups:ignoredups:ignorespace

# Check the window size after each command and, if necessary, update the values of LINES and COLUMNS
shopt -s checkwinsize

# Causes bash to append to history instead of overwriting it so if you start a new terminal, you have old session history
shopt -s histappend
PROMPT_COMMAND='history -a'

# Allow ctrl-S for history navigation (with ctrl-R)
stty -ixon

# Set the default editor
export EDITOR=vim
export VISUAL=vim

# To have colors for ls and all grep commands such as grep, egrep and zgrep
export COLOR_MODE="dark"
export CLICOLOR=1
export LS_COLORS='no=00:fi=00:di=01;38:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.avi=01;35:*.fli=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.ogg=01;35:*.mp3=01;35:*.wav=01;35:*.xml=00;31:'
if [ ${COLOR_MODE} = "dark" ]; then
	LS_COLORS="${LS_COLORS}:di=01;36:"
else
	LS_COLORS="${LS_COLORS}:di=01;34:"
fi
alias grep="grep --color=auto"

# Color for manpages in less makes manpages a little easier to read
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

if [ ! -d "$(basename "${DEBUG_LOG%/*}")" ]; then
	mkdir -p "${DEBUG_LOG%/*}"
fi
exec {funlog}>"${DEBUG_LOG}"
export funlog=${funlog}
if [ "${VERBOSE}" = "true" ]; then
	echo "Loaded shell files:" >&${funlog}
	echo "${_sources[@]}" >&${funlog}
fi

#######################################################
# Set the ultimate amazing command prompt
#######################################################

cpu_usage_update() {
	local idle="$(mpstat 1 1 | tail -n 1 | awk '{print $12}')"
	local idlef=${idle#*\.}
	# bash can't math with decimals or prefixed 0's.  ie. 08
	if [ "${idlef}" -lt 10 ]; then idlef=${idlef:1:1}; fi
	local usedf=$((100-${idlef}))
	# restore prefix zero for decimal calculations
	if [ "${usedf}" -lt 10 ]; then usedf="0${usedf}"; fi
	echo "cpu: $((100-${idle%\.*})).${usedf}" > ${HOME}/.prompt
}

cpu_usage() {
	grep 'cpu: ' ${HOME}/.prompt | awk '{print $2}'
}

__setprompt () {
	local LAST_COMMAND=$? # Must come first!
	(cpu_usage_update &)
	# Show error exit code if there is one
	if [ $LAST_COMMAND != 0 ]; then
		PS1="${color[ps1param]}(${color[ps1errorval]}ERROR${color[ps1param]})-(${color[ps1error]}Exit Code ${color[ps1errorval]}${LAST_COMMAND}${color[ps1param]})-(${color[ps1error]}"
		if [ $LAST_COMMAND == 1 ]; then
			PS1+="General error"
		elif [ $LAST_COMMAND == 2 ]; then
			PS1+="Missing keyword, command, or permission problem"
		elif [ $LAST_COMMAND == 126 ]; then
			PS1+="Permission problem or command is not an executable"
		elif [ $LAST_COMMAND == 127 ]; then
			PS1+="Command not found"
		elif [ $LAST_COMMAND == 128 ]; then
			PS1+="Invalid argument to exit"
		elif [ $LAST_COMMAND == 129 ]; then
			PS1+="Fatal error signal 1"
		elif [ $LAST_COMMAND == 130 ]; then
			PS1+="Script terminated by Control-C"
		elif [ $LAST_COMMAND == 131 ]; then
			PS1+="Fatal error signal 3"
		elif [ $LAST_COMMAND == 132 ]; then
			PS1+="Fatal error signal 4"
		elif [ $LAST_COMMAND == 133 ]; then
			PS1+="Fatal error signal 5"
		elif [ $LAST_COMMAND == 134 ]; then
			PS1+="Fatal error signal 6"
		elif [ $LAST_COMMAND == 135 ]; then
			PS1+="Fatal error signal 7"
		elif [ $LAST_COMMAND == 136 ]; then
			PS1+="Fatal error signal 8"
		elif [ $LAST_COMMAND == 137 ]; then
			PS1+="Fatal error signal 9"
		elif [ $LAST_COMMAND -gt 255 ]; then
			PS1+="Exit status out of range"
		else
			PS1+="Unknown error code"
		fi
		PS1+="${color[ps1param]})${color[default]}\n"
	else
		PS1=""
	fi

	# Date
	PS1+="${color[ps1param]}(${color[ps1day]}$(date +%a) ${color[ps1date]}$(date +%b-'%-d')" # Date
	PS1+=" ${color[ps1time]}$(date +'%-I':%M:%S%P)${color[ps1param]})${color[ps1dash]}-" # Time

	# CPU
	PS1+="${color[ps1param]}(${color[ps1cpu]}CPU ${color[ps1cpuval]}$(cpu_usage)%"

	# Jobs
	PS1+=" ${color[ps1job]}jobs${color[ps1param]}:${color[ps1jobval]}\j${color[ps1param]})${color[ps1dash]}-"

	# Vault
	PS1+="${color[ps1param]}(${color[ps1vault]}vault${color[ps1bracket]}[$(vault-ps1-color)${color[ps1bracket]}]${color[ps1param]})${color[ps1dash]}-"

	# AWS
	PS1+="${color[ps1param]}(${color[ps1aws]}aws${color[ps1bracket]}[$(aws-ps1-color)${color[ps1bracket]}]${color[ps1param]})${color[ps1dash]}-"

	# Kubernetes
	PS1+="${color[ps1param]}(${color[ps1kube]}kube${color[ps1bracket]}[$(kube-ps1-color)${color[ps1bracket]}]${color[ps1param]})${color[ps1dash]}-"

	# User and server
	local SSH_IP=$(echo $SSH_CLIENT | awk '{ print $1 }')
	local SSH2_IP=$(echo $SSH2_CLIENT | awk '{ print $1 }')
	if [ $SSH2_IP ] || [ $SSH_IP ] ; then
		PS1+="${color[ps1param]}(${color[ps1user]}\u@\h"
	else
		PS1+="${color[ps1param]}(${color[ps1user]}\u"
	fi

	# Current directory
	PS1+="${color[ps1param]}:${color[ps1dir]}\w${color[ps1param]})${color[ps1dash]}-${color[ps1param]}("

	PS1+="$(ssh-ps1-tunnels)${color[ps1param]}):"
	
	# Total size of files in current directory
	#PS1+="${color[ps1param]}(${color[ps1size]}$(\ls -lah | grep -m 1 total | sed 's/total //')${color[ps1param]}:"

	# Number of files
	#PS1+="${color[ps1files]}$(trim $(\ls -A -1 | wc -l ))${color[ps1param]})"

	# Skip to the next line
	PS1+="${color[default]}\n"

	if [ $EUID -ne 0 ]; then
		PS1+="\[${color[gray]}\]>\[${color[default]}\] " # Normal user
	else
		PS1+="\[${color[red]}\]>\[${color[default]}\] " # Root user
	fi

	# PS2 is used to continue a command using the \ character
	PS2="\[${color[ps1param]}\]>\[${color[default]}\] "

	# PS3 is used to enter a number choice in a script
	PS3='Please enter a number from above list: '

	# PS4 is used for tracing a script in debug mode
	PS4="${color[ps1param]}+${color[default]} "
}
PROMPT_COMMAND='__setprompt'
