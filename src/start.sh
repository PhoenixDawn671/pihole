#!/bin/bash -e

if [ "${PH_VERBOSE:-0}" -gt 0 ] ; then
    set -x ;
fi


# The below functions are all contained in bash_functions.sh
# shellcheck source=/dev/null
. /usr/bin/bash_functions.sh

modifyUser pihole ${PIHOLE_UID}
modifyGroup pihole ${PIHOLE_GID}

# shellcheck source=/dev/null
# SKIP_INSTALL=true . /etc/.pihole/automated\ install/basic-install.sh

echo "  [i] Starting docker specific checks & setup for docker pihole/pihole"

# TODO:
#if [ ! -f /.piholeFirstBoot ] ; then
#    echo "   [i] Not first container startup so not running docker's setup, re-create container to run setup again"
#else
#    regular_setup_functions
#fi

# Initial checks
# ===========================
fix_capabilities
# validate_env || exit 1
ensure_basic_configuration


apply_FTL_Configs_From_Env

# Web interface setup
# ===========================
# load_web_password_secret
# setup_web_password

# Misc Setup
# ===========================
# setup_blocklists

# FTL setup
# ===========================

# setup_FTL_User
# setup_FTL_query_logging

[ -f /.piholeFirstBoot ] && rm /.piholeFirstBoot

echo "  [i] Docker start setup complete"
echo ""


echo "  [i] pihole-FTL ($FTL_CMD) will be started as ${DNSMASQ_USER}"
echo ""


if [ "${PH_VERBOSE:-0}" -gt 0 ] ; then
    set -x ;
fi

# Install editors inside container if requested
if [ "${INSTALL_DEV_TOOLS:-0}" -gt 0 ] ; then
    apk add --no-cache nano less
fi

# Remove possible leftovers from previous pihole-FTL processes
rm -f /dev/shm/FTL-* 2> /dev/null
rm -f /run/pihole/FTL.sock



# Start crond for scheduled scripts (logrotate, pihole flush, gravity update etc)
# crond

# Randomize gravity update time
sed -i "s/59 1 /$((1 + RANDOM % 58)) $((3 + RANDOM % 2))/" /crontab.txt
# Randomize update checker time
sed -i "s/59 17/$((1 + RANDOM % 58)) $((12 + RANDOM % 8))/" /crontab.txt
/usr/bin/crontab /crontab.txt

/usr/sbin/crond

gravityDBfile=$(getFTLConfigValue files.gravity)

if [ -z "$SKIPGRAVITYONBOOT" ] || [ ! -f "${gravityDBfile}" ]; then
    if [ -n "$SKIPGRAVITYONBOOT" ];then
        echo "  SKIPGRAVITYONBOOT is set, however ${gravityDBfile} does not exist (Likely due to a fresh volume). This is a required file for Pi-hole to operate."
        echo "  Ignoring SKIPGRAVITYONBOOT on this occaision."
    fi
    pihole -g
else
    echo "  Skipping Gravity Database Update."
fi

pihole updatechecker

# Start FTL. TODO: We need to either mock the service file or update the pihole script in the main repo to restart FTL if no init system is present
sh /opt/pihole/pihole-FTL-prestart.sh
capsh --user=$DNSMASQ_USER --keep=1 -- -c "/usr/bin/pihole-FTL $FTL_CMD >/dev/null" &

tail -f /var/log/pihole-FTL.log

# Notes on above:
# - DNSMASQ_USER default of pihole is in Dockerfile & can be overwritten by runtime container env
# - /var/log/pihole/pihole*.log has FTL's output that no-daemon would normally print in FG too
#   prevent duplicating it in docker logs by sending to dev null
