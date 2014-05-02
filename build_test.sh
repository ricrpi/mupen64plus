#!/bin/sh

# terminate the script if any commands return a non-zero error code
set -e

if [ "$1" = "-h" || "$1" = "--help"]; then
	echo "Mupen64plus installer for the Raspberry PI"
	echo "Environment Variable options:"
	echo ""
	echo "    MAKE=[make]               Make Utility to use"
	echo "    M64P_COMPONENTS=          The list of components to download and build"
	echo "                              The default is to read ./pluginList however one can"
	echo "                              specify just the plugin names e.g. 'core'"      
	echo "    PREFIXDIR=[~/mupen64plus] Directory to download and compile plugins"
	echo "    REPO=[mupen64plus]        Default repository on https://github.com"
	echo " "
fi

#------------------- set some variables if not specified ----------------------------------------

IAM=`whoami`

if [ -z "$MAKE" ]; then
	MAKE=make
fi

if [ -z "$M64P_COMPONENTS" ]; then
	M64P_COMPONENTS=`cat pluginList | grep -v -e '^#' -e '^$' | cut -d '#' -f 1 | sed -r 's:\t+:\t:g'`
IFS='
'
fi

if [ -z "$PREFIXDIR" ]; then
	if [ $IAM = "root" ]; then
		PREFIXDIR="/root/mupen64plus"
	else
		PREFIXDIR="/home/${IAM}/mupen64plus"
	fi
fi

if [ -z "$REPO" ]; then
	REPO="mupen64plus"
fi

#------------------------------- set staic variables  --------------------------------------------

RASPBERRY_PI=1
MAKE_INSTALL="PLUGINDIR= SHAREDIR= BINDIR= MANDIR= LIBDIR= INCDIR=api LDCONFIG=true "

#------------------------------- create test folder --------------------------------------------

mkdir -p ./test/

#------------------------------- SDL dev libraries --------------------------------------------
if [ "$IAM" = "root" ]; then
	if [ ! -e "/usr/bin/sdl-config" ]; then
		echo "************************************ Downloading/Installing SDL"
		apt-get install -y libsdl1.2-dev
	fi
else
	if [ ! -e "/usr/bin/sdl-config" ]; then
		echo "You need to install SDL development libraries"
		echo "Either run this script with sudo/root or run 'apt-get install libsdl1.2-dev'"
	fi
fi


#------------------------------- Download missing plugins --------------------------------------------

for component in ${M64P_COMPONENTS}; do
	plugin=`echo "${component}" | cut -f 1`
	repository=`echo "${component}" | cut -f 2`
	branch=`echo "${component}" | cut -f 3`

	if [ -z "$repository" ]; then
		repository=$REPO
	fi
	if [ -z "$branch" ]; then
		branch="master"
	fi

	if [ ! -e "${PREFIXDIR}/mupen64plus-${plugin}" ]; then
		echo "************************************ Downloading ${plugin} from ${repository} to ${PREFIXDIR}/mupen64plus-${plugin}"
		git clone https://github.com/${repository}/mupen64plus-${plugin} ${PREFIXDIR}/mupen64plus-${plugin}
	fi
done

#--------------------------------------- Build plugins --------------------------------------------

for component in ${M64P_COMPONENTS}; do
	plugin=`echo "${component}" | cut -f 1`
	repository=`echo "${component}" | cut -f 2`
	branch=`echo "${component}" | cut -f 3`

	if [ -z "$repository" ]; then
		repository=$REPO
	fi
	if [ -z "$branch" ]; then
		branch="master"
	fi

	if [ "${plugin}" = "core" ]; then
		component_type="library"
	elif  [ "${plugin}" = "rom" ]; then
		if [ "$0" = "build_test.sh"]; then
			echo "************************************ Building test ROM"
			mkdir -p ./test/
			cp ${PREFIXDIR}/mupen64plus-rom/m64p_test_rom.v64 ./test/
			continue
		fi
	elif  [ "${plugin}" = "ui-console" ]; then
		component_type="front-end"
	else
		component_type="plugin"
	fi

	echo "************************************ Building ${plugin} ${component_type}"
	if [ -n "$CLEAN" ]; then
	"$MAKE" -C ${PREFIXDIR}/mupen64plus-${plugin}/projects/unix clean $@
	fi

	"$MAKE" -C ${PREFIXDIR}/mupen64plus-${plugin}/projects/unix all $@
	
	if [ "$0" = "build_test.sh"]; then
	"$MAKE" -C ${PREFIXDIR}/mupen64plus-${plugin}/projects/unix install $@ ${MAKE_INSTALL} DESTDIR="$(pwd)/test/"
	else
	"$MAKE" -C ${PREFIXDIR}/mupen64plus-${plugin}/projects/unix install $@ ${MAKE_INSTALL} DESTDIR="/usr/bin"
	fi

	mkdir -p ./test/doc
	for doc in LICENSES README RELEASE; do
		if [ -e "${PREFIXDIR}/mupen64plus-${component}/${doc}" ]; then
			cp "${PREFIXDIR}/mupen64plus-${plugin}/${doc}" "./test/doc/${doc}-mupen64plus-${plugin}"
		fi
	done
	for subdoc in gpl-license font-license lgpl-license module-api-versions.txt; do
		if [ -e "${PREFIXDIR}/mupen64plus-${plugin}/doc/${subdoc}" ]; then
			cp "${PREFIXDIR}/mupen64plus-${plugin}/doc/${subdoc}" ./test/doc/
		fi
	done
done
