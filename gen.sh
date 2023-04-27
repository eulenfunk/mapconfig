#!/bin/bash
# set -u # stop at unset variables
# set -o pipefail # do not assume ok after multple chained pies.
# set -e # stop on errors - want to, but errorhandling is not yet done. TBD
cd /opt/eulenfunk/map


function replace {
	find $1 -type f -print0 | xargs -0 sed -i "s;$2;$3;g"
}

#instance functions

function instance_fastd {
        echo instance_fastd $3
	rm -rf /etc/fastd/$3
	cp -r templates/instance/fastd /etc/fastd/$3
	replace /etc/fastd/$3 SITE $3
	replace /etc/fastd/$3 MTU $6
	replace /etc/fastd/$3 BIND "${7//_/\ }"
	#systemctl enable fastd@$3
	systemctl restart fastd@$3
}

#$l = TYPE NAME SITE URI PORT MTU
#      name         - Bezeichnung, die auf der Map angezeigt wird
#      sitecode     - Eindeutiger Code der Instanz
#      fqdn         - Domainname, unter dem die Map erreichbar sein soll
#      port         - IP-Port auf dem der interne Hopglass-Server für diese Domain antwortet
#      mtu          - fastd-MTU der Domäne
#      fastd.conf   - Additionelle erste Zeile für die Fastd-config (bind...)
#      batgws       - exakte Anzahl der Fastd-Gatways (Alarmwert check_mk)
#      batnodes     - maximale Anzahl der Batman-Knoten (Crit-wert check_mk, Warn 80%)
#      batclients   - maximale Anzahl der Batman-Clients (Crit-wert für check_mk, Warn 80%)
function instance_l2tp {
        echo instance_l2tp $3
	rm -rf /etc/l2tp/$3
	BROKERS="$(cat $(ls /etc/fastd/peers/$3/*|grep -v '~') | \
		tr "\n" "#" | \
		sed -e 's/^/-b /g' -e 's/#$//g' -e 's/#/ -b /g')"
	echo "BROKERS=\"$BROKERS\"" > /etc/l2tp/$3
	echo "ID=$5" >> /etc/l2tp/$3
	echo "MTU=$6" >> /etc/l2tp/$3
	echo "UUID=$(cat /etc/machine-id)" >> /etc/l2tp/$3
	cp templates/init/tunneldigger\@.service /etc/systemd/system/tunneldigger\@.service
	systemctl enable tunneldigger@$3
	systemctl restart tunneldigger@$3
}

function instance_wgvxlan {
	echo instance_wgvxlan $3

	[ -f /etc/fastd/peers/$3/$3 ] || return
	source /etc/fastd/peers/$3/$3

	export PRIVATE_KEY=$(wg genkey)
	export PUBLIC_KEY=$(echo $PRIVATE_KEY | wg pubkey)
	#export IPV6_ADDR=$(echo $PUBLIC_KEY |md5sum|sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\)\(..\).*$/fe80::\1\2:\3\4:\5\6/')
	export IPV6_ADDR=$(wgvxlan_ipv6 $PUBLIC_KEY)
	export SITE=$3
	EXPVARS='$PRIVATE_KEY:$SERVER_PUBLIC_KEY:$SERVER_ENDPOINT:$ALLOWED_IPS:$IPV6_ADDR:$VXLAN_ID:$SITE'
	export PRIVATE_KEY SERVER_PUBLIC_KEY SERVER_ENDPOINT ALLOWED_IPS VXLAN_ID

	[ ! -d /etc/wireguard ] && mkdir -p /etc/wireguard
	envsubst "$EXPVARS" < $HOME/templates/instance/wireguard/wg.conf > /etc/wireguard/wg-$3.conf

	# tell the supernode our public key
	JSON='{"domain": "'"$SITE"'","public_key": "'"$PUBLIC_KEY"'"}'
	#wget -O- -v --post-data="$JSON" $BROKER
	curl -X POST $BROKER -d "$JSON"

	# check if wg interface still exists
	ip a s bat-$SITE >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		ip link del bat-$SITE
	fi
	ip a s vxlan-$SITE >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		ip link del vxlan-$SITE
	fi
	ip a s wg-$SITE >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		ip link del wg-$SITE
	fi

	# connect to wireguard (vxlan and bat interfaces are handled by wg-quick)
	systemctl restart wg-quick@wg-$SITE
	systemctl enable wg-quick@wg-$SITE
}

function instance_yanic {
	cp templates/instance/yanic.conf /etc/yanic/$3.conf
	replace /etc/yanic/$3.conf SITE $3
	replace /etc/yanic/$3.conf PORT $5
	mkdir -p /home/yanic/$3
	chown yanic /home/yanic/$3
	mkdir -p /tmp/yanic/$3
	chown yanic /tmp/yanic/$3
	systemctl restart yanic@$3
}

function instance_hgserver {
	echo "  - job_name: '$3'" >> /etc/prometheus/prometheus.yml
	echo "    static_configs:" >> /etc/prometheus/prometheus.yml
	echo "      - targets: ['localhost:4$5']" >> /etc/prometheus/prometheus.yml
	rm -rf /etc/hopglass-server/$3
	cp -r templates/instance/hopglass-server /etc/hopglass-server/$3
	replace /etc/hopglass-server/$3 SITE $3
	replace /etc/hopglass-server/$3 PORT $5
	cp $HOME/aliases/$3.json /etc/hopglass-server/$3/aliases.json 2> /dev/null
	cd $HOME
	mkdir -p /var/local/hopglass-server/$3
	#systemctl enable hopglass-server@$3
	systemctl restart hopglass-server@$3
}

function instance_nginx {
	printf " $4" >> hosts
	cp $HOME/templates/instance/nginx.conf $WEBCONF/$4.conf
	replace $WEBCONF/$4.conf URL $4
	replace $WEBCONF/$4.conf PORT $5
	replace $WEBCONF/$4.conf SITE $3
}

function instance_webdir {
	rm -rf $WEBDATA/$4
	cp -r templates/instance/webdir $WEBDATA/$4
	replace $WEBDATA/$4 NAME "${2//_/\ }"
	replace $WEBDATA/$4 SITE $3

	# (sudo -u hopglass bash -c "cp -r /tmp/meshviewer{,-$3}"; cp templates/instance/config_meshviewer.json /tmp/meshviewer-$3/config.json; replace /tmp/meshviewer-$3/config.json NAME "${2//_/\ }";	replace /tmp/meshviewer-$3/config.json SITE $3;	replace /tmp/meshviewer-$3/config.json BASEDOM $BASEDOM; sudo -u hopglass bash -c "cd /tmp/meshviewer-$3; node_modules/.bin/gulp"; cp -r /tmp/meshviewer-$3/build $WEBDATA/$4/new; rm -rf /tmp/meshviewer-$3) &
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
	replace $WEBDATA/$4 NAME "${2//_/\ }"
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
	replace $WEBDATA/$4 SITE ${3//,/\\&var-job=}

	# (sudo -u hopglass bash -c "cp -r /tmp/meshviewer{,-$4}"; cp templates/group/config_meshviewer.json /tmp/meshviewer-$4/config.json; replace /tmp/meshviewer-$4/config.json NAME "${2//_/\ }"; replace /tmp/meshviewer-$4/config.json SITE ${3//,/\\&var-job=}; replace /tmp/meshviewer-$4/config.json DATASOURCES "$DATASOURCES"; replace /tmp/meshviewer-$4/config.json BASEDOM $BASEDOM; sudo -u hopglass bash -c "cd /tmp/meshviewer-$4; node_modules/.bin/gulp"; cp -r /tmp/meshviewer-$4/build $WEBDATA/$4/new; rm -rf /tmp/meshviewer-$4) &
}

#alias functions

function alias_nginx {
	printf " $2" >> hosts
	LINE=$(cat sites | awk "\$4 == \"$3\"")
	ALIAS_TYPE=$(echo $LINE | cut -d' ' -f1)
	cp $HOME/templates/alias/$ALIAS_TYPE.conf $WEBCONF/$2.conf
	replace $WEBCONF/$2.conf URL $2
	replace $WEBCONF/$2.conf PORT $(echo $LINE | cut -d' ' -f5)
	replace $WEBCONF/$2.conf ALIAS $(echo $LINE | cut -d' ' -f4)
}

#basedom functions

function basedom_nginx {
	BASEDOM=$4
	cp $HOME/templates/basedom/nginx.conf $WEBCONF/$4.conf
	replace $WEBCONF/$4.conf URL $4
}

# wgvxlan ipv6 helper function
function wgvxlan_ipv6 {
	# generate a predictable v6 address
	local macaddr="$(echo $1 |md5sum|sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\).*$/02:\1:\2:\3:\4:\5/')"
	local oldIFS="$IFS"; IFS=':'; set -- $macaddr; IFS="$oldIFS"
	echo "fe80::$1$2:$3ff:fe$4:$5$6"
}

#main functions

function init {
	#fastd
	cd /etc/fastd
	git clone https://github.com/eulenfunk/fastd-peers peers
	fastd --generate-key > secret.conf
	sed -e 's/Secret: /secret "/g' -e 's/$/";/g' -e 's/Public: /#public "/g' -i secret.conf
	chmod 700 secret.conf

	# networking scripts
	mkdir -p /usr/local/bin
	cd /usr/local/bin
	cp $HOME/templates/init/batup .
	chmod +x batup
	cp $HOME/templates/init/delay.sh .
	chmod +x delay.sh
	cd $HOME

	#wireguard
	cp $home/templates/wg-watch /usr/local/bin
	chmod +x /usr/local/bin/wg-watch
	cp $home/templates/wg-watch.service /etc/systemd/system
	cp $home/templates/wg-watch.timer /etc/systemd/system

	# service files
	cp $HOME/templates/init/tunneldigger@.service /etc/systemd/system/
	systemctl daemon-reload
	systemctl enable wg-watch.timer
	systemctl start wg-watch.timer

	#nginx
	mv /etc/nginx{,.bak}
	cp -r templates/init/nginx /etc/nginx
	openssl dhparam -out /etc/nginx/dhparams.pem 2048
	cp base/20-eulenmap.conf /etc/sysctl.d
	grep -v "$(hostname --ip-address)" /etc/hosts > /etc/hosts.head
}

function all {
	#partitial purge
	rm -rf $WEBDATA/*
	rm -rf $WEBCONF/*
	rm -rf /tmp/meshviewer*
	cp -r /opt/hopglass/meshviewer /tmp/
	rm -rf /tmp/meshviewer/build
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
#			git clone https://github.com/Moorviper/meshviewer_hwpics $WEBDATA/$BASEDOM/meshviewer_hwpics
			git clone https://github.com/Adorfer/meshviewer_hwpics $WEBDATA/$BASEDOM/meshviewer_hwpics
			ln -s $WEBDATA/$BASEDOM/meshviewer_hwpics/nodes $WEBDATA/$BASEDOM/nodes
			;;
		"instance")
			instance_fastd $l
			instance_hgserver $l
			#instance_yanic $l
			instance_nginx $l
			instance_webdir $l
			;;
		"instancel2tp")
			instance_l2tp $l
			instance_hgserver $l
			#instance_yanic $l
			instance_nginx $l
			instance_webdir $l
			;;
		"instancewgvxlan")
			instance_wgvxlan $l
			instance_hgserver $l
			#instance_yanic $l
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
	systemctl restart prometheus-systemd
	systemctl restart nginx
	chown -R hopglass:hopglass /var/local/hopglass-server
	$HOME/patch.sh
}

cd $(dirname $0)
HOME=$PWD
WEBDATA="/var/www"
WEBCONF="/etc/nginx/conf.d"
$@

