#!/bin/bash
#   /etc/letsencrypt/live/map.eulenfunk.de-0001/fullchain.pem
base=/etc/letsencrypt/live
#base=ddorf.map.eulenfunk.de
dest=map.eulenfunk.de-0006
 echo ln -f -s -n  $base/$dest $base/map.eulenfunk.de
 ln -f -s -n  $base/$dest $base/map.eulenfunk.de

for dom in $(cat /opt/eulenfunk/map/sites|grep -v ^\#|grep instance |cut -d" " -f4|sed ':a;N;$!ba;s/\n/ /g'); do 
 echo ln -f -s $base/$dest $base/$dom
 ln -f -s -n  $base/$dest $base/$dom
done

for dom in $(cat /opt/eulenfunk/map/sites|grep -v ^\#|grep alias |cut -d" " -f2|sed ':a;N;$!ba;s/\n/ /g'); do 
 echo ln -f -s $base/$dest $base/$dom
 ln -f -s -n $base/$dest $base/$dom
done

for dom in $(cat /opt/eulenfunk/map/sites|grep -v ^\#|grep group |cut -d" " -f4|sed ':a;N;$!ba;s/\n/ /g'); do 
 echo ln -s $base/$dest $base/$dom
  ln -f -s -n $base/$dest $base/$dom
done

