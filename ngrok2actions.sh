#!/usr/bin/env bash
#
# Copyright (c) 2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/ssh2actions
# File name：ngrok2actions.sh
# Description: Connect to Github Actions VM via SSH by using ngrok
# Version: 2.0
#

Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Green_background_prefix="\033[42;37m"
Red_background_prefix="\033[41;37m"
Font_color_suffix="\033[0m"
INFO="[${Green_font_prefix}INFO${Font_color_suffix}]"
ERROR="[${Red_font_prefix}ERROR${Font_color_suffix}]"
LOG_FILE='/tmp/ngrok.log'
CONTINUE_FILE="/tmp/continue"

if [[ -z "${NGROK_TOKEN}" ]]; then
    echo -e "${ERROR} Please set 'NGROK_TOKEN' environment variable."
    exit 2
fi

if [[ -n "$(uname | grep -i Linux)" ]]; then
    echo -e "${INFO} Install ngrok ..."

    curl -fsSL https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.tgz | sudo tar xvzf - -C /usr/local/bin
    ngrok -v
elif [[ -n "$(uname | grep -i Darwin)" ]]; then
    echo -e "${INFO} Install ngrok ..."
    curl -fsSL https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-darwin-amd64.zip -o /tmp/ngrok.zip
    sudo unzip /tmp/ngrok.zip -d /usr/local/bin
    ngrok -v
    USER=root
    echo -e "${INFO} Set SSH service ..."
    sudo launchctl unload /System/Library/LaunchDaemons/ssh.plist
    sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist
else
    echo -e "${ERROR} This system is not supported!"
    exit 1
fi

echo 'PermitRootLogin no' | sudo tee -a /etc/ssh/sshd_config >/dev/null
echo 'PasswordAuthentication no' | sudo tee -a /etc/ssh/sshd_config >/dev/null
echo 'PubkeyAuthentication yes' | sudo tee -a /etc/ssh/sshd_config >/dev/null

mkdir "$HOME/.ssh"
curl -fsSL "https://github.com/${GITHUB_ACTOR}.keys" > "$HOME/.ssh/authorized_keys"
chmod -R go-rwx "$HOME/.ssh"

echo -e "${INFO} Start ngrok proxy for SSH port..."
screen -dmS ngrok \
    ngrok tcp 22 \
    --log "${LOG_FILE}" \
    --authtoken "${NGROK_TOKEN}" \
    --region "${NGROK_REGION:-us}"

sleep 10

ERRORS_LOG=$(grep "command failed" ${LOG_FILE})

if [[ -e "${LOG_FILE}" && -z "${ERRORS_LOG}" ]]; then
    SSH_CMD="$(grep -oE "tcp://(.+)" ${LOG_FILE} | sed "s/tcp:\/\//ssh ${USER}@/" | sed "s/:/ -p /")"
    MSG="
*GitHub Actions - ngrok session info:*

⚡ *CLI:*
\`${SSH_CMD}\`

🔔 *TIPS:*
Run '\`touch ${CONTINUE_FILE}\`' to continue to the next step.
"
    while ((${PRT_COUNT:=1} <= ${PRT_TOTAL:=10})); do
        echo "------------------------------------------------------------------------"
        echo "To connect to this session copy and paste the following into a terminal:"
        echo -e "${Green_font_prefix}$SSH_CMD${Font_color_suffix}"
        echo -e "TIPS: Run 'touch ${CONTINUE_FILE}' to continue to the next step."
        echo "------------------------------------------------------------------------"
        
        echo -e "${INFO} (${PRT_COUNT}/${PRT_TOTAL}) Re-printing help in 10 seconds ..."
        sleep 10
        PRT_COUNT=$((${PRT_COUNT} + 1))
    done
else
    echo "${ERRORS_LOG}"
    exit 4
fi

while ps aux | grep -q '[n]grok' && [[ ! -f "$CONTINUE_FILE" ]]; do
    sleep 1
    if [[ -e $CONTINUE_FILE ]]; then
        echo -e "${INFO} Continue to the next step."
    fi
done

# ref: https://gist.github.com/retyui/7115bb6acf151351a143ec8f96a7c561
