#!/bin/bash

# terminate the script if any commands return a non-zero error code
set -e

if [ "$1" = "-h" -o "$1" = "--help" ]; then
	echo "Mupen64plus installer for the Raspberry PI"
	echo "Usage:"
	echo "[Environment Vars] ./buid_test.sh [makefile targets]"
	echo
	echo "Environment Variable options:"
	echo ""
	echo "    CLEAN=[1]                    Clean before build"
	echo "    MAKE=[make]                  Make Utility to use"
	echo "    M64P_COMPONENTS=             The list of components to download and build"
	echo "                                 The default is to read ./pluginList. "
	echo "                                 One can specify the plugin names e.g. 'core'."
	echo "                                 This will override automatic changing of the branch"
	echo "    PLUGIN_FILE=[defaultList]    File with List of plugins to build"
	echo "    BUILDDIR=[./] | PREFIX=[./]  Directory to download and build plugins in"
	echo "    REPO=[mupen64plus]           Default repository on https://github.com"
	
	echo ""

	exit 0
fi

#-------------------------------------------------------------------------------

defaultPluginList="defaultList"	
PATH=$PWD:$PATH			# Add the current directory to $PATH
MEM_REQ=750			# The number of M bytes of memory required to build 
USE_SDL2=0			# Use SDL2?
SDL2="SDL2-2.0.3"		# SDL Library version
IAM=`whoami`
M64P_COMPONENTS_FILE=0
GPU=0
GCC_VERSION=4.7
MAKE_INSTALL="PLUGINDIR= SHAREDIR= BINDIR= MANDIR= LIBDIR= INCDIR=api LDCONFIG=true"

set RASPBERRY_PI=1

#-------------------------------------------------------------------------------

DO_UPDATE=1
apt_update()
{
	if [ $DO_UPDATE -eq 1 -a "$IAM" = "root" ]; then
		apt-get update
		
	fi
	DO_UPDATE=0
}

#------------------- set some variables ----------------------------------------

if [ -n "$PREFIX" ]; then
	BUILDDIR="$PREFIX"
fi

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

if [ ! -d "$BUILDDIR"]; then
	mkdir "$BUILDDIR"
fi

if [ -z "$REPO" ]; then
	REPO="mupen64plus"
fi

#------------------------------- GCC compiler --------------------------------------------


if [ "$IAM" = "root" ]; then
	if [ ! -e "/usr/bin/gcc-$GCC_VERSION" ]; then
		echo "************************************ Downloading/Installing GCC $GCC_VERSION"
		apt_update
		apt-get install gcc-$GCC_VERSION
	fi
	if [ ! -e "/usr/bin/g++-$GCC_VERSION" ]; then
		echo "************************************ Downloading/Installing G++ $GCC_VERSION"
		apt_update
		apt-get install g++-$GCC_VERSION
	fi
else
	if [ ! -e "/usr/bin/gcc-$GCC_VERSION" ]; then
		echo "You should install the GCC $GCC_VERSION compiler"
		echo "Either run this script with sudo/root or run 'apt-get install gcc-$GCC_VERSION'"
		exit 1
	fi
	if [ ! -e "/usr/bin/g++-$GCC_VERSION" ]; then
		echo "You should install the G++ $GCC_VERSION compiler"
		echo "Either run this script with sudo/root or run 'apt-get install g++-$GCC_VERSION'"
		exit 1
	fi
fi

if [ -e "/usr/bin/gcc-$GCC_VERSION" ]; then
	ln -f -s /usr/bin/gcc-$GCC_VERSION gcc
fi

if [ -e "/usr/bin/g++-$GCC_VERSION" ]; then
	ln -f -s /usr/bin/g++-$GCC_VERSION g++
fi

#------------------------------- SDL dev libraries --------------------------------------------

if [ $USE_SDL2 -eq 1 ]; then
	if [ "$IAM" = "root" ]; then
		if [ ! -e "/usr/local/lib/libSDL2.so" ]; then
			echo "************************************ Downloading/Building/Installing SDL2"
			
			pushd "${BUILDDIR}"
			
			if [ ! -e "${BUILDDIR}/$SDL2" ]; then
				wget http://www.libsdl.org/release/$SDL2.tar.gz
				tar -zxf $SDL2.tar.gz
			fi

			cd $SDL2
			./configure
			make
			make install
			cd ..
			popd
		fi
	else
		if [ ! -e "/usr/local/lib/libSDL2.so" ]; then
			echo "************************************ Downloading/Building/Installing SDL2"
			
			pushd "${BUILDDIR}"
			
			if [ ! -e "${BUILDDIR}/$SDL2" ]; then
				wget http://www.libsdl.org/release/$SDL2.tar.gz
				tar -zxf $SDL2.tar.gz
			fi

			cd $SDL2
			./configure
			make
			cd ..
			popd

			echo "You need to install SDL2 development libraries"
			echo "Either run this script with sudo/root or run 'pushd ${BUILDDIR}/$SDL2; make install; popd'"
			exit 1
		fi
	fi
	# Override mupen64-core Makefile SDL
	SDL_CFLAGS=`sdl2-config --cflags`
  	SDL_LDLIBS=`sdl2-config --libs`
else
	if [ "$IAM" = "root" ]; then
		if [ ! -e "/usr/bin/sdl-config" ]; then
			echo "************************************ Downloading/Installing SDL"
			apt_update
			apt-get install -y libsdl1.2-dev
		fi
	else
		if [ ! -e "/usr/bin/sdl-config" ]; then
			echo "You need to install SDL development libraries"
			echo "Either run this script with sudo/root or run 'apt-get install libsdl1.2-dev'"
			exit 1
		fi
	fi
  	SDL_CFLAGS=`sdl-config --cflags`
  	SDL_LDLIBS=`sdl-config --libs`
fi

#------------------------------- Setup Information to debug problems --------------------------------

if [ 1 -eq 1 ]; then
	echo ""
	echo "--------------- Setup Information -------------"
	git --version
	free -h
	gcc -v 2>&1 | tail -n 1
#	g++ -v 2>&1 | tail -n 1
	GCC_VERSION=`gcc -v 2>&1 | tail -n 1 | cut -d " " -f 3`

	RESULT=`git log -n 1 | head -n 1`
	echo "Build script: $RESULT"

	#Check what is being built"
	RESULT=`git diff --name-only defaultList | wc -l`
	if [ $RESULT -eq 1 -o -n "$PLUGIN_LIST" ]; then
		echo "Using Modifed List"
#		echo "--------------------------"
#		cat "$defaultPluginList"
#		echo "--------------------------"
	else
		echo "Using DefaultList"
	fi

	if [ $USE_SDL2 -eq 1 -a -e "/usr/local/bin/sdl2-config" ]; then
		echo "Using SDL 2"
	else
		if [ -e "/usr/bin/sdl-config" ]; then
			echo "Using SDL1.2"
		else
			echo "Unknown SDL setup"
		fi
	fi

	if [ -e "/boot/config.txt" ]; then
		cat /boot/config.txt | grep "gpu_mem"
		GPU=`cat /boot/config.txt | grep "gpu_mem" | cut -d "=" -f 2`
	fi

	uname -a

	if [ -e "/etc/issue" ]; then
		cat /etc/issue
	fi

	echo "-----------------------------------------------"
fi

#------------------------------- Download/Update plugins --------------------------------------------

if [ 1 -eq 1 ]; then
	# update this installer
	RESULT=`git pull origin`

	if [ "$RESULT" != "Already up-to-date." ]; then
		echo ""
		echo "    Installer updated. Please re-run build.sh"
		echo ""
		exit
	fi
fi

if [ $M64P_COMPONENTS_FILE -eq 1 ]; then
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
			pushd "${BUILDDIR}/$repository/mupen64plus-$plugin"
			echo "checking $plugin from $repository is up-to-date"
			echo `git pull origin $branch `
			popd
		fi
	done
fi

#-------------------------------------- set API Directory ----------------------------------------
if [ $M64P_COMPONENTS_FILE -eq 1 ]; then
for component in ${M64P_COMPONENTS}; do
	plugin=`echo "${component}" | cut -d , -f 1`
	repository=`echo "${component}" | cut -d , -f 2`

	if [ "$plugin" = "core" ]; then
		set APIDIR="../../../../$repository/mupen64plus-core/src/api"
		break
	fi
done
else
set APIDIR="../../../../mupen64plus-core/src/api"
fi

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

		if [ $M64P_COMPONENTS_FILE -eq 0 ]; then
		repository="."
		fi

		pushd "${BUILDDIR}/$repository/mupen64plus-${plugin}"
		currentBranch=`git branch | grep [*] | cut -b 3-;`

		if [ ! "$branch" = "$currentBranch" ]; then
			echo "************************************ Changing branch from ${currentBranch} to ${branch} for mupen64plus-${plugin}"
			git checkout $branch
		fi

		popd
	done
fi
#--------------------------------------- Check free memory --------------------------------------------

RESULT=`free -m -t | grep "Total:" | sed -r 's: +:\t:g' | cut -f 2`

if [ $RESULT -lt $MEM_REQ ]; then
	echo "Not enough memory to build"

	#does /etc/dphys-swapfile specify a value?
	SWAP_RESULT="grep CONF_SWAPSIZE /etc/dphys-swapfile"
	REQ=`expr $MEM_REQ - $RESULT`

	if [ `echo "$SWAP_RESULT" | cut -c1 ` = "#" ]; then
		echo "Please enable CONF_SWAPSIZE=$REQ in /etc/dphys-swapfile and run 'sudo dphys-swapfile setup; sudo reboot'"
	else
		echo "Please set CONF_SWAPSIZE to >= $REQ in /etc/dphys-swapfile and run 'sudo dphys-swapfile setup; sudo reboot'"
	fi

	exit
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
		continue

	elif  [ "${plugin}" = "ui-console" ]; then
		component_type="front-end"
	else
		component_type="plugin"
	fi

	if [ $M64P_COMPONENTS_FILE -eq 0 ]; then
		repository="."
	fi

	echo "************************************ Building ${plugin} ${component_type}"

	if [ $CLEAN -gt 0 ]; then
		"$MAKE" -C ${BUILDDIR}/$repository/mupen64plus-${plugin}/projects/unix clean $@
	fi

	if [ `echo "$GCC_VERSION 4.7.3" | awk '{print ($1 < $2)}'` -eq 1 ]; then
		"$MAKE" -C ${BUILDDIR}/$repository/mupen64plus-${plugin}/projects/unix all $@ COREDIR="/usr/local/lib/" RPIFLAGS=" " SDL_CFLAGS="$SDL_CFLAGS" SDL_LDLIBS="$SDL_LDLIBS"
	else
		"$MAKE" -C ${BUILDDIR}/$repository/mupen64plus-${plugin}/projects/unix all $@ COREDIR="/usr/local/lib/" SDL_CFLAGS="$SDL_CFLAGS" SDL_LDLIBS="$SDL_LDLIBS"
	fi
done
