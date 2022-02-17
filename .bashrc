#!/usr/bin/env bash

declare -a _sources
sh_source
_this="$( script_source )"
_sources+=("$(basename ${_this})")


Time12a="\$(date +%H:%M)"
PathShort="\w";
declare -a UTILITIES
UTILITIES=("date" "basename" "expr" "date" "tty" "stty" "echo" "sed" "awk"
"tail" "head" "edit" "less" "vim" "ps" "ping" "netstat" "shutdown" "tree" "tar"
"openssl" "grep" )

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

if [ -f "${HOME}/.secrets.sh" ] ; then
	source "${HOME}/.secrets.sh"
fi

# Load all .fun_ scripts in home directory
for script in $(/bin/ls -a ${HOME} | grep '^.fun_.*\.sh$' | grep -v overwrites ); do
	source "${HOME}/${script}"
done

if [ -f "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi

echo "Loaded shell files:"
echo "${_sources[@]}"

if [ "$(version-test ${BASH_VERSION%%(*} lt '4.0.0' )" ]; then
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
export KUBECONFIG="${HOME}/.kube/conubectl:${HOME}/.kube/config/kubecfg.yaml"
export TG_ROOT="${HOME}/git/platform/terraform-modules"
export GOPATH="$HOME/go"
export IFS_BACKUP=$IFS


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


#iatest=$(expr index "$-" i)
# Disable the bell
#if (( $iatest > 0 )); then bind "set bell-style visible"; fi

# Ignore case on auto-completion
# Note: bind used instead of sticking these in .inputrc
#if (( $iatest > 0 )); then bind "set completion-ignore-case on"; fi

# Show auto-completion list automatically, without double tab
#if (( $iatest > 0 )); then bind "set show-all-if-ambiguous On"; fi

# Set the default editor
export EDITOR=vim
export VISUAL=vim

# To have colors for ls and all grep commands such as grep, egrep and zgrep
export CLICOLOR=1
export LS_COLORS='no=00:fi=00:di=01;34:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.avi=01;35:*.fli=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.ogg=01;35:*.mp3=01;35:*.wav=01;35:*.xml=00;31:'
alias grep="grep --color=auto"

# Color for manpages in less makes manpages a little easier to read
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'


#######################################################
# GENERAL ALIAS'S
#######################################################
# To temporarily bypass an alias, we preceed the command with a \
# EG: the ls command is aliased, but to use the normal ls command you would type \ls


#######################################################
# Set the ultimate amazing command prompt
#######################################################

#alias cpu="grep 'cpu ' /proc/stat | awk '{usage=(\$2+\$4)*100/(\$2+\$4+\$5)} END {print usage}' | awk '{printf(\"%.1f\n\", \$1)}'"
alias cpu='echo 10'
__setprompt () {
	local LAST_COMMAND=$? # Must come first!

	# Show error exit code if there is one
	if [ $LAST_COMMAND != 0 ]; then
		# PS1="\[${color[red]}\](\[${color[lightred]}\]ERROR\[${color[red]}\])-(\[${color[lightred]}\]Exit Code \[${color[white]}\]${LAST_COMMAND}\[${color[red]}\])-(\[${color[lightred]}\]"
		PS1="${color[darkgray]}(${color[lightred]}ERROR${color[darkgray]})-(${color[red]}Exit Code ${color[lightred]}${LAST_COMMAND}${color[darkgray]})-(${color[red]}"
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
		PS1+="${color[darkgray]})${color[default]}\n"
	else
		PS1=""
	fi

	# Date
	PS1+="${color[darkgray]}($(set-color 196)$(date +%a) $(set-color 208)$(date +%b-'%-d')" # Date
	PS1+=" $(set-color 220) $(date +'%-I':%M:%S%P)${color[darkgray]})-" # Time

	# CPU
	PS1+="($(set-color 112)CPU $(set-color 34)$(cpu)%"

	# Jobs
	PS1+="${color[darkgray]}:${color[green]}\j"

	# Network Connections (for a server - comment out for non-server)
	# PS1+="\[${color[darkgray]}\]:\[${color[green]}\]Net $(awk 'END {print NR}' /proc/net/tcp)"

	PS1+="${color[darkgray]})-"
	PS1+="($(set-color 24)vault${color[gray]}[$(vault-ps1-color)${color[gray]}]${color[darkgray]})-"

	PS1+="(${color[teal]}aws${color[gray]}[$(aws-ps1-color)${color[gray]}]${color[darkgray]})-"

	PS1+="(${color[blue]}kube${color[gray]}[$(kube-ps1-color)${color[gray]}]${color[darkgray]})-"

	#PS1+="$(git-ps1-color)"


	# User and server
	local SSH_IP=`echo $SSH_CLIENT | awk '{ print $1 }'`
	local SSH2_IP=`echo $SSH2_CLIENT | awk '{ print $1 }'`
	if [ $SSH2_IP ] || [ $SSH_IP ] ; then
		PS1+="(${color[darkblue]}\u@\h"
	else
		PS1+="(${color[darkblue]}\u"
	fi

	# Current directory
	PS1+="${color[darkgray]}:${color[blue]}\w${color[darkgray]})-"

	# Total size of files in current directory
	PS1+="(${color[burgandy]}$(\ls -lah | grep -m 1 total | sed 's/total //')${color[darkgray]}:"

	# Number of files
	PS1+="${color[purple]}$(trim $(\ls -A -1 | wc -l ))${color[darkgray]})"

	# Skip to the next line
	PS1+="${color[default]}\n"

	if [ $EUID -ne 0 ]; then
		PS1+="\[${color[gray]}\]>\[${color[default]}\] " # Normal user
	else
		PS1+="\[${color[red]}\]>\[${color[default]}\] " # Root user
	fi

	# PS2 is used to continue a command using the \ character
	PS2="\[${color[darkgray]}\]>\[${color[default]}\] "

	# PS3 is used to enter a number choice in a script
	PS3='Please enter a number from above list: '

	# PS4 is used for tracing a script in debug mode
	PS4="${color[darkgray]}+${color[default]} "
}
PROMPT_COMMAND='__setprompt'
