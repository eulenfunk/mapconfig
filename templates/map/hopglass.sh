#!/bin/bash
cd $(dirname $0)
node ../hopglass-server/hopglass-server.js --webport 4PORT --collectorport 3PORT --iface bat-SITE --targetip ff02::1
