#!/bin/bash

cd $(dirname $0)
HOME=$PWD

#replace $2 with $3 in directory $1 recursively
function replace {
	find $1 -type f -print0 | xargs -0 sed -i "s;$2;$3;g"
}

function fastd {
	cp -r templates/fastd new/fastd/$2
	replace new/fastd/$2 SITE $2
	replace new/fastd/$2 MTU $5
}

function map {
	cp -r templates/map new/map/$2
	replace new/map/$2 SITE $2
	replace new/map/$2 PORT $4
	echo "  - job_name: '$2'" >> new/map/prometheus.yml
	echo "    target_groups:" >> new/map/prometheus.yml
	echo "      - targets: ['localhost:4$4']" >> new/map/prometheus.yml
	cp -r out/map/$2/raw.json new/map/$2/
	cp templates/map/aliases.json.$2 new/map/$2/
}

function nginx {
	cp templates/nginx/domain.org.conf.example$6 new/nginx/conf.d/$3.conf
	replace new/nginx/conf.d/$3.conf URL $3
	replace new/nginx/conf.d/$3.conf PORT $4
	cp -r templates/webdir new/webdir/$3
	replace new/webdir/$3 NAME "$(echo $1 | sed 's/:/ /g')"
	replace new/webdir/$3 SITE $2
}

rm -rf new
mkdir new

#prepare fastd
cp -r templates/fastdbase new/fastd
git clone https://github.com/eulenfunk/fastd-peers new/fastd/peers

#prepare map
cp -r templates/mapbase new/map
git clone https://github.com/plumpudding/hopglass-server new/map/hopglass-server
cd new/map/hopglass-server
npm install
cd $HOME
mv out/map/grafana new/map/
cp -r out/map/prometheus new/map/
mv out/map/data new/map/

#prepare nginx & webdir
cp -r templates/nginxbase new/nginx
cp -r templates/webdirbase new/webdir
git clone https://github.com/plumpudding/hopglass
cd hopglass
npm install
grunt
cd ..
mv hopglass/build new/webdir/map.eulenfunk.de/
rm -rf hopglass

while read l
do
	fastd $l
	map $l
	nginx $l
	#$l = NAME SITE URI PORT MTU
done < $HOME/sites

#cleanup map
chmod +x new
chown -R map:map new/map

rm -rf backup
mv out backup
mv new out

function restart {
	systemctl restart fastd@$2
	systemctl enable fastd@$2
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
