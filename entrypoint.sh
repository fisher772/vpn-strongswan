#!/bin/bash

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

PATH_IPSEC_DOCKER_SECRETS=/etc/ipsec.d/ipsec.docker/ipsec.docker.secrets
PATH_XL2TPD_CONF=/etc/xl2tpd/xl2tpd.conf
PATH_PPP_CONF=/etc/ppp/options.xl2tpd
PATH_IPSEC_CONF_REPLACE=/etc/ipsec.d/ipsec.docker/l2tp-ikev2.conf

INTERFACE=${IPTABLES_INTERFACE:+-i ${IPTABLES_INTERFACE}} # will be empty if not set
O_INTERFACE=${O_IPTABLES_INTERFACE:+-o ${O_IPTABLES_INTERFACE}} # will be empty if not set
ENDPOINTS=${IPTABLES_ENDPOINTS:+-s ${IPTABLES_ENDPOINTS}} # will be empty if not set

PATH_KEYS=/etc/ipsec.d
PATH_IPSEC=/etc/ipsec.d/ipsec.docker
PATH_CHAP_SECRETS=/etc/ppp/chap-secrets

if [[ ! -z "${TZ}" ]]; then
  cp /usr/share/zoneinfo/${TZ} /etc/localtime
  echo ${TZ} >/etc/timezone
fi

create_user() {
    echo "Cleaning credentials..."

    local eap_user_name=$(cat /dev/urandom | tr -dc 'a-zA-Z' | fold -w 8 | head -n 1)
    local eap_user_pw=$(openssl rand -base64 24)
    local psk_user_name=$(cat /dev/urandom | tr -dc 'a-zA-Z' | fold -w 8 | head -n 1)
    local psk_user_pw=$(openssl rand -base64 24)
    local psk_user_key=$(openssl rand -base64 48)

    cat >> "$PATH_IPSEC_DOCKER_SECRETS" <<EOF
$eap_user_name : EAP "$eap_user_pw"
EOF

    cat >> "$PATH_CHAP_SECRETS" <<EOF
$psk_user_name    l2tpd-psk     "$psk_user_pw"         *
EOF

    cat > "$PATH_IPSEC/users_creds/psk_${psk_user_name}.txt" <<EOF
user: $psk_user_name
password: $psk_user_pw
EOF
    chmod 0600 "$PATH_IPSEC/users_creds/psk_${psk_user_name}.txt"

    cat > "$PATH_IPSEC/users_creds/ikev_${eap_user_name}.txt" <<EOF
user: $eap_user_name
password: $eap_user_pw
EOF
    chmod 0600 "$PATH_IPSEC/users_creds/ikev_${eap_user_name}.txt"

exit 0
}

rewrite_creds() {
    echo "Rewriting credentials..."

    local eap_user_name=$(cat /dev/urandom | tr -dc 'a-zA-Z' | fold -w 8 | head -n 1)
    local eap_user_pw=$(openssl rand -base64 24)
    local psk_user_name=$(cat /dev/urandom | tr -dc 'a-zA-Z' | fold -w 8 | head -n 1)
    local psk_user_pw=$(openssl rand -base64 24)
    local psk_user_key=$(openssl rand -base64 48)

    rm -f "$PATH_IPSEC"/users_creds/* 2>/dev/null

    truncate -s 0 "$PATH_IPSEC_DOCKER_SECRETS" 2>/dev/null
    truncate -s 0 "$PATH_CHAP_SECRETS" 2>/dev/null

    cat >> "$PATH_IPSEC_DOCKER_SECRETS" <<EOF
# /etc/ipsec.d/ipsec.docker/ipsec.docker.secrets - strongSwan IPsec secrets file

%any %any : PSK "$psk_user_key"

: RSA "server-key.pem"

$eap_user_name : EAP "$eap_user_pw"
EOF
    chmod 0600 "$PATH_IPSEC_DOCKER_SECRETS"

    cat >> "$PATH_CHAP_SECRETS" <<EOF
# Secrets for authentication using CHAP

$psk_user_name    l2tpd-psk     "$psk_user_pw"         *
EOF
    chmod 0600 "$PATH_CHAP_SECRETS"

    cat > "$PATH_IPSEC/users_creds/psk_${psk_user_name}.txt" <<EOF
user: $psk_user_name
password: $psk_user_pw
EOF
    chmod 0600 "$PATH_IPSEC/users_creds/psk_${psk_user_name}.txt"

    cat > "$PATH_IPSEC/users_creds/ikev_${eap_user_name}.txt" <<EOF
user: $eap_user_name
password: $eap_user_pw
EOF
    chmod 0600 "$PATH_IPSEC/users_creds/ikev_${eap_user_name}.txt"

if [[ "$LE_CERT_STATUS" == "true" ]]; then
    sed -i 's|: RSA "server-key.pem"|: ECDSA "le-key.pem"|g' "$PATH_IPSEC_DOCKER_SECRETS" 2>/dev/null
else
    :
fi

exit 0
}

case "$1" in
  --clean_creds)
    rewrite_creds
    ;;
  --adduser)
    create_user
    ;;
  *)
    :
esac

# add iptables rules if IPTABLES=true
if [[ x${IPTABLES} == 'xtrue' ]]; then
  iptables -A INPUT ${ENDPOINTS} ${INTERFACE} -p udp -m udp --sport 500 --dport 500 -m policy --pol ipsec --dir out -j ACCEPT
  iptables -A INPUT ${ENDPOINTS} ${INTERFACE} -p udp -m udp --sport 4500 --dport 4500 -m policy --pol ipsec --dir out -j ACCEPT
  iptables -A INPUT ${ENDPOINTS} ${INTERFACE} -p udp -m udp --sport 1701 --dport 1701 -m policy --pol ipsec --dir out -j ACCEPT
  iptables -I INPUT ${ENDPOINTS} ${INTERFACE} -p udp --dport 500 --sport 500 -m policy --dir in --pol none -j DROP
  iptables -I INPUT ${ENDPOINTS} ${INTERFACE} -p udp --dport 4500 --sport 4500 -m policy --dir in --pol none -j DROP
  iptables -I INPUT ${ENDPOINTS} ${INTERFACE} -p udp --dport 1701 --sport 1701 -m policy --dir in --pol none -j DROP
  iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  iptables -A FORWARD -i ppp+ ${O_INTERFACE} -j ACCEPT
  iptables -A FORWARD -i ppp+ -o ppp+ -j ACCEPT
  iptables -A FORWARD ${INTERFACE} -o ppp+ -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  iptables -t filter -A FORWARD --match policy --pol ipsec --dir in --proto esp ${ENDPOINTS} -j ACCEPT
  if [[ ! -z ${SNAT_IP} ]]; then
    iptables -t nat -A POSTROUTING ${ENDPOINTS} ${O_INTERFACE} -j SNAT --to-source ${SNAT_IP}
  else
    iptables -t nat -A POSTROUTING ${ENDPOINTS} ${O_INTERFACE} -j MASQUERADE
    iptables -t nat -I POSTROUTING ${ENDPOINTS} -m policy --dir out --pol ipsec -j ACCEPT
  fi
fi

revipt() {
if [[ x${IPTABLES} == 'xtrue' ]]; then
  iptables -D INPUT ${ENDPOINTS} ${INTERFACE} -p udp -m udp --sport 500 --dport 500 -m policy --pol ipsec --dir out -j ACCEPT
  iptables -D INPUT ${ENDPOINTS} ${INTERFACE} -p udp -m udp --sport 4500 --dport 4500 -m policy --pol ipsec --dir out -j ACCEPT
  iptables -D INPUT ${ENDPOINTS} ${INTERFACE} -p udp -m udp --sport 1701 --dport 1701 -m policy --pol ipsec --dir out -j ACCEPT
  iptables -D INPUT ${ENDPOINTS} ${INTERFACE} -p udp --dport 500 --sport 500 -m policy --dir in --pol none -j DROP
  iptables -D INPUT ${ENDPOINTS} ${INTERFACE} -p udp --dport 4500 --sport 4500 -m policy --dir in --pol none -j DROP
  iptables -D INPUT ${ENDPOINTS} ${INTERFACE} -p udp --dport 1701 --sport 1701 -m policy --dir in --pol none -j DROP
  iptables -D INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  iptables -D FORWARD -i ppp+ ${O_INTERFACE} -j ACCEPT
  iptables -D FORWARD -i ppp+ -o ppp+ -j ACCEPT
  iptables -D FORWARD ${INTERFACE} -o ppp+ -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  iptables -t filter -D FORWARD --match policy --pol ipsec --dir in --proto esp ${ENDPOINTS} -j ACCEPT
  if [[ ! -z ${SNAT_IP} ]]; then
    iptables -t nat -D POSTROUTING ${ENDPOINTS} ${O_INTERFACE} -j SNAT --to-source ${SNAT_IP}
  else
    iptables -t nat -D POSTROUTING ${ENDPOINTS} ${O_INTERFACE} -j MASQUERADE
    iptables -t nat -D POSTROUTING ${ENDPOINTS} -m policy --dir out --pol ipsec -j ACCEPT
  fi
fi
}

# enable ip forward
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.ip_no_pmtu_disc=1
sysctl -w net.ipv4.conf.all.accept_redirects=0
sysctl -w net.ipv4.conf.all.send_redirects=0
sysctl -w net.ipv4.conf.all.rp_filter=0
sysctl -w net.ipv4.conf.default.accept_redirects=0
sysctl -w net.ipv4.conf.default.send_redirects=0
sysctl -w net.ipv4.conf.default.rp_filter=0
sysctl -w net.ipv4.conf.eth0.send_redirects=0
sysctl -w net.ipv4.conf.eth0.rp_filter=0

sed -i "s/\${VPN_ROUTE_RANGE}/$VPN_ROUTE_RANGE/g" "$PATH_IPSEC_CONF_REPLACE" 2>/dev/null
sed -i "s/\${VPN_DOMAIN}/$VPN_DOMAIN/g" "$PATH_IPSEC_CONF_REPLACE" 2>/dev/null
sed -i "s/\${IPSEC_RDNS}/$IPSEC_RDNS/g" "$PATH_IPSEC_CONF_REPLACE" 2>/dev/null

sed -i "s/\${XL2TPD_IPRANGE}/$XL2TPD_IPRANGE/g" "$PATH_XL2TPD_CONF" 2>/dev/null
sed -i "s/\${XL2TPD_IPLOCAL}/$XL2TPD_IPLOCAL/g" "$PATH_XL2TPD_CONF" 2>/dev/null
sed -i "s/\${XL2TPD_DNS1}/$XL2TPD_DNS1/g" "$PATH_PPP_CONF" 2>/dev/null
sed -i "s/\${XL2TPD_DNS2}/$XL2TPD_DNS2/g" "$PATH_PPP_CONF" 2>/dev/null

# replace *.conf
if [[ "$LE_CERT_STATUS" == "true" ]]; then
    sed -i 's|: RSA "server-key.pem"|: ECDSA "le-key.pem"|g' "$PATH_IPSEC_DOCKER_SECRETS" 2>/dev/null
else
    :
fi

if [[ "$LE_CERT_STATUS" == "true" ]]; then
    sed -i "s|leftcert=server-cert.pem|leftcert=le-crt.pem|g" "$PATH_IPSEC_CONF_REPLACE" 2>/dev/null
else
    :
fi

# function to use when this script recieves a SIGTERM.
term() {
  echo "Caught SIGTERM signal! Stopping ipsec..."
  ipsec stop
  # remove iptable rules
  revipt
}

# catch the SIGTERM
trap term SIGTERM

echo "Starting strongSwan/ipsec..."
ipsec start --nofork "$@" &

/usr/sbin/crond
/usr/sbin/rsyslogd
/usr/sbin/xl2tpd

# wait for child process to exit
wait $!

# remove iptable rules
revipt
