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

#------------------- set some variables if not specified ----------------------------------------

IAM=`whoami`

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

set RASPBERRY_PI=1
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
		exit 1
	fi
fi

#------------------------------- Download/Update plugins --------------------------------------------

if [ "$M64P_COMPONENTS_FILE" -eq 1 ]; then
	for component in ${M64P_COMPONENTS}; do
		plugin=`echo "${component}" | cut -d , -f 1`
		repository=`echo "${component}" | cut -d , -f 2`
		branch=`echo "${component}" | cut -d , -f 3`

		if [ -z "$plugin" ]; then
			continue
		fi

		if [ -z "$repository" ]; then
			repository=$REPO
		fi

		if [ -z "$branch" ]; then
			branch="master"
		fi

		if [ ! -e "${BUILDDIR}/$repository/mupen64plus-${plugin}" ]; then
			echo "************************************ Downloading ${plugin} from ${repository} to ${BUILDDIR}/$repository/mupen64plus-${plugin}"
			git clone https://github.com/${repository}/mupen64plus-${plugin} ${BUILDDIR}/$repository/mupen64plus-${plugin}
		else
			cd $repository/mupen64plus-$plugin
			echo "checking $plugin from $repository is up-to-date"
			echo `git pull origin $branch `
			cd ../..
		fi
	done
fi

#----------------------------------- Build Symbolic Links ----------------------------------------

if [ 0 -eq 1 ]; then
if [ $M64P_COMPONENTS_FILE -eq 1 ]; then
	echo "Building Symbolic Links"
	for component in ${M64P_COMPONENTS}; do
		plugin=`echo "${component}" | cut -d , -f 1`
		repository=`echo "${component}" | cut -d , -f 2`

		if [ -z "$plugin" ]; then
			continue
		fi

		# build link to plugin in current directory
		ln -s -f $repository/mupen64plus-$plugin mupen64plus-$plugin

		if [ !"${plugin}" = "core" ]; then
			ln -s -f $repository/mupen64plus-core mupen64plus-core
		fi
	done
fi
fi

#-------------------------------------- set API Directory ----------------------------------------

for component in ${M64P_COMPONENTS}; do
	plugin=`echo "${component}" | cut -d , -f 1`
	repository=`echo "${component}" | cut -d , -f 2`

	if [ "${plugin}" = "core" ]; then
		set APIDIR="../../../../$repository/mupen64plus-core/src/api"
		break
	fi
done

#-------------------------------------- Change Branch --------------------------------------------

if [ $M64P_COMPONENTS_FILE -eq 1 ]; then
	for component in ${M64P_COMPONENTS}; do
		plugin=`echo "${component}" | cut -d , -f 1`
		repository=`echo "${component}" | cut -d , -f 2`
		branch=`echo "${component}" | cut -d , -f 3`

		if [ -z "$plugin" ]; then
			continue
		fi

		if [ -z "$branch" ]; then
			branch="master"
		fi

		cd $repository/mupen64plus-${plugin}
		currentBranch=`git branch | grep [*] | cut -b 3-;`
		
		if [ ! "$branch" = "$currentBranch" ]; then
			echo "************************************ Changing branch from ${currentBranch} to ${branch} for mupen64plus-${plugin}"
			git checkout $branch
		fi

		cd ../..
	done
fi

#--------------------------------------- Build plugins --------------------------------------------

for component in ${M64P_COMPONENTS}; do
	plugin=`echo "${component}" | cut -d , -f 1`
	repository=`echo "${component}" | cut -d , -f 2`

	if [ -z "$plugin" ]; then
		continue
	fi

	if [ "${plugin}" = "core" ]; then
		component_type="library"
	elif  [ "${plugin}" = "rom" ]; then
		if [ "$0" = "./build_test.sh" ]; then
			echo "************************************ Building test ROM"
			mkdir -p ./test/
			cp ${BUILDDIR}/$repository/mupen64plus-rom/m64p_test_rom.v64 ./test/
			continue
		fi
	elif  [ "${plugin}" = "ui-console" ]; then
		component_type="front-end"
	else
		component_type="plugin"
	fi

	echo "************************************ Building ${plugin} ${component_type}"
	
	"$MAKE" -C ${BUILDDIR}/$repository/mupen64plus-${plugin}/projects/unix clean $@
	"$MAKE" -C ${BUILDDIR}/$repository/mupen64plus-${plugin}/projects/unix all $@
	"$MAKE" -C ${BUILDDIR}/$repository/mupen64plus-${plugin}/projects/unix install $@ ${MAKE_INSTALL}


	mkdir -p ./test/doc
	for doc in LICENSES README RELEASE; do
		if [ -e "${BUILDDIR}/$repository/mupen64plus-${component}/${doc}" ]; then
			cp "${BUILDDIR}/$repository/mupen64plus-${plugin}/${doc}" "./test/doc/${doc}-mupen64plus-${plugin}"
		fi
	done
	for subdoc in gpl-license font-license lgpl-license module-api-versions.txt; do
		if [ -e "${BUILDDIR}/$repository/mupen64plus-${plugin}/doc/${subdoc}" ]; then
			cp "${BUILDDIR}/$repository/mupen64plus-${plugin}/doc/${subdoc}" ./test/doc/
		fi
	done
done
