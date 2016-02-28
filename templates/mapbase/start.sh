#!/bin/bash
cd $(dirname $0)

if [ -n "$1" ]
then
  for i in $@
  do
    ps aux | grep "start.sh" | grep "$i" | cut -d' ' -f2 | xargs kill 2> /dev/null
    ps aux | grep bat-$i | tr -s ' ' | cut -d' ' -f2 | xargs kill 2> /dev/null
    (while true; do $i/hopglass.sh; done) &
  done
#else
#  pkill prometheus
#  pkill grafana
#  sleep 0.5
fi

#sleep $(expr $RANDOM % 1000 / 100)
#pgrep prometheus || (while true; do ./prometheus/prometheus; done) &
#pgrep node_exporter || (while true; do ./prometheus/node_exporter; done) &
#cd grafana
#pgrep grafana-server || (while true; do ./bin/grafana-server; done) &
