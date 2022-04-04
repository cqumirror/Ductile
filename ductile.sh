#!/bin/sh
# set -x
# set -v
#	Ductile.sh - Tools to change mirror for modern distributions
#
#	Copyright (c) 2022 CQULanunion Operation and Maintenance Team <cqumirror@gmail.com>
#	Lanunion of Chongqing University ( 2011 - 2022 ) All Rights Reserved.
#	

# Hard coded mirror list, for we cannot find a way to get all the urls online
# Format: site-code=['site-url','mirror_name_a','mirror_name_b',...]
# from A-Z. Pick the distribution we can use. Test using archlinux
mirrors=(bfsu bupt cqu tuna)
bfsu=(http://mirrors.bfsu.edu.cn archlinux)
bupt=(http://mirrors.bupt.edu.cn archlinux)
cqu=(http://mirrors.cqu.edu.cn archlinux)
tuna=(http://mirrors.tuna.tsinghua.edu.cn archlinux)

# Check distribution
OS_RELEASE=/etc/os-release
ERROR_LOG_DIR=/var/log
VERSION=0.0.1
TMP_DIR=/tmp
IS_TEST=1
DO_REFRESH=1
ONLINE=0


##  Using parseopts from archlinux 
#   parseopts.sh - getopt_long-like parser
#
#   Copyright (c) 2012-2021 Pacman Development Team <pacman-dev@archlinux.org>
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# A getopt_long-like parser which portably supports longopts and
# shortopts with some GNU extensions. For both short and long opts,
# options requiring an argument should be suffixed with a colon, and
# options with optional arguments should be suffixed with a question
# mark. After the first argument containing the short opts, any number
# of valid long opts may be be passed. The end of the options delimiter
# must then be added, followed by the user arguments to the calling
# program.
#
# Options with optional arguments will be returned as "--longopt=optarg"
# for longopts, or "-o=optarg" for shortopts. This isn't actually a valid
# way to pass an optional argument with a shortopt on the command line,
# but is done by parseopts to enable the caller script to split the option
# and its optarg easily.
#
# Recommended Usage:
#   OPT_SHORT='fb:zq?'
#   OPT_LONG=('foo' 'bar:' 'baz' 'qux?')
#   if ! parseopts "$OPT_SHORT" "${OPT_LONG[@]}" -- "$@"; then
#     exit 1
#   fi
#   set -- "${OPTRET[@]}"
# Returns:
#   0: parse success
#   1: parse failure (error message supplied)
parseopts() {
	local opt= optarg= i= shortopts=$1
	local -a longopts=() unused_argv=()

	shift
	while [[ $1 && $1 != '--' ]]; do
		longopts+=("$1")
		shift
	done
	shift

	longoptmatch() {
		local o longmatch=()
		for o in "${longopts[@]}"; do
			if [[ ${o%[:?]} = "$1" ]]; then
				longmatch=("$o")
				break
			fi
			[[ ${o%[:?]} = "$1"* ]] && longmatch+=("$o")
		done

		case ${#longmatch[*]} in
			1)
				# success, override with opt and return arg req (0 == none, 1 == required, 2 == optional)
				opt=${longmatch%[:?]}
				case $longmatch in
					*:)  return 1 ;;
					*\?) return 2 ;;
					*)   return 0 ;;
				esac
				;;
			0)
				# fail, no match found
				return 255 ;;
			*)
				# fail, ambiguous match
				printf "${0##*/}: $(gettext "option '%s' is ambiguous; possibilities:")" "--$1"
				printf " '%s'" "${longmatch[@]%[:?]}"
				printf '\n'
				return 254 ;;
		esac >&2
	}

	while (( $# )); do
		case $1 in
			--) # explicit end of options
				shift
				break
				;;
			-[!-]*) # short option
				for (( i = 1; i < ${#1}; i++ )); do
					opt=${1:i:1}

					case $shortopts in
						# option requires optarg
						*$opt:*)
							# if we're not at the end of the option chunk, the rest is the optarg
							if (( i < ${#1} - 1 )); then
								OPTRET+=("-$opt" "${1:i+1}")
								break
							# if we're at the end, grab the the next positional, if it exists
							elif (( i == ${#1} - 1 && $# > 1 )); then
								OPTRET+=("-$opt" "$2")
								shift
								break
							# parse failure
							else
								printf "${0##*/}: $(gettext "option requires an argument") -- '%s'\n" "$opt" >&2
								OPTRET=(--)
								return 1
							fi
							;;
						# option's optarg is optional
						*$opt\?*)
							# if we're not at the end of the option chunk, the rest is the optarg
							if (( i < ${#1} - 1 )); then
								OPTRET+=("-$opt=${1:i+1}")
								break
							# option has no optarg
							else
								OPTRET+=("-$opt")
							fi
							;;
						# option has no optarg
						*$opt*)
							OPTRET+=("-$opt")
							;;
						# option doesn't exist
						*)
							printf "${0##*/}: $(gettext "invalid option") -- '%s'\n" "$opt" >&2
							OPTRET=(--)
							return 1
							;;
					esac
				done
				;;
			--?*=*|--?*) # long option
				IFS='=' read -r opt optarg <<< "${1#--}"
				longoptmatch "$opt"
				case $? in
					0)
						# parse failure
						if [[ $1 = *=* ]]; then
							printf "${0##*/}: $(gettext "option '%s' does not allow an argument")\n" "--$opt" >&2
							OPTRET=(--)
							return 1
						# --longopt
						else
							OPTRET+=("--$opt")
						fi
						;;
					1)
						# --longopt=optarg
						if [[ $1 = *=* ]]; then
							OPTRET+=("--$opt" "$optarg")
						# --longopt optarg
						elif (( $# > 1 )); then
							OPTRET+=("--$opt" "$2" )
							shift
						# parse failure
						else
							printf "${0##*/}: $(gettext "option '%s' requires an argument")\n" "--$opt" >&2
							OPTRET=(--)
							return 1
						fi
						;;
					2)
						# --longopt=optarg
						if [[ $1 = *=* ]]; then
							OPTRET+=("--$opt=$optarg")
						# --longopt
						else
							OPTRET+=("--$opt")
						fi
						;;
					254)
						# ambiguous option -- error was reported for us by longoptmatch()
						OPTRET=(--)
						return 1
						;;
					255)
						# parse failure
						printf "${0##*/}: $(gettext "invalid option") '--%s'\n" "$opt" >&2
						OPTRET=(--)
						return 1
						;;
				esac
				;;
			*) # non-option arg encountered, add it as a parameter
				unused_argv+=("$1")
				;;
		esac
		shift
	done

	# add end-of-opt terminator and any leftover positional parameters
	OPTRET+=('--' "${unused_argv[@]}" "$@")
	unset longoptmatch

	return 0
}



# Check is os-release exists
if [ ! -f $OS_RELEASE ];then
    	echo "Seems os-release does not exist, you should either specific package manager or report this in issse"
	sleep 1
	exit;
fi

# import system information, don't source when release this script
# Get distro ID
DISTRO_ID=$(grep -rw '/etc/os-release' -e "ID" | cut -d "=" -f2)
echo() { printf '%s\n' "$*"; }

## TODO
starter_busybox() {
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
}

## workaround by Hagb_Green
# Usage:
# check_contains value "${array[@]}"
check_contains() {
	value=$1
	shift
	for i in "$@"; do
		[ "$i" == "$value" ] && return 0
	done
	echo "Site abbr or distro name not exist or cannot be precessed."
	exit 1
}

prepare_archlinux() {
	REPO_FILE_DIR='/etc/pacman.d'
	REPO_FILE=mirrorlist
	echo "==> Arch Linux Detected."
	echo
	cd $REPO_FILE_DIR
	if (( ! $ONLINE )); then eval SITE=\${$MIRROR[0]}; else SITE=$MIRROR; fi
	if (( $IS_TEST )) ; then 
		echo "==> Performing backup..."
		cp $REPO_FILE $REPO_FILE.bak
		echo "==> Backup original file at $REPO_FILE_DIR/$REPO_FILE.bak"
		echo "==> Performing replacement..."
		sed "/^## Generated.*/a ##\n## China\nServer = $SITE/archlinux/\$repo/os/\$arch" $REPO_FILE.bak > $REPO_FILE
		if (( $DO_REFRESH )) ; then echo "Do sudo pacman -Syy to update database."; echo && echo "Done"; exit; else pacman -Syy; echo && echo "Done"; exit; fi
	else
		sed "/^## Generated.*/a ##\n## China\nServer = $SITE/archlinux/\$repo/os/\$arch" $REPO_FILE > $TMP_DIR/$REPO_FILE
		echo "A sample of new $REPO_FILE_DIR/$REPO_FILE is placed in $TMP_DIR/$REPO_FILE"
		echo "Exit."
		if (( $DO_REFRESH )) ; then echo && echo "Done"; exit; else echo "Do sudo pacman -Syy to update database."; echo && echo "Done"; exit; fi
	fi
}


prepare_debian() {
	echo "pm is apt"
	apt --version
	exit
}

## TODO
# Need to expand other distribution ids
# Steps:
#	- Get array containing site information with the variable value from a dynamically named variable 
#	- Check mirror existance
#	- Action
#
#
repo_replace() {
	case "$DISTRO_ID" in
		arch)
			echo "$MIRROR"
			if (( ! $ONLINE )); then eval temp_var=\${$MIRROR[@]}; check_contains archlinux $temp_var; fi
			prepare_archlinux
			;;
		debian)	prepare_debian;;
		ubuntu)	echo "pm is apt"; PM=apt; exit;;
		fedora) echo "pm is dnf"; PM=dnf; exit;;
		\"opensuse-leap\")	echo "pm is zypp"; exit;;
		\"opensuse-tumbleweed\")	echo "pm is zypp"; exit;;
	esac
}


if [[ $DISTRO_ID == *"openwrt"* ]] ; then
	starter_busybox
else

	usage() {
	printf "ductile %s\n" "$makepkg_version"
	echo
	printf -- "$(gettext "Easily changing mirror using shell script.")\n"
	echo
	printf -- "$(gettext "Usage: %s [options]")\n" "$0"
	echo
	printf -- "$(gettext "Options:")\n"
	printf -- "$(gettext "  -V, --version		Show version information and exit")\n"
	echo
	printf -- "$(gettext "  -m, --mirror		Specific a mirror to use.")\n"
	echo
	printf -- "$(gettext "  -h, --help		Show help information and exit.")\n"
	echo
	printf -- "$(gettext "  -c, --config		Read config from config file.")\n"
	echo
	printf -- "$(gettext "  -R, --refresh		Automatically refresh repo database.")\n"
	echo
	printf -- "$(gettext "  -V, --verbose		Dry run this scripts and show things to change without applying changes.")\n"
	echo
	printf -- "$(gettext "  -r, --recommand	Add recommanded repos like archlinuxcn for Arch Linux.")\n"
	echo
	printf -- "$(gettext "  -p, --pm		Specify the package manager individually.")\n"
	echo
	printf -- "$(gettext "  -i, --ask		Run interactively.")\n"
	echo
	printf -- "$(gettext "  -U, --offline		Run scritps offline.")\n"
	echo
	printf -- "$(gettext "  -S, --speed		Run mirror speedtest and choose the fastest one.")\n"
	echo
	}

	version() {
		printf "ductile %s\n" "$VERSION"
		printf -- "Maintained by CQULanunion Operation and Maintenance Team <cqumirror@gmail.com>.\n"
		printf '\n'
		printf -- "$(gettext "\
	This is free software; see the source for copying conditions.\n\
	There is NO WARRANTY, to the extent permitted by law.\n")"
	}

	# PROGRAM START

	# ensure we have a sane umask set
	umask 0022

	# determine whether we have gettext; make it a no-op if we do not
	if ! type -p gettext >/dev/null; then
		gettext() {
			printf "%s\n" "$@"
		}
	fi
	
	ARGLIST=("$@")

	# Parse Command Line Options.
	OPT_SHORT="chpm:SUivRVr"
	# Options need argueents will need to add ":" after the long options. Like mirror -> "mirror:"
	OPT_LONG=('offline' 'speed' 'help' 'mirror:' 'config:' 'refresh' 'verbose' 'recommand' 'pm:' 'version' 'ask')

# 	# Pacman Options
# 	OPT_LONG+=('asdeps' 'noconfirm' 'needed' 'noprogressbar')

	if ! parseopts "$OPT_SHORT" "${OPT_LONG[@]}" -- "$@"; then
		exit $E_INVALID_OPTION
	fi
	set -- "${OPTRET[@]}"
	unset OPT_SHORT OPT_LONG OPTRET

	
	while true; do
		case "$1" in
			# Makepkg Options
			-h|--help)		usage; exit $E_OK ;;
			-v|--version)	version; exit $E_OK ;;
			-V|--verbose)	IS_TEST=0;;
			-m|--mirror)	shift; MIRROR=$1 ;;
			-i|--ask)		echo "ask" ;;
			-R|--refresh)	DO_REFRESH=0;;
			-U|--offline)	ONLINE=1;; # offline mode
			--)				shift; break ;;
		esac
		shift
	done
fi

## ONLINE=1
if (( $ONLINE )); then
	echo "Please enter the repo URL."
	echo "Like http://ex.ampl.e"
	read -p "> " MIRROR
	repo_replace
fi
## ONLINE=0
## Check if abbr exists

if [ -z "$MIRROR" ]; then echo "==> Mirror is not specific. Abort..." && exit 1; else check_contains $MIRROR "${mirrors[@]}"; fi

if (( $IS_TEST )) ; then 
	# Check root privilege
	if [[ $EUID -ne 0 ]]; then echo "This script must be run as root" && exit 1; fi
fi

echo "Start default mirror replacement with $MIRROR ..."
echo

# Name may change. Due to the function do more than just get pm name.
repo_replace
