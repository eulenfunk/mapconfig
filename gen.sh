#!/bin/bash

function replace {
	find $1 -type f -print0 | xargs -0 sed -i "s;$2;$3;g"
}

#instance functions

function instance_fastd {
	rm -rf /etc/fastd/$3
	cp -r templates/instance/fastd /etc/fastd/$3
	replace /etc/fastd/$3 SITE $3
	replace /etc/fastd/$3 MTU $7
	replace /etc/fastd/$3 BIND "$(echo $8 | sed 's/_/ /g')"
	systemctl enable fastd@$3
	systemctl restart fastd@$3
}

function instance_hgserver {
	rm -rf /etc/hopglass-server/$3
	cp -r templates/instance/hopglass-server /etc/hopglass-server/$3
	replace /etc/hopglass-server/$3 SITE $3
	replace /etc/hopglass-server/$3 PORT $6
	echo "  - job_name: '$3'" >> /etc/prometheus/prometheus.yml
	echo "    target_groups:" >> /etc/prometheus/prometheus.yml
	echo "      - targets: ['localhost:4$6']" >> /etc/prometheus/prometheus.yml
	mkdir -p /var/local/hopglass-server/$3
	systemctl enable hopglass-server@$3
	systemctl restart hopglass-server@$3
}

function instance_nginx {
	cp templates/instance/example.com.conf$5 /etc/nginx/conf.d/$4.conf
	replace /etc/nginx/conf.d/$4.conf URL $4
	replace /etc/nginx/conf.d/$4.conf PORT $6
	replace /etc/nginx/conf.d/$4.conf WEBDIR $WEBDIR
}

function instance_webdir {
	rm -rf $WEBDIR/$4
	cp -r templates/instance/webdir $WEBDIR/$4
	replace $WEBDIR/$4 NAME $(echo $2 | sed 's/_/ /g')
	replace $WEBDIR/$4 SITE $3
	replace $WEBDIR/$4 PROTO $BASEDOM_PROTO
	replace $WEBDIR/$4 BASEDOM $BASEDOM
}

#group functions

function group_nginx {
	cp templates/group/example.com.conf$5 /etc/nginx/conf.d/$4.conf
	replace /etc/nginx/conf.d/$4.conf URL $4
	replace /etc/nginx/conf.d/$4.conf WEBDIR $WEBDIR
}

function group_webdir {
	rm -rf $WEBDIR/$4
	cp -r templates/group/webdir $WEBDIR/$4
	replace $WEBDIR/$4 NAME $(echo $2 | sed 's/_/ /g')
	DATASOURCES=""
	for SITE in $(echo $3 | sed 's/,/ /g')
	do
		URL=$(cat $HOME/sites | awk "\$3 == \"$SITE\"" | cut -d' ' -f4)
		URL_ENC=$(cat $HOME/sites | awk "\$3 == \"$SITE\"" | cut -d' ' -f5)
		if [ "$URL_ENC" == "1" ]
		then
			URL_PROTO="https"
		else
			URL_PROTO="http"
		fi
		if [ "$DATASOURCES" == "" ]
		then
			DATASOURCES="    \"$URL_PROTO://$URL/data/\""
		else
			DATASOURCES="$DATASOURCES,\n    \"$URL_PROTO://$URL/data/\""
		fi
	done
	replace $WEBDIR/$4 DATASOURCES "$DATASOURCES"
	replace $WEBDIR/$4 SITE $(echo $3 | sed 's/,/\&var-id=/g')
	replace $WEBDIR/$4 PROTO $BASEDOM_PROTO
	replace $WEBDIR/$4 BASEDOM $BASEDOM
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
}

function all {
	cp templates/init/prometheus.yml /etc/prometheus/prometheus.yml
	while read l
	do
		#$l = TYPE NAME SITE URI PORT MTU
		case "$(echo $l | cut -d' ' -f1)" in
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
		"basedom")
			BASEDOM=$(echo $l | cut -d' ' -f2)
			BASEDOM_ENC=$(echo $l | cut -d' ' -f3)
			if [ "$BASEDOM_ENC" == "1" ]
			then
				BASEDOM_PROTO="https"
			else
				BASEDOM_PROTO="http"
			fi
			;;
		esac
	done < $HOME/sites
	systemctl restart prometheus
	systemctl restart nginx
	chown -R hopglass:hopglass /var/local/hopglass-server
	ln -s /opt/hopglass/web/build $WEBDIR/$BASEDOM/build
}

cd $(dirname $0)
HOME=$PWD
WEBDIR="/var/www"

$@

