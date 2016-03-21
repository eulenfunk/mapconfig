#!/bin/bash
ip l set dev $1 address 02:a5:a7:99:20:cd
ip l set dev $1 up
modprobe batman-adv
batctl -m bat-$1 if add $1
#netctl restart bat-$1
ip l set dev bat-$1 up
sleep 5
su - map -c "~/$1/hopglass.sh" &
