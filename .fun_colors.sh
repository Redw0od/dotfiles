_this="$( basename ${BASH_SOURCE[0]} )"
_source[$_this]="${_this%/*}"

UTILITIES+=("tput" "printf")

declare -A color

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
    for colors in {0..255} ; do # Colors
        # Display the color
		tput setab ${colors}
        printf "  %3s  " ${colors}
        printf "\e[48;5;%sm  %3s   " ${colors} ${colors}
		echo -n "${color[default]}"
        # Display 6 colors per lines
        if [ $(((${colors} + 1) % 6)) == 4 ] ; then
            echo # New line
        fi
    done
    echo # New line
}

color[black]=$(set-color 0)
color[red]=$(set-color 1)
color[darkgreen]=$(set-color 2)
color[mustard]=$(set-color 3)
color[darkblue]=$(set-color 4)
color[purple]=$(set-color 5)
color[teal]=$(set-color 6)
color[lightgray]=$(set-color 7)
color[gray]=$(set-color 8)
color[orange]=$(set-color 9)
color[green]=$(set-color 10)
color[yellow]=$(set-color 11)
color[blue]=$(set-color 12)
color[burgandy]=$(set-color 13)
color[cyan]=$(set-color 14)
color[white]=$(set-color 15)
color[lightred]=$(set-color 205)
color[darkgray]=$(set-color 240)
color[lightgreen]=$(set-color 154)
color[brown]=$(set-color 88)
color[lightblue]=$(set-color 45)
color[magenta]=$(set-color 198)
color[lightmagenta]=$(set-color 200)
color[lightcyan]=$(set-color 87)
color[lime_yellow]=$(set-color 190)
color[powder_blue]=$(set-color 153)

case ${TERM} in
  "xterm-256color")
    color[yellow_bg]=$(tput setab 3)
    color[bright]=$(tput bold)
    color[default]=$(tput sgr0)
    color[blink]=$(tput blink)
    color[reverse]=$(tput smso)
    color[underline]=$(tput smul)
    ;;
  *)	
	  color[default]="\033[0m"
  ;;
esac

export color

# If you source this file directly, apply the overwrites.
if [ -z "$(echo "${BASH_SOURCE[*]}" | grep -F "bashrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi