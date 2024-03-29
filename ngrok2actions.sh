#!/usr/bin/env bash

set -euo pipefail

green="\033[32m"
red="\033[31m"
yellow="\033[1;33m"
reset="\033[0m"

INFO="[${green}INFO${reset}]"
WARN="[${yellow}WARN${reset}]"
ERROR="[${red}ERROR${reset}]"

CONTINUE_FILE="/tmp/continue"
SOCKET_FILE="$(mktemp -u -t "tmate-$(id -u).XXXXXXXX")"
LOG_FILE="$SOCKET_FILE.log"

latest_tmate_version="$(curl --fail --show-error --silent --location "https://api.github.com/repos/tmate-io/tmate/releases/latest" | jq -r .tag_name)"
if uname --kernel-name --machine | grep -qFxi "Linux x86_64"; then
    echo -e "${INFO} Install ngrok ..."

    curl --fail --show-error --silent --location "https://github.com/tmate-io/tmate/releases/download/${latest_tmate_version}/tmate-${latest_tmate_version}-static-linux-amd64.tar.xz" | \
      sudo tar --xz -xvf - -C /usr/local/bin --strip-components=1
else
    echo -e "${ERROR} This system is not supported!"
    exit 1
fi
tmate -V
echo -e "${INFO} tmate installed successfully..."

mkdir -p "$HOME/.ssh"
curl -fsSL "https://github.com/${GITHUB_ACTOR}.keys" > "$HOME/.ssh/authorized_keys"
chmod -R go-rwx "$HOME/.ssh"

echo -e "${INFO} Start tmate..."
exec tmate -a "$HOME/.ssh/authorized_keys" -S "$SOCKET_FILE" -F >"$LOG_FILE" 2>&1 &
TMATE_PID="$!"

sleep 1

ERRORS_LOG=$(grep "command failed" "${LOG_FILE}" || true)
if [[ -e "${LOG_FILE}" && -z "${ERRORS_LOG}" ]]; then
    SSH_CMD="$(awk '/^ssh session:/{print $4}' "$LOG_FILE")"
    PRT_COUNT=0
    while pgrep -x tmate >/dev/null && [[ ! -f "$CONTINUE_FILE" ]]; do
      if ((PRT_COUNT % 10 == 0)); then
        echo -e "$(cat <<EOF
------------------------------------------------------------------------
To connect to this session copy and paste the following into a terminal:

    ${green}ssh ${SSH_CMD}${reset}

${yellow}NOTE:${reset} you must authenticate using the private key of any SSH key set up
in your GitHub account. You can use the ${green}-i /path/to/private-key${reset} with ssh.

${yellow}TIP:${reset} Run ${green}touch ${CONTINUE_FILE}${reset} to continue to the next step.
------------------------------------------------------------------------
EOF
)"

        echo -e "${INFO} Re-printing help in 10 seconds ..."
      fi

      sleep 1
      ((PRT_COUNT = PRT_COUNT+1))
    done

    echo -e "${WARN} Continue to the next step."
    kill "$TMATE_PID"
else
    echo "${ERRORS_LOG}"
    exit 4
fi
