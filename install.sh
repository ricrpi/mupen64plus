#!/bin/sh

# terminate the script if any commands return a non-zero error code
set -e

if [ "$1" = "-h" -o "$1" = "--help" ]; then
	echo "Mupen64plus installer for the Raspberry PI"
	echo "Usage:"
	echo "[Environment Vars] ./buid_test.sh [makefile targets]"
	echo
	echo "Environment Variable options:"
	echo ""
	echo "    CLEAN=[1]                 Clean before build"
	echo "    MAKE=[make]               Make Utility to use"
	echo "    M64P_COMPONENTS=          The list of components to download and build"
	echo "                              The default is to read ./pluginList. "
	echo "                              One can specify the plugin names e.g. 'core'."
	echo "                              This will override automatic changing of the branch"
	echo "    PLUGIN_FILE=[defaultList] File with List of plugins to build"
	echo "    BUILDDIR=[./]             Directory to download and build plugins in"
	echo "    REPO=[mupen64plus]        Default repository on https://github.com"
	echo ""

	exit 0
fi

M64P_COMPONENTS_FILE=0
defaultPluginList="defaultList"

PATH=$PWD:$PATH

#------------------- set some variables if not specified ----------------------------------------

IAM=`whoami`

if [ -z "$CLEAN" ]; then
	CLEAN=1
fi

if [ -z "$MAKE" ]; then
	MAKE=make
fi

if [ -z "$M64P_COMPONENTS" ]; then
	if [ -n "$PLUGIN_FILE" ]; then
		defaultPluginList="$PLUGIN_FILE"
	fi

	M64P_COMPONENTS_FILE=1

	#get file contents, ignore comments, blank lines and replace multiple tabs with single comma
	M64P_COMPONENTS=`cat "$defaultPluginList" | grep -v -e '^#' -e '^$' | cut -d '#' -f 1 | sed -r 's:\t+:,:g'`
fi

if [ -z "$BUILDDIR" ]; then
	BUILDDIR="."
fi

if [ -z "$REPO" ]; then
	REPO="mupen64plus"
fi

#------------------------------- set staic variables  --------------------------------------------

MAKE_INSTALL="PLUGINDIR= SHAREDIR= BINDIR= MANDIR= LIBDIR= INCDIR=api LDCONFIG=true "

for component in ${M64P_COMPONENTS}; do
	plugin=`echo "${component}" | cut -d , -f 1`
	repository=`echo "${component}" | cut -d , -f 2`

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
		
	if [ "$component_type" = "front-end" ]; then
		"$MAKE" -C ${BUILDDIR}/$repository/mupen64plus-${plugin}/projects/unix install $@ ${MAKE_INSTALL} DESTDIR="/usr/bin"
	else
		mkdir -p "/usr/local/lib/mupen64plus"
		"$MAKE" -C ${BUILDDIR}/$repository/mupen64plus-${plugin}/projects/unix install $@ ${MAKE_INSTALL} DESTDIR="/usr/lib/mupen64plus/"
	fi
	
done
