#!/bin/sh

# A modified version of
# http://www.cc98.org/dispbbs.asp?boardID=212&ID=4011172

## LAC name in config file
L2TPD_LAC=zjuvpn
L2TPD_CONTROL_FILE=/var/run/xl2tpd/l2tp-control
L2TPD_INIT_FILE=/etc/init.d/xl2tpd
L2TPD_CFG_TMPL=/etc/xl2tpd/xl2tpd.conf.client-example
L2TPD_CFG_FILE=/etc/xl2tpd/xl2tpd.conf
PPP_OPT_FILE=/etc/ppp/peers/zjuvpn
PPP_LOG_FILE=/var/log/zjuvpn
VPN_SERVER="10.5.1.7" #VPN_SERVER="10.5.1.9"

# get status
usage()
{
    cat <<EOF
$0: A utility for ZJU school L2TP VPN.
Usage: $0[ACTION]

Actions:
      Default             Connect.
      -d                  Disconnect.
      -c                  Configure.
      -s                  Only setup static route.
      -h                  Show this information.
EOF
}

check_connection()
{
    if ping -c 1 -q $VPN_SERVER > /dev/null 2>&1 ; then
        return 0
    else
cat <<EOF
[ERR] $VPN_SERVER unavailable
EOF
        bring_down_ppp
        exit 1
    fi
}

ppp_alive()
{
    if [ -e /var/run/ppp-$L2TPD_LAC.pid ] && ip addr show | grep 'inet.*ppp' > /dev/null; then
        return 0         # Yes, connected
    else
        return 1
    fi
}

check_configure_file()
{
    if [ ! -e "$L2TPD_CFG_TMPL" ]; then
        cat > $L2TPD_CFG_TMPL <<EOF
[global]
access control = no
auth file = /etc/ppp/chap-secrets
debug avp = no
debug network = no
debug packet = no
debug state = no
debug tunnel = no

[lac zjuvpn]
lns = 10.5.1.9
redial = no
redial timeout = 5
require chap = yes
require authentication = no
ppp debug = no
pppoptfile = /etc/ppp/peers/zjuvpn
require pap = no
autodial = yes

EOF
    fi

    if [ ! -e "$L2TPD_CFG_FILE" ]; then
        cp -f $L2TPD_CFG_TMPL $L2TPD_CFG_FILE
    elif ! grep -q "\[lac $L2TPD_LAC\]" $L2TPD_CFG_FILE; then
        sed -n '9~1p' $L2TPD_CFG_TMPL >> $L2TPD_CFG_FILE
    fi

    if [ ! -e "$PPP_OPT_FILE" ]; then
        read_user_passwd
    fi
}

read_user_passwd()
{
    read -p "Username: " username
    if [ "${username/@/}" = "$username" ]; then
        echo -e "WARNING: If you are connecting to ZJU VPN, you\e[01;31;1m must\e[0m append your domain name (e.g. @a / @c / @d) after your username."
        return 1
    fi
    read -p "Password: " password
    echo

    cat > $PPP_OPT_FILE <<EOF
noauth
linkname $L2TPD_LAC
logfile $PPP_LOG_FILE
name $username
password $password
EOF
    chmod 600 $PPP_OPT_FILE

    unset username
    unset password

    echo "[MSG] User and Passwd saved."
    return 0
}

# set parameter
bring_up_ppp()
{
    $L2TPD_INIT_FILE stop >/dev/null 2>&1
    echo -n > $PPP_LOG_FILE
    $L2TPD_INIT_FILE start >/dev/null 2>&1

    for i in $(seq 0 120)
    do
        if ppp_alive; then
            echo "[LOG] Done!"
#            tail $PPP_LOG_FILE | sed -u 's/^/[LOG] pppd: /'
            tail $PPP_LOG_FILE | sed 's/^/[LOG] pppd: /'
            echo -n > $PPP_LOG_FILE
            return 0     # Yes, brought up!
        fi
        #echo -n -e "\\r[MSG] Trying to bring up vpn... $i"
        echo "[MSG] Trying to bring up vpn... $i"
        sleep 1
#        tail $PPP_LOG_FILE | sed -u 's/^/[LOG] pppd: /'
        tail $PPP_LOG_FILE | sed 's/^/[LOG] pppd: /'
        echo -n > $PPP_LOG_FILE
    done
}

bring_down_ppp()
{
    echo -n "[MSG] Disconnecting VPN ... "

    [ -e $L2TPD_CONTROL_FILE ] && echo "d $L2TPD_LAC" > $L2TPD_CONTROL_FILE
    $L2TPD_INIT_FILE stop >/dev/null 2>&1

    PPP=$(ip addr show | grep ppp[0-9]: | cut "-d " -f2 | cut -d: -f1)
    if [ -n "$PPP" ]; then
        echo "[MSG] ifdown $PPP"
        ifconfig $PPP down
    fi

    echo "Done!"
    tail $PPP_LOG_FILE | sed 's/^/[LOG] pppd: /'    
    echo -n > $PPP_LOG_FILE
    return 0
}

setup_route()
{
    GW=$(ip route get $VPN_SERVER 2>/dev/null | grep via | awk '{print $3}')
    PPP=$(ip addr show | grep ppp[0-9]: | cut "-d " -f2 | cut -d: -f1)
    echo "[MSG] Detected gateway: $GW, PPP device: $PPP ."
    echo -n "[MSG] Setting up route table...  "

    ip route add  10.0.0.0/8 via $GW  #2>/dev/null

    ip route add   0.0.0.0/1 dev $PPP #2>/dev/null
    ip route add 128.0.0.0/1 dev $PPP #2>/dev/null

    #ip route del default via $GW
    #ip route add default dev $PPP
    
    echo "Done!"
}

connect()
{
    bring_up_ppp && setup_route
}

reconnect()
{
    bring_down_ppp && connect
}

####################
# Main
####################
if [ $# -lt 1 ]; then
    check_connection
    check_configure_file
    reconnect
elif [ "$1" = "-d" ]; then
    bring_down_ppp
elif [ "$1" = "-c" ]; then
    rm $PPP_OPT_FILE
    check_configure_file
elif [ "$1" = "-s" ]; then
    check_connection
    setup_route
elif [ "$1" = "-h" ]; then
    usage
else
    echo "[ERR] Unknown parameter.";
    usage
fi
