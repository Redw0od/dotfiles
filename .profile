# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022
echo "RUNNING .profile"
# Check Shell and create custom source function based on shell type
unset _sources
if [ -n "${BASH_SOURCE}" ]; then
    sh_source () { 
        eval 'script_source () { echo "${BASH_SOURCE[1]}"; }
              script_origin () { echo "${BASH_SOURCE[*]}"; }' 
    }
    SHELL='bash'
    if [ -f "${HOME}/.bashrc" ]; then
        source "${HOME}/.bashrc"
    fi
elif [ -n "${(%):-%x}" ]; then
    sh_source () { 
        eval 'script_source () { echo "${(%):-%x}"; }
              script_origin () { echo ${funcfiletrace[*]%:*} }'
    }
    SHELL='zsh'
    if [ -f "${HOME}/.zshrc" ]; then
        source "${HOME}/.zshrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "${HOME}/bin" ] ; then
    PATH="${HOME}/bin:${PATH}"
fi
if [ -d "${GOROOT}/bin" ] ; then
    PATH="${GOROOT}/bin:${PATH}"
fi
if [ -d "${GOPATH}/bin" ] ; then
    PATH="${GOPATH}/bin:${PATH}"
fi

if [ "$(distribution)" = "darwin" ]; then
    HOMEBREW_BIN="/opt/homebrew/bin"
else
    HOMEBREW_BIN="/home/linuxbrew/.linuxbrew/bin"
fi
if [ -e "${HOMEBREW_BIN}/brew" ] ; then
    eval "$(${HOMEBREW_BIN}/brew shellenv)"
    if [ -s "${HOMEBREW_PREFIX}/opt/nvm/nvm.sh" ] ; then
        source "${HOMEBREW_PREFIX}/opt/nvm/nvm.sh"
    fi
    if [ -s "${HOMEBREW_PREFIX}/opt/nvm/etc/bash_completion.d/nvm" ] ; then
        source "${HOMEBREW_PREFIX}/opt/nvm/etc/bash_completion.d/nvm"
    fi
fi

#ssh-load-keys mandiant

echo "Shell scripts depend on many additional tools."
echo "This is a list of tools used in these functions that are missing on your system:"
shell-utilities "${UTILITIES[@]}"
echo ""

aws-check-binary
kube-check-binary
tg-check-binary
