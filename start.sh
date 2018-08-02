#!/bin/bash -e
# Dockerfile variables
export TAG
export ServerIP
export ServerIPv6
export PYTEST
export PHP_ENV_CONFIG
export PHP_ERROR_LOG 
export HOSTNAME
export WEBLOGDIR
export DNS1
export DNS2
export INTERFACE
export IPv6
export WEBPASSWORD
export WEB_PORT

export adlistFile='/etc/pihole/adlists.list'

# The below functions are all contained in bash_functions.sh
. /bash_functions.sh

# Some of the bash_functions use variables these core pi-hole/web scripts
. /opt/pihole/webpage.sh
# PH_TEST prevents the install from actually running (someone should rename that)
PH_TEST=true . $PIHOLE_INSTALL

echo " ::: Starting docker specific setup for docker diginc/pi-hole"
validate_env || exit 1
prepare_setup_vars
change_setting "IPV4_ADDRESS" "$ServerIP"
change_setting "IPV6_ADDRESS" "$ServerIPv6"
setup_web_port "$WEB_PORT"
setup_web_password "$WEBPASSWORD"
setup_dnsmasq "$DNS1" "$DNS2" "$INTERFACE"
setup_php_env
setup_dnsmasq_hostnames "$ServerIP" "$ServerIPv6" "$HOSTNAME"
setup_ipv4_ipv6
setup_lighttpd_bind "$ServerIP"
setup_blocklists
test_configs

[ -f /.piholeFirstBoot ] && rm /.piholeFirstBoot

echo "::: Docker start setup complete"
