#!/bin/bash

function replace {
	find $1 -type f -print0 | xargs -0 sed -i "s;$2;$3;g"
}

#instance functions

function instance_fastd {
	rm -rf /etc/fastd/$3
	cp -r templates/instance/fastd /etc/fastd/$3
	replace /etc/fastd/$3 SITE $3
	replace /etc/fastd/$3 MTU $6
	replace /etc/fastd/$3 BIND ${7//_/}
	#systemctl enable fastd@$3
	#systemctl restart fastd@$3
}

function instance_hgserver {
	echo "  - job_name: '$3'" >> /etc/prometheus/prometheus.yml
	echo "    target_groups:" >> /etc/prometheus/prometheus.yml
	echo "      - targets: ['localhost:4$5']" >> /etc/prometheus/prometheus.yml
	rm -rf /etc/hopglass-server/$3
	cp -r templates/instance/hopglass-server /etc/hopglass-server/$3
	cd /etc/hopglass-server/$3
	replace . SITE $3
	replace . PORT $5
	cp $HOME/aliases/$3.json ./aliases.json 2> /dev/null
	cd $HOME
	mkdir -p /var/local/hopglass-server/$3
	#systemctl enable hopglass-server@$3
	#systemctl restart hopglass-server@$3
}

function instance_nginx {
	printf " $4" >> hosts
	cp $HOME/templates/instance/nginx.conf $WEBCONF/$4.conf
	replace $WEBCONF/$4.conf URL $4
	replace $WEBCONF/$4.conf PORT $5
}

function instance_webdir {
	rm -rf $WEBDATA/$4
	cp -r templates/instance/webdir $WEBDATA/$4
	replace $WEBDATA/$4 NAME ${2//_/}
	replace $WEBDATA/$4 SITE $3
}

#group functions

function group_nginx {
	printf " $4" >> hosts
	cp $HOME/templates/group/nginx.conf $WEBCONF/$4.conf
	replace $WEBCONF/$4.conf URL $4
}

function group_webdir {
	rm -rf $WEBDATA/$4
	cp -r templates/group/webdir $WEBDATA/$4
	replace $WEBDATA/$4 NAME "${2//_/}"
	DATASOURCES=""
	for SITE in ${3//,/ }
	do
		URL=$(cat $HOME/sites | awk "\$3 == \"$SITE\"" | cut -d' ' -f4)
		if [ "$DATASOURCES" == "" ]
		then
			DATASOURCES="    \"https://$URL/data/\""
		else
			DATASOURCES="$DATASOURCES,\n    \"https://$URL/data/\""
		fi
	done
	replace $WEBDATA/$4 DATASOURCES "$DATASOURCES"
	replace $WEBDATA/$4 SITE ${3//,/\\&var-id=}
}

#alias functions

function alias_nginx {
	printf " $2" >> hosts
	LINE=$(cat sites | awk "\$4 == \"$3\"")
	ALIAS_TYPE=$(echo $LINE | cut -d' ' -f1)
	cp $HOME/templates/alias/$ALIAS_TYPE.conf $WEBCONF/$2.conf
	replace $WEBCONF/$2.conf URL $2
	replace $WEBCONF/$2.conf PORT $(echo $LINE | cut -d' ' -f6)
	replace $WEBCONF/$2.conf ALIAS $(echo $LINE | cut -d' ' -f4)
}

#basedom functions

function basedom_nginx {
	BASEDOM=$4
	cp $HOME/templates/basedom/nginx.conf $WEBCONF/$4.conf
	replace $WEBCONF/$4.conf URL $4
}

#main functions

function init {
	#fastd
	cd /etc/fastd
	git clone https://github.com/eulenfunk/fastd-peers peers
	fastd --generate-key > secret.conf
	sed -e 's/Secret: /secret "/g' -e 's/$/";/g' -e 's/Public: /#public "/g' -i secret.conf
	chmod 700 secret.conf
	cp $HOME/templates/init/batup.sh .
	chmod +x batup.sh
	cd $HOME

	#nginx
	mv /etc/nginx{,.bak}
	cp -r templates/init/nginx /etc/nginx
	cp base/20-eulenmap.conf /etc/sysctl.d
	grep -v "$(hostname --ip-address)" /etc/hosts > /etc/hosts.head
}

function all {
	#partitial purge
	rm -rf $WEBDATA/*
	rm -rf $WEBCONF/*
	printf "$(hostname --ip-address) $(hostname)" > hosts
	cp templates/init/prometheus.yml /etc/prometheus/prometheus.yml
	while read l
	do
		#$l = TYPE NAME SITE URI PORT MTU
		case "$(echo $l | cut -d' ' -f1)" in
		"basedom")
			basedom_nginx $l
			group_webdir $l
			ln -s /opt/hopglass/web/build $WEBDATA/$BASEDOM/build
			;;
		"instance")
			instance_fastd $l
			instance_hgserver $l
			instance_nginx $l
			instance_webdir $l
			;;
		"group")
			group_nginx $l
			group_webdir $l
			;;
		"alias")
			alias_nginx $l
			;;
		esac
	done < $HOME/sites
	replace $WEBCONF WEBDATA $WEBDATA
	replace $WEBDATA BASEDOM $BASEDOM
	cat /etc/hosts.head hosts > /etc/hosts
	systemctl restart prometheus
	systemctl restart nginx
	chown -R hopglass:hopglass /var/local/hopglass-server
}

cd $(dirname $0)
HOME=$PWD
WEBDATA="/var/www"
WEBCONF="/etc/nginx/conf.d"
$@

