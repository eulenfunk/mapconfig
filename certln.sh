#!/bin/bash
base=/etc/letsencrypt/live
dest=ddorf.map.eulenfunk.de
 ln -s $base/$dest $base/map.eulenfunk.de


for dom in $(cat /opt/eulenfunk/map/sites|grep -v \#|grep instance |cut -d" " -f4|sed ':a;N;$!ba;s/\n/ /g'); do 
 echo ln -s $base/$dest $base/$dom
 ln -s $base/$dest $base/$dom
done

for dom in $(cat /opt/eulenfunk/map/sites|grep -v \#|grep alias |cut -d" " -f2|sed ':a;N;$!ba;s/\n/ /g'); do 
 echo ln -s $base/$dest $base/$dom
 ln -s $base/$dest $base/$dom
done

for dom in $(cat /opt/eulenfunk/map/sites|grep -v \#|grep group |cut -d" " -f4|sed ':a;N;$!ba;s/\n/ /g'); do 
 echo ln -s $base/$dest $base/$dom
  ln -s $base/$dest $base/$dom
done

