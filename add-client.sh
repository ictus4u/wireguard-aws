#!/bin/bash

# We read from the input parameter the name of the client
if [ -z "$1" ]; then
    read -p "Enter VPN user name: " USERNAME
    if [ -z $USERNAME ]; then
      echo "[#]Empty VPN user name. Exit"
      exit 1;
    fi
  else USERNAME=$1
fi

if (which mutt > /dev/null 2>&1); then
  # We read from the input parameter the email of the client
  if [ -z "$2" ]; then
      read -p "Enter VPN user email: " USERMAIL
      if [ -z $USERMAIL ]; then
        echo "[#]Empty VPN user email. Email won't be sent."
      fi
    else USERMAIL=$2
  fi
fi

cd /etc/wireguard/

read DNS < ./dns.var
read ENDPOINT < ./endpoint.var
read VPN_SUBNET < ./vpn_subnet.var
PRESHARED_KEY="_preshared.key"
PRIV_KEY="_private.key"
PUB_KEY="_public.key"
ALLOWED_IP="0.0.0.0/0"

# Go to the wireguard directory and create a directory structure in which we will store client configuration files
mkdir -p ./clients
cd ./clients
mkdir ./$USERNAME
cd ./$USERNAME
umask 077

CLIENT_PRESHARED_KEY=$( wg genpsk )
CLIENT_PRIVKEY=$( wg genkey )
CLIENT_PUBLIC_KEY=$( echo $CLIENT_PRIVKEY | wg pubkey )

#echo $CLIENT_PRESHARED_KEY > ./"$USERNAME$PRESHARED_KEY"
#echo $CLIENT_PRIVKEY > ./"$USERNAME$PRIV_KEY"
#echo $CLIENT_PUBLIC_KEY > ./"$USERNAME$PUB_KEY"

read SERVER_PUBLIC_KEY < /etc/wireguard/server_public.key

# We get the following client IP address
read OCTET_IP < /etc/wireguard/last_used_ip.var
OCTET_IP=$(($OCTET_IP+1))
echo $OCTET_IP > /etc/wireguard/last_used_ip.var

CLIENT_IP="$VPN_SUBNET$OCTET_IP/32"

# Create a blank configuration file client
cat > /etc/wireguard/clients/$USERNAME/$USERNAME.conf << EOF
[Interface]
PrivateKey = $CLIENT_PRIVKEY
Address = $CLIENT_IP
DNS = $DNS


[Peer]
PublicKey = $SERVER_PUBLIC_KEY
PresharedKey = $CLIENT_PRESHARED_KEY
AllowedIPs = $ALLOWED_IP
Endpoint = $ENDPOINT
PersistentKeepalive=25
EOF

# Add new client data to the Wireguard configuration file
cat >> /etc/wireguard/wg0.conf << EOF

[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
PresharedKey = $CLIENT_PRESHARED_KEY
AllowedIPs = $CLIENT_IP
EOF

# Restart Wireguard
systemctl stop wg-quick@wg0
systemctl start wg-quick@wg0

# Show QR config to display
qrencode -t ansiutf8 < ./$USERNAME.conf

# Show config file
echo "# Display $USERNAME.conf"
cat ./$USERNAME.conf

# Save QR config to png file
qrencode -t png -o ./$USERNAME.png < ./$USERNAME.conf

if (which mutt > /dev/null 2>&1); then
  attachments=""
  if [ -f ./$USERNAME.conf ]; then
    attachments=" ./$USERNAME.conf"
  fi
  if [ -f ./$USERNAME.png ]; then
    attachments=" ./$USERNAME.png"
  fi

  if [ ! -z "$attachments" ]; then
    if [ ! -z $USERMAIL ]; then
      message=$(cat <<"EOT"
Hi there!

Your VPN configuration files are attached to this email.

You'll need to use Wireguard as a client application. You can download
a proper setup application for your system from the link below:

https://www.wireguard.com/install/

Please, use this config in only one device.

Best regards!
EOT
      )
      echo $message | mutt -s "Your VPN configuration" -a $attachments -- $USERMAIL
    fi
  fi
fi
