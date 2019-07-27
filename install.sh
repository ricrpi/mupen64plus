#!/bin/sh

# terminate the script if any commands return a non-zero error code
set -e

if [ "$1" = "-h" -o "$1" = "--help" ]; then
	echo "Mupen64plus installer for the Raspberry PI"
	echo "Usage:"
	echo "[Environment Vars] ./install.sh"
	echo
	echo "Environment Variable options:"
	echo ""
	echo "    CLEAN=[1]                 Clean before build"
	echo "    MAKE=[make]               Make Utility to use"
	echo "    BUILDDIR=[./]             Directory to download and build plugins in"
	echo "    REPO=[mupen64plus]        Default repository on https://github.com"
	echo ""

	exit 0
fi

defaultPluginList="defaultList"

PATH=$PWD:$PATH

#------------------- set some variables if not specified ----------------------------------------

IAM=`whoami`

if [ -z "$CLEAN" ]; then
	CLEAN=0
fi

if [ -z "$MAKE" ]; then
	MAKE=make
fi

if [ -n "$1" ]; then
	defaultPluginList="$1"
fi

if [ ! -e "$defaultPluginList" ]; then
	echo "Cannot find file: $defaultPluginList"
	exit 
fi

#get file contents, ignore comments, blank lines and replace multiple tabs with single comma
M64P_COMPONENTS=`cat "${defaultPluginList}" | grep -v -e '^#' -e '^$' | cut -d '#' -f 1 | sed -r 's:\t+:,:g' | sed -r 's:\ +:,:g'`

if [ -z "$BUILDDIR" ]; then
	BUILDDIR="$PWD"
fi

if [ -z "$REPO" ]; then
	REPO="mupen64plus"
fi

#-------------------------------------- set API Directory ----------------------------------------

for component in ${M64P_COMPONENTS}; do
	plugin=`echo "${component}" | cut -d , -f 1`
	repository=`echo "${component}" | cut -d , -f 2`
	flags=`echo "${component}" | cut -d , -f 5- | sed -r 's:,:\ :g'`

	if [ "${plugin}" = "core" ]; then
		export APIDIR="../../../../$repository/mupen64plus-core/src/api"
		break
	fi
done

#------------------------------- set staic variables  --------------------------------------------

for component in ${M64P_COMPONENTS}; do
	plugin=`echo "${component}" | cut -d , -f 1`
	repository=`echo "${component}" | cut -d , -f 2`
	flags=`echo "${component}" | cut -d , -f 5- | sed -r 's:,:\ :g'`

	if [ -z "$plugin" ]; then
		continue
	fi

	if [ "${plugin}" = "core" ]; then
		component_type="library"
	elif  [ "${plugin}" = "rom" ]; then
		continue
		
	elif  [ "${plugin}" = "ui-console" ]; then
		component_type="front-end"
	else
		component_type="plugin"
	fi

	echo "************************************ Installing ${plugin} ${component_type}"
		
#	if [ "$component_type" = "front-end" ]; then
#		"$MAKE" -C ${BUILDDIR}/$repository/mupen64plus-${plugin}/projects/unix install $flags COREDIR="/usr/local/lib/"
#	else
		mkdir -p "/usr/local/lib/mupen64plus"
		sh -c "$MAKE -C ${BUILDDIR}/$repository/mupen64plus-${plugin}/projects/unix install $flags"
#	fi
	
done
