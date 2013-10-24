#!/bin/bash

dir=$(dirname $(readlink -f $0))
cd "${dir}"

echo "try in a moment: http://127.0.0.1:9292"

nohup rackup -s thin -o 127.0.0.1 -p 9292 -P rack.pid > "${dir}/access.log"
