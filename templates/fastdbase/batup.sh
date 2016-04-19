#!/bin/bash

# einen hostkey holen: md5 der mac-adresse des lokalen default-gatewaysD

hostkey=$(ip a |grep -A1 $(route -n|grep ^0.0.0.0|cut -c 73-80)|grep ether|cut -d" " -f6|md5sum|cut -b -8)
lb=$(echo $hostkey|cut -b 1-2)
hb=$(echo $hostkey|cut -b 3-4)

ip l set dev $1 address 02:a5:a7:99:$lb:$hb
ip l set dev $1 up
modprobe batman-adv
batctl -m bat-$1 if add $1
#netctl restart bat-$1
ip l set dev bat-$1 up
sleep 5
su - map -c "~/$1/hopglass.sh" &
