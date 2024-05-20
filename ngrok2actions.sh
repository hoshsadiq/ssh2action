#!/usr/bin/env bash

set -euxo pipefail

green=$'\033[32m'
red=$'\033[31m'
yellow=$'\033[1;33m'
reset=$'\033[0m'

INFO="[${green}INFO${reset}]"
WARN="[${yellow}WARN${reset}]"
ERROR="[${red}ERROR${reset}]"

CONTINUE_FILE="/tmp/continue"
SOCKET_FILE="$(mktemp -u -t "tmate-$(id -u).XXXXXXXX")"
LOG_FILE="$SOCKET_FILE.log"

if ! hash sudo 2> /dev/null && whoami | grep root; then
  sudo() {
    "$@"
  }
fi


install_tmate() {
    latest_tmate_version="$(curl --fail --show-error --silent --location "https://api.github.com/repos/tmate-io/tmate/releases/latest" | jq -r .tag_name)"
    if uname --kernel-name --machine | grep -qFxi "Linux x86_64"; then
        echo -e "${INFO} Install tmate ..."

        curl --fail --show-error --silent --location "https://github.com/tmate-io/tmate/releases/download/${latest_tmate_version}/tmate-${latest_tmate_version}-static-linux-amd64.tar.xz" | \
          sudo tar --xz -xvf - -C /usr/local/bin --strip-components=1
    else
        echo -e "${ERROR} This system is not supported!"
        exit 1
    fi
    tmate -V
    echo -e "${INFO} tmate installed successfully..."
}

set_up_authorized_keys() {
    echo -e "${INFO} Setting up authorized_keys."
    mkdir -p "$HOME/.ssh"
    curl -fsSL "https://github.com/${GITHUB_ACTOR}.keys" > "$HOME/.ssh/authorized_keys"
    chmod -R go-rwx "$HOME/.ssh"
}

start_tmate() {
  echo -e "${INFO} Start tmate..."
  exec tmate -a "$HOME/.ssh/authorized_keys" -S "$SOCKET_FILE" -F >"$LOG_FILE" 2>&1 &
  TMATE_PID="$!"

  sleep 1
}

print_connection_info() {
  local key_fingerprints SSH_CMD
  SSH_CMD="$(awk '/^ssh session:/{print $4}' "$LOG_FILE")"
  key_fingerprints="$(ssh-keygen -l -f /dev/stdin < "$HOME/.ssh/authorized_keys" | sed -e "s/^/    /")"
  echo -e "$(cat <<EOF
------------------------------------------------------------------------
To connect to this session copy and paste the following into a terminal:

    ${green}ssh ${SSH_CMD}${reset}

${yellow}NOTE:${reset} you must authenticate using the private key of any SSH key set up
in your GitHub account. You can use the ${green}-i /path/to/private-key${reset} with ssh.

The following keys will have access (user ${green}${GITHUB_ACTOR}${reset}):

${green}
${key_fingerprints}
${reset}

${yellow}TIP:${reset} Run ${green}touch ${CONTINUE_FILE}${reset} to continue to the next step.
------------------------------------------------------------------------
EOF
)"
}

await_continue() {
  ERRORS_LOG=$(grep "command failed" "${LOG_FILE}" || true)
  if [[ -e "${LOG_FILE}" && -z "${ERRORS_LOG}" ]]; then
    while pgrep -x tmate >/dev/null && [[ ! -f "$CONTINUE_FILE" ]]; do
      sleep 1
    done

    echo -e "${WARN} Continue to the next step."
    kill "$TMATE_PID"
  else
    echo "${ERRORS_LOG}"
    exit 4
  fi
}


install_tmate
set_up_authorized_keys
start_tmate
print_connection_info
await_continue
