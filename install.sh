#!/usr/bin/env bash
UNINSTALL="${1}"
if [ -d "${HOME}/backup/dotfiles" ] && [ -z ${UNINSTALL} ]; then
	mv "${HOME}/backup/dotfiles" "${HOME}/backup/dotfiles$(date +%s)"
fi
for script in $(/bin/ls -A . ); do
	case "${script}" in
		.git|.gitignore|LICENSE|README.md|install.sh)
			continue;;
		.fun_overwrites.sh|.secrets.sh)
			if [ ! -f "${HOME}/${script}" ] && [ -z ${UNINSTALL} ]; then
				cp  "${script}" "${HOME}/${script}" 
			fi
			if [ -n ${UNINSTALL} ]; then
				rm -i "${HOME}/${script}" 
			fi
			continue;;
		.profile)
			if [ -f "${HOME}/.bash_profile" ]; then
				if [ -z ${UNINSTALL} ]; then
					mkdir -p "${HOME}/backup/dotfiles"
					mv "${HOME}/.bash_profile" "${HOME}/backup/dotfiles/${script}"
				else
					mv "${HOME}/backup/dotfiles/.bash_profile" "${HOME}" 
				fi
			fi
			;&
		*)
			if [ -f "${HOME}/${script}" ] && [ -z ${UNINSTALL} ]; then
				mkdir -p "${HOME}/backup/dotfiles"
				mv "${HOME}/${script}" "${HOME}/backup/dotfiles/${script}"
			fi

			if [ -z ${UNINSTALL} ]; then
				ln -fs "$(pwd)/${script}" "${HOME}"
			else
				if [ -L "${HOME}/${script}" ]; then
					rm -f "${HOME}/${script}"
				fi
				if [ -f "${HOME}/backup/dotfiles/${script}" ]; then
					mv "${HOME}/backup/dotfiles/${script}" "${HOME}/" 
					if [ $(/bin/ls -A "${HOME}/backup/dotfiles" | wc -l) -lt 1 ]; then 
						rmdir "${HOME}/backup/dotfiles"
					fi
				fi
			fi
			;;
	esac
done
chmod 700 ~/.secrets.sh

echo "dotfiles has been symlinked into your home directory."
echo "Backups have been made of any files that had conflicting names in ${HOME}/backup/dotfiles"
echo "If your shell doesn't use .profile or .bash_profile on load, you'll need to add .profile"
echo "as a source to your shell's load file."
echo "Modify any function by placing a copy in the .fun_overwrites.sh file.  This file is loaded last"
echo "and not automatically overwritten/deleted during install."
echo "Store your secrets in .secrets.sh"
echo "Run this script with any argument to uninstall.  e.g.  ./install.sh UNINSTALL"
