THIS="$( basename ${BASH_SOURCE[0]} )"
SOURCE[$THIS]="${THIS%/*}"
echo "RUNNING ${THIS}"

UTILITIES+=("tput" "printf")

set-color () {
  if [ -z "$(which tput)" ]; then 
    echo "\e[38;5;${1}m"
  else 
    tput setaf ${1}
  fi
}

set-bg-color () {
  if [ -z "$(which tput)" ]; then 
    echo "\e[38;5;${1}m"
  else 
    tput setab ${1}
  fi
}

color-map () {
    for color in {0..255} ; do # Colors
        # Display the color
		tput setab ${color}
        printf "  %3s  " ${color}
        printf "\e[48;5;%sm  %3s   " ${color} ${color}
		echo -n "${NORMAL}"
        # Display 6 colors per lines
        if [ $(((${color} + 1) % 6)) == 4 ] ; then
            echo # New line
        fi
    done
    echo # New line
}

export BLACK=$(set-color 0)
export RED=$(set-color 1)
export DARKGREEN=$(set-color 2)
export MUSTARD=$(set-color 3)
export DARKBLUE=$(set-color 4)
export PURPLE=$(set-color 5)
export TEAL=$(set-color 6)
export LIGHTGRAY=$(set-color 7)
export GRAY=$(set-color 8)
export ORANGE=$(set-color 9)
export GREEN=$(set-color 10)
export YELLOW=$(set-color 11)
export BLUE=$(set-color 12)
export BURGANDY=$(set-color 13)
export CYAN=$(set-color 14)
export WHITE=$(set-color 15)
export LIGHTRED=$(set-color 205)
export DARKGRAY=$(set-color 240)
export LIGHTGREEN=$(set-color 154)
export BROWN=$(set-color 88)
export LIGHTBLUE=$(set-color 45)
export MAGENTA=$(set-color 198)
export LIGHTMAGENTA=$(set-color 200)
export LIGHTCYAN=$(set-color 87)
export LIME_YELLOW=$(set-color 190)
export POWDER_BLUE=$(set-color 153)


case ${TERM} in
  "xterm-256color")
    export YELLOW_BG=$(tput setab 3)
    export BRIGHT=$(tput bold)
    export NORMAL=$(tput sgr0)
    export BLINK=$(tput blink)
    export REVERSE=$(tput smso)
    export UNDERLINE=$(tput smul)
    ;;
  *)	
	  export NORMAL="\033[0m"
  ;;
esac
export NOCOLOR=$NORMAL

# If you source this file directly, apply the overwrites.
if [ -z "$(echo "${BASH_SOURCE[*]}" | grep -F "bashrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi