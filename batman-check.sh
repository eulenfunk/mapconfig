#!/bin/bash

## Batman-Advanced
bat_version=$(batctl -v)
bat_adv_v=$(batctl -v 2>/dev/null|cut -d" " -f4|tr -d "]")
bat_ctl_v=$(batctl -v 2>/dev/null|cut -d" " -f2)
batadvequal=2
if [ "$bat_adv_v" == "$bat_ctl_v" ] ; then
  batadvequal=1
 fi

batmanloaded=$(lsmod |grep batman_adv|wc -l)

if [ "$batmanloaded" -le "0" ] ; then
   wall "batman-adv module not loaded! Installing"
   sleep 60
   /root/batman-adv-dkmsadd.sh
   wall "batman-adv module installed, rebooting in 10 seconds!"
   sleep 10
   reboot
  else
   wall "batman-adv seems to be loaded, not further action by batman-check.sh"
 fi
