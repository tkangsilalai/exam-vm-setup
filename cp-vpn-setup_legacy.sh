#!/bin/bash

systemctl stop wg-quick@cp-vpn
rm /etc/wireguard/cp-vpn.conf

while [ true ]
do
	USER_INPUT=$(sudo -u dsde DISPLAY=:0 XAUTHORITY=/home/dsde/.Xauthority zenity --forms --separator=$'\n' --add-entry="Username" --add-password="Password" --title "Virtual Machine Setup" --text "Login")

	readarray -t USER_PASS <<<"$USER_INPUT"

	login_payload=$(printf '{"username":"%s","password":"%s"}' "${USER_PASS[0]}" "${USER_PASS[1]}")

	response=$(curl --fail-with-body -X POST https://cp-vpn.nattee.net/provision -H 'Content-Type: application/json' -d $login_payload)

	if [[ $? -ne 0 ]]
	then
		sudo -u dsde DISPLAY=:0 XAUTHORITY=/home/dsde/.Xauthority zenity --error --text $response
		continue
	else
		systemctl stop wg-quick@cp-vpn
		echo "$response" | jq -r '.wireguardConfig' > /etc/wireguard/cp-vpn.conf
		systemctl start wg-quick@cp-vpn
		sudo -u dsde DISPLAY=:0 XAUTHORITY=/home/dsde/.Xauthority zenity --info --text "Login Successful. Press OK to continue"
		break
	fi
done
