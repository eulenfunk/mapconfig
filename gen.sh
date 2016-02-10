#!/bin/bash

cd $(dirname $0)
HOME=$PWD

#replace $2 with $3 in directory $1 recursively
function replace {
	find $1 -type f -print0 | xargs -0 sed -i "s;$2;$3;g"
}

function fastd {
	cp -r templates/fastd out/fastd/$2
	replace out/fastd/$2 SITE $2
	replace out/fastd/$2 MTU $5
}

function map {
	cp -r templates/map out/map/$2
	replace out/map/$2 SITE $2
	replace out/map/$2 PORT $4
	echo "  - job_name: '$2'" >> out/map/prometheus.yml
	echo "    target_groups:" >> out/map/prometheus.yml
	echo "      - targets: ['localhost:4$4']" >> out/map/prometheus.yml
	mv backup/map/$2/raw.json out/map/$2/
	cp templates/map/aliases.json.$2 out/map/$2/
}

function nginx {
	cp templates/nginx/domain.org.conf.example$6 out/nginx/conf.d/$3.conf
	replace out/nginx/conf.d/$3.conf URL $3
	replace out/nginx/conf.d/$3.conf PORT $4
	cp -r templates/webdir out/webdir/$3
	replace out/webdir/$3 NAME "$(echo $1 | sed 's/:/ /g')"
}

rm -rf backup
mv out backup
mkdir out

#prepare fastd
cp -r templates/fastdbase out/fastd
git clone https://github.com/eulenfunk/fastd-peers out/fastd/peers

#prepare map
cp -r templates/mapbase out/map
git clone https://github.com/plumpudding/hopglass-server out/map/hopglass-server
cd out/map/hopglass-server
npm install
cd $HOME
mv backup/map/grafana out/map/
mv backup/map/prometheus out/map/
mv backup/map/data out/map/

#prepare nginx & webdir
cp -r templates/nginxbase out/nginx
cp -r templates/webdirbase out/webdir
git clone https://github.com/plumpudding/hopglass
cd hopglass
npm install
grunt
cd ..
mv hopglass/build out/webdir/map.eulenfunk.de/
rm -rf hopglass

while read l
do
	fastd $l
	map $l
	nginx $l
	#$l = NAME SITE URI PORT MTU
done < $HOME/sites

#cleanup map
chmod +x out
chown -R map:map out/map

function restart {
	systemctl restart fastd@$2
}

while read l
do
        restart $l
done < $HOME/sites
netctl restart ens19-ffm

#pkill node
#pkill prometheus
#pkill grafana-server
systemctl restart nginx
