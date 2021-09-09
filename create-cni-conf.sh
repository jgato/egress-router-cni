# !/bin/bash

echo "run as root"

# Some env variables used by cnitool. 
# Path to the CNI Plugin. In this case, our egress-router
export CNI_PATH=./bin

# Path with CNI configuration files. It looks for *.conflist or *.conf files
export NETCONFPATH=./

~/go/bin/cnitool add egress-router /var/run/netns/testing 
