#!/bin/bash
echo -n letsencrypt certonly >certonly.sh
cat /opt/eulenfunk/map/sites|grep -v \#|grep basedom |cut -d" " -f4|sed s/^/\ -d\ /|sed ':a;N;$!ba;s/\n/ /g' >>certonly.sh 
cat /opt/eulenfunk/map/sites|grep -v \#|grep instance |cut -d" " -f4|sed s/^/\ -d\ /|sed ':a;N;$!ba;s/\n/ /g' >>certonly.sh 
cat /opt/eulenfunk/map/sites|grep -v \#|grep alias |cut -d" " -f2|sed s/^/\ -d\ /|sed ':a;N;$!ba;s/\n/ /g' >>certonly.sh
cat /opt/eulenfunk/map/sites|grep -v \#|grep group |cut -d" " -f4|sed s/^/\ -d\ /|sed ':a;N;$!ba;s/\n/ /g' >>certonly.sh
sed -i ':a;N;$!ba;s/\n/ /g' certonly.sh
