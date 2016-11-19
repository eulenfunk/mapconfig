#!/bin/bash

#wup kontakte ausblenden
sed 's/"showContact": true/"showContact": false/' -i /var/www/wup.map.eulenfunk.de/config.json
