#!/bin/bash

function check_service {
	printf "P $1 $1="
	result=$(systemctl status --no-pager $1 | grep "Active:"| grep -o -e failed -e inactive -e active)
	num=0
	if [ "$result" == "active" ] ; then num=1; fi
	printf "$num;0.1:2;0:2 "
	echo status=$result
}

function check_instance {
	check_service "fastd@$3"
	check_service "hopglass-server@$3"
}

cd $(dirname $0)
HOME=$PWD

while read l
do
	#$l = TYPE NAME ffnr URI 8098 MTU
	[ "$(echo $l | cut -d' ' -f1)" == "instance" ] && check_instance $l
done < $HOME/sites

check_service nginx
check_service grafana-server
check_service prometheus-systemd
