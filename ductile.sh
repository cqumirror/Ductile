#!/bin/sh
# shellcheck shell=ash


# Check distribution
OS_RELEASE=/etc/os-release

ERROR_LOG_DIR=/var/log/

# CLI options for distributions like openwrt which uses busybox by default
optspec="-:vchm"
# - for long option
# c for config
# h for help
# m for specific mirror

while getopts "$optspec" optchar; do
	case $optchar in
		-)
			case $OPTARG in
				config)
					;;
				help)
					;;
				mirror)
					;;
			esac
			;;
		c)
			;;
		h)
			;;
		m)
			;;

		*)
			if [ "$OPTERR" !=1 ] || [ "${optspec:0:1}" = ":" ]; then
				echo "Non-option argument: '-${OPTARG}' " >&2
			fi
			;;
	esac
done

