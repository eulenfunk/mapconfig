#!/bin/bash
sitesf=/opt/eulenfunk/map/sites
#sitesf=./sites
jsonpath=/data/nodes.json
outpath=/var/www/map.eulenfunk.de/data
outfile=nodes.json
tfileprefix="/tmp/$(basename $0).$$.tmp"
jsonoutput=$tfileprefix.allnodes.json

readarray -t -O "${#domurls[@]}" domurls < <( cat $sitesf|grep ^instance|cut -d" " -f4 )

for value in "${domurls[@]}"
do
     url=https://$value$jsonpath
     domurlss[${#domurlss[@]}]=$url
done

c=0
for url in "${domurlss[@]}"
do
     #echo $c $url
     dumpfile=$tfileprefix.$c
     wget -4 -O $dumpfile $url >/dev/null 2>&1
     [ ${#nodesstring} -ge 2 ] && nodesstring+=" + "
     nodesstring+=".["$c"].nodes"
     filestring+=" $dumpfile "
     let c++
done

#echo nodesstring: $nodesstring
#echo filestring: $filestring

jq -cs --arg filestring "$filestring" --arg nodesstring "$nodesstring"  "{ version: (.[0].version), timestamp: (.[0].timestamp), nodes: ( $nodesstring ) }" $filestring > $jsonoutput

[ ! -d "$outpath" ] &&  mkdir $outpath
[ -f "$outpath/$outfile" ] && rm  $outpath/$outfile
if [ ! -f "$outpath/$outfile" ] && [ -f  $jsonoutput ]; then
  cp $jsonoutput $outpath/$outfile
 fi
[ $(find $tfileprefix.* 2>/dev/null |wc -l) -gt 0 ] && rm $tfileprefix.*
