
sh_source
_this="$( script_source )"
_sources+=("$(basename ${_this})")

UTILITIES+=("tput" "printf")

declare -A color

set-color() {
  if [ -z "$(command -v tput)" ]; then 
    echo "\e[38;5;${1}m"
  else 
    tput setaf ${1}
  fi
}

set-bg-color() {
  if [ -z "$(command -v tput)" ]; then 
    echo "\e[38;5;${1}m"
  else 
    tput setab ${1}
  fi
}

color-map() {
  local background=${1:-true}
  for colors in {0..255} ; do # Colors
    # Display the color
    if [[ ${background} == "true" ]]; then
      tput setab ${colors}
      printf "  %3s  " ${colors}
      printf "\e[48;5;%sm  %3s   " ${colors} ${colors}
    else 
      tput setaf ${colors}
      printf "  %3s  " ${colors}
      printf "\e[38;05;%sm  %3s   " ${colors} ${colors}
    fi
		echo -n "${color[default]}"
        # Display 6 colors per lines
        if [ $(((${colors} + 1) % 6)) == 4 ] ; then
            echo # New line
        fi
    done
    echo # New line
}

color-values() {
  for name in "${!color[@]}" ; do 
    echo "${color[$name]}$name${color[default]}"
  done | sort 
  echo # New line
}
color[black]=$(set-color 0)
color[darkred]=$(set-color 124)
color[forest]=$(set-color 64)
color[bistre]=$(set-color 3)
color[mustard]=$(set-color 220)
color[duke]=$(set-color 25)
color[darkblue]=$(set-color 20)
color[darkmagenta]=$(set-color 5)
color[purple]=$(set-color 93)
color[teal]=$(set-color 6)
color[ashgray]=$(set-color 251)
color[lightgray]=$(set-color 7)
color[davysgray]=$(set-color 8)
color[gray]=$(set-color 8)
color[carmine]=$(set-color 9)
color[red]=$(set-color 9)
color[orange]=$(set-color 202)
color[green]=$(set-color 76)
color[citrine]=$(set-color 226)
color[yellow]=$(set-color 11)
color[blue]=$(set-color 12)
color[electricpurple]=$(set-color 13)
color[burgandy]=$(set-color 125)
color[cerulean]=$(set-color 81)
color[cyan]=$(set-color 14)
color[bone]=$(set-color 15)
color[darkgreen]=$(set-color 28)
color[white]=$(set-color 231)
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
if [[ "${COLOR_MODE}" == "dark" ]]; then
  color[orange]=$(set-color 202)
  color[blue]=$(set-color 33)
fi

case ${TERM} in
  "xterm-256color"|"xterm-kitty")
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
color[help_header]=${color[forest]}
color[help]=${color[green]}

color[ps1day]=${color[red]}
color[ps1date]=${color[red]}
color[ps1time]=${color[red]}
color[ps1param]=${color[darkgray]}
color[ps1dash]=${color[darkgray]}
color[ps1cpu]=${color[blue]}
color[ps1cpuval]=${color[yellow]}
color[ps1job]=${color[blue]}
color[ps1jobval]=${color[yellow]}
color[ps1vault]=${color[green]}
color[ps1bracket]=${color[gray]}
color[ps1aws]=${color[green]}
color[ps1awsval]=${color[red]}
color[ps1kube]=${color[green]}
color[ps1kubeval]=${color[red]}
color[ps1user]=${color[blue]}
color[ps1dir]=${color[blue]}
color[ps1files]=${color[yellow]}
color[ps1size]=${color[yellow]}
color[ps1error]=${color[red]}
color[ps1errorval]=${color[lightred]}

export color

# If you source this file directly, apply the overwrites.
if [ -z "$(echo "$(script_origin)" | grep -F "shrc" )" ] && [ -e "${HOME}/.fun_overwrites.sh" ]; then
	source "${HOME}/.fun_overwrites.sh"
fi