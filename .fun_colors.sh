
sh_source
_this="$( script_source )"
_sources+=("$(basename ${_this})")

UTILITIES+=("tput" "printf")

declare -A color

set_color() {
  if [ -z "$(which tput)" ]; then 
    echo "\e[38;5;${1}m"
  else 
    tput setaf ${1}
  fi
}

set_bg_color() {
  if [ -z "$(which tput)" ]; then 
    echo "\e[38;5;${1}m"
  else 
    tput setab ${1}
  fi
}

color_map() {
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

color[black]=$(set_color 0)
color[red]=$(set_color 1)
color[darkgreen]=$(set_color 2)
color[mustard]=$(set_color 3)
color[darkblue]=$(set_color 4)
color[purple]=$(set_color 5)
color[teal]=$(set_color 6)
color[lightgray]=$(set_color 7)
color[gray]=$(set_color 8)
color[orange]=$(set_color 9)
color[green]=$(set_color 10)
color[yellow]=$(set_color 11)
color[blue]=$(set_color 12)
color[burgandy]=$(set_color 13)
color[cyan]=$(set_color 14)
color[white]=$(set_color 15)
color[lightred]=$(set_color 205)
color[darkgray]=$(set_color 240)
color[lightgreen]=$(set_color 154)
color[brown]=$(set_color 88)
color[lightblue]=$(set_color 45)
color[magenta]=$(set_color 198)
color[lightmagenta]=$(set_color 200)
color[lightcyan]=$(set_color 87)
color[lime_yellow]=$(set_color 190)
color[powder_blue]=$(set_color 153)

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
color[banner]=${color[gray]}
color[bannertext]=${color[lightgray]}
color[success]=${color[green]}
color[warn]=${color[mustard]}
color[info]=${color[teal]}
color[error]=${color[red]}
color[fail]=${color[red]}
color[important]=${color[mustard]}

export color

# If you source this file directly, apply the overwrites.
if [ -z "$(echo "$(script_origin)" | grep -F "shrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi