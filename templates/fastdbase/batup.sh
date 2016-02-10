#!/bin/bash
ip l set dev $1 address 02:a5:a7:99:09:ab
ip l set dev $1 up
modprobe batman-adv
batctl -m bat-$1 if add $1
netctl restart bat-$1
sleep 1
su - map -c "~/start.sh $1"
