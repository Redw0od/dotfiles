# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022
# Check Shell and create custom source function based on shell type
unset _sources

if [ -f "${HOME}/.zshrc" ]; then
    source "${HOME}/.zshrc"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "${HOME}/bin" ]; then
    path-prepend "${HOME}/bin"
fi
if [ -n ${GOROOT} ] && [ -d "${GOROOT}/bin" ]; then
    path-prepend "${GOROOT}/bin"
fi
if [ -n ${GOPATH} ] && [ -d "${GOPATH}/bin" ]; then
    path-prepend "${GOPATH}/bin"
fi

if [ -n "$(command -v brew)" ]; then
    HOMEBREW_BIN="$(dirname $(command -v brew))"
else
  if [ "$(distribution)" = "darwin" ]; then
      HOMEBREW_BIN="/opt/homebrew/bin"
  elif [ -n "${CHROME_REMOTE_DESKTOP_SESSION}" ]; then
      HOMEBREW_BIN="${HOME}/.linuxbrew/bin"
  else
      HOMEBREW_BIN="/home/linuxbrew/.linuxbrew/bin"
  fi
fi

if [ -d "${HOMEBREW_BIN}" ]; then
    path-prepend "${HOMEBREW_BIN}"
fi
if [ -e "${HOMEBREW_BIN}/brew" ]; then
    eval "$(${HOMEBREW_BIN}/brew shellenv)"
    if [ -s "${HOMEBREW_PREFIX}/opt/nvm/nvm.sh" ]; then
        source "${HOMEBREW_PREFIX}/opt/nvm/nvm.sh"
    fi
    if [ -s "${HOMEBREW_PREFIX}/opt/nvm/etc/zsh_completion.d/nvm" ] ; then
        source "${HOMEBREW_PREFIX}/opt/nvm/etc/zsh_completion.d/nvm"
    fi
fi

echos "Shell scripts depend on many additional tools."
echos "This is a list of tools used in these functions that are missing on your system:"
common-utilities "${UTILITIES[@]}"
echo ""

if [ ! -f "${HOME}/tmp/version_check" ] && [ -z "$(find "${HOME}/tmp/version_check" -mmin -1440 -type f -print)"]; then
    touch "${HOME}/tmp/version_check"
    aws-check-binary
    kube-check-binary
    tg-check-binary
    vault-check-binary
fi

