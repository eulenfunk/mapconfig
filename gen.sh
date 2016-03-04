#!/bin/bash


#util
#replace $2 with $3 in directory $1 recursively
function replace {
	find $1 -type f -print0 | xargs -0 sed -i "s;$2;$3;g"
}

function fastdcom {
	cp -r templates/fastd new/fastd/$2
	replace new/fastd/$2 SITE $2
	replace new/fastd/$2 MTU $5
}

function mapcom {
	cp -r templates/map new/map/$2
	replace new/map/$2 SITE $2
	replace new/map/$2 PORT $4
	echo "  - job_name: '$2'" >> new/map/prometheus.yml
	echo "    target_groups:" >> new/map/prometheus.yml
	echo "      - targets: ['localhost:4$4']" >> new/map/prometheus.yml
	cp -r out/map/$2/raw.json new/map/$2/
	cp templates/map/aliases.json.$2 new/map/$2/aliases.json
}

function nginxcom {
	cp templates/nginx/domain.org.conf.example$6 new/nginx/conf.d/$3.conf
	replace new/nginx/conf.d/$3.conf URL $3
	replace new/nginx/conf.d/$3.conf PORT $4
	cp -r templates/webdir new/webdir/$3
	replace new/webdir/$3 NAME "$(echo $1 | sed 's/:/ /g')"
	replace new/webdir/$3 SITE $2
}

function fastdprep {
	#prepare fastd
	cp -r templates/fastdbase new/fastd
	git clone https://github.com/eulenfunk/fastd-peers new/fastd/peers
	cp out/fastd/secret.conf new/fastd/
}

function mapprep {
	#prepare map
	cp -r templates/mapbase new/map
	git clone https://github.com/plumpudding/hopglass-server new/map/hopglass-server
	cd new/map/hopglass-server
	npm install
	cd $HOME
}

function nginxprep {
	#prepare nginx & webdir
	cp -r templates/nginxbase new/nginx
	cp -r templates/webdirbase new/webdir
	cp -r hopglass/build new/webdir/map.eulenfunk.de/
}

function hopglass {
	cd hopglass
	git fetch --all
	git checkout -f origin/master
	npm install
	npm install grunt-cli
	rm -rf build
	node_modules/grunt-cli/bin/grunt
	cd ..
	#rm -rf hopglass
}

function install {
	#cleanup map
	chmod +x new
	sudo chown -R map:map new/map
	
	sudo systemctl stop nginx #fastd prometheus grafana-server
	
	sudo rm -rf backup
	sudo mv out backup
	sudo mv new out
	
	sudo systemctl start nginx #fastd prometheus grafana-server
	sudo pkill node
}

function all {
	sudo rm -rf new
	mkdir new

	fastdprep
	nginxprep
	mapprep
	
	while read l
	do
		#$l = NAME SITE URI PORT MTU
		fastdcom $l
		mapcom $l
		nginxcom $l
	done < $HOME/sites

	install
}

cd $(dirname $0)
HOME=$PWD
$@
