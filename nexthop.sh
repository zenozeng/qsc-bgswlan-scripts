#!/bin/sh
 
url="http://10.50.200.245"
ua="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1700.77 Safari/537.36"
login () {
    echo $'\n'"Login using :$1 :$2"
    # auto logout
    curl -d "action=auto_dm&username=$1&password=$2" "$url/rad_online.php" -A "$ua" 
    # login
    curl -d "action=login&username=$1&password=$2&ac_id=3&type=1&wbaredirect=http://www.baidu.com/&mac=undefined&user_ip=&is_ldap=1&local_auth=1" "$url/cgi-bin/srun_portal" -A "$ua"
}
 
USER1=`cat users | head -n1`
PASSWD1=`cat users | head -n2 | tail -n1`
USER2=`cat users | head -n3 | tail -n1`
PASSWD2=`cat users | head -n4 | tail -n1`
 
ip route delete 10.50.200.245
ip route add 10.50.200.245 dev wlan1
login $USER1 $PASSWD1
 
ip route replace 10.50.200.245 dev wlan0-1
login $USER2 $PASSWD2
 
echo $'\n'"# Get GW"
GW1=`ifconfig wlan1 | grep -o 'inet addr[^ ]*' | grep -o '[0-9.]*' | cut -d '.' -f3`
if [ $GW1 -gt 127 ]; then
    GW1=10.189.128.1
else
    GW1=10.189.0.1
fi
echo "GW1:$GW1"
 
GW2=`ifconfig wlan0-1 | grep -o 'inet addr[^ ]*' | grep -o '[0-9.]*' | cut -d '.' -f3`
if [ $GW2 -gt 127 ]; then
    GW2=10.189.128.1
else
    GW2=10.189.0.1
fi
echo "GW2:$GW2"
 
# Set up IP Route
ip route delete default
ip route add default nexthop dev ppp0 nexthop via $GW1 dev wlan1 nexthop via $GW2 dev wlan0-1
# ip route add default nexthop via $GW1 dev wlan1 nexthop via $GW2 dev wlan0-1
# ip route add default nexthop dev ppp0 nexthop via 10.189.0.1 dev wlan1 nexthop via 10.189.128.1 dev wlan0-1
