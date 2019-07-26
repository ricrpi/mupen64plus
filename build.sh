#!/bin/bash

# terminate the script if any commands return a non-zero error code
set -e

if [ "$1" = "-h" -o "$1" = "--help" ]; then
	echo "Mupen64plus installer for the Raspberry PI"
	echo "Usage:"
	echo "[Environment Vars] ./buid.sh [defaultList]"
	echo
	echo "Environment Variable options:"
	echo ""
	echo "    CLEAN=[1]                    Clean before build"
	echo "    DEBUG=[0]                    Compile for Debugging"
	echo "    DEV=[0]                      Development build - installs into ./test"
	echo "    GCC=[8]                      Version of gcc to use"
	echo "    MAKE=[make]                  Make Utility to use"
	echo "    COMP=                        The list of components to download and build"
	echo "                                 The default is to read ./pluginList. "
	echo "                                 One can specify the plugin names e.g. 'core'."
	echo "                                 This will override automatic changing of the branch"
	echo "    BUILDDIR=[./] | PREFIX=[./]  Directory to download and build plugins in"
	echo "    REPO=[mupen64plus]           Default repository from https://github.com"
	echo "    CLEAN_SDL2=[0]               Clean SDL2 build"
	echo "    CHECK_SDL2=[1]               Perform a compatibility check on SDL2"
	echo "    X11=[0|1|2]                  X11 / SDL support:"
	echo "                                 0 = if SDL already installed then use its config"
	echo "                                     else build with no X11 support"
	echo "                                 1 = force build with X11 support "
	echo "                                     - mupen64plus must always be run with X"
	echo "                                 2 = force build with no X11 support"
	echo "                                     - mupen64plus runs slightly faster"
	echo "                                 NOTE: running script as root may update SDL libs"
	echo ""

	exit 0
fi


#-------------- User Configurable --------------------------------------------------

MEM_REQ=750			# The number of M bytes of memory required to build

SDL2="SDL2-2.0.3"		# SDL Library version
SDL_CFG="--disable-video-opengl "

#------------ Defaults -----------------------------------------------------------

if [ -z "$defaultPluginList"]; then
	PLATFORM=`uname -m`
	#the default file to read the git repository list from
	if [ "$PLATFORM" = "armv6l" ]; then
		expectedPluginList="RaspbianList"
	elif [ "$PLATFORM" = "armv7l" ]; then
		expectedPluginList="RaspbianList_Pi2"
	else
		expectedPluginList="x86List"
	fi
	if [ `readlink -- defaultList` != "$expectedPluginList" ]; then
		echo "Expected defaultList -> $expectedPluginList but got:"
		ls -la defaultList
		echo "Please change this symbolic link"
		exit -1
	fi

	defaultPluginList="defaultList"
fi

if [ -z "$CHECK_SDL2" ]; then
	CHECK_SDL2=1
fi

if [ -z "$GCC" ]; then
	GCC=8
fi

if [ -z "$MAKE_SDL2" ]; then
	MAKE_SDL2="0"
fi

if [ -z "$COREDIR" ]; then
	COREDIR="/usr/local/lib/"
fi

if [ -z "$MAKE_SDL2" ]; then
	MAKE_SDL2="0"
fi

if [ -z "$CLEAN" ]; then
	CLEAN="1"
fi

if [ -z "$X11" ]; then
	X11="0"
fi


if [ "$X11" == "1" ]; then
	SDL_CFG="$SDL_CFG --enable-video-x11 "
else
	SDL_CFG="$SDL_CFG --disable-video-x11 "
fi

if [ "$V" = "1" ]; then
	exec 3>&1
else
	exec 3>/dev/null
fi

if [ -z "$DEV" ]; then
	DEV="0"
fi

# check for build script updates
if [ "$DEV" = "0" ]; then
	# update this installer
	RESULT=`git pull origin`
	echo "$RESULT" >&3

	if [[ $RESULT != "Already up"* ]]; then
		echo ""
		echo "    Installer updated. Please re-run build.sh"
		echo ""
		exit
	fi
fi

IAM=`whoami`
GPU=0
MAKE_INSTALL="PLUGINDIR= SHAREDIR= BINDIR= MANDIR= LIBDIR= INCDIR=api LDCONFIG=true"
PATH=$PWD:$PATH			# Add the current directory to $PATH so we can override gcc/g++ version

#-------------------------------------------------------------------------------

DO_UPDATE=1
apt_update()
{
	if [ "$DO_UPDATE" = "1" ] && [ "$IAM" = "root" ]; then
		apt-get update
	fi
	DO_UPDATE="0"
}

#------------------- set some variables ----------------------------------------

if [ -n "$PREFIX" ]; then
	BUILDDIR="$PREFIX"
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
M64P_COMPONENTS=`cat "${defaultPluginList}" | grep -v -e '^#' -e '^$' | cut -d '#' -f 1 | sed -r 's:\t+:,:g'`

if [ -z "${BUILDDIR}" ]; then
	BUILDDIR=`pwd`
fi


if [ ! -d "${BUILDDIR}" ]; then
	mkdir "${BUILDDIR}"
fi

if [ -z "${REPO}" ]; then
	REPO="mupen64plus"
fi

#------------------------------- Raspberry PI firmware -----------------------------------

if [ 0 -eq 1 ]; then
	if [ ! -d "/opt/vc" ]; then
		git clone --depth 1 "https://github.com/raspberrypi/firmware"
		if [ "$IAM" = "root" ]; then
			cp -R -f "${BUILDDIR}/firmware/opt/vc" "/opt"
		else
			echo "You need to run this script with sudo/root or copy the Videocore firmware drivers using 'sudo cp -R -f \"${BUILDDIR}/firmware/opt/vc\" /opt'"
			exit 1
		fi
	fi
fi

#------------------------------- GCC compiler --------------------------------------------


if [ "$IAM" = "root" ]; then
	if [ ! -e "/usr/bin/gcc-$GCC" ]; then
		echo "************************************ Downloading/Installing GCC $GCC"
		apt_update
		apt-get install gcc-$GCC
	fi
	if [ ! -e "/usr/bin/g++-$GCC" ]; then
		echo "************************************ Downloading/Installing G++ $GCC"
		apt_update
		apt-get install g++-$GCC
	fi
else
	if [ ! -e "/usr/bin/gcc-$GCC" ]; then
		echo "You should install the GCC $GCC compiler"
		echo "Either run this script with sudo/root or run 'apt-get install gcc-$GCC'"
		exit 1
	fi
	if [ ! -e "/usr/bin/g++-$GCC" ]; then
		echo "You should install the G++ $GCC compiler"
		echo "Either run this script with sudo/root or run 'apt-get install g++-$GCC'"
		exit 1
	fi
fi

if [ -e "/usr/bin/gcc-$GCC" ]; then
	ln -f -s /usr/bin/gcc-$GCC gcc
fi

if [ -e "/usr/bin/g++-$GCC" ]; then
	ln -f -s /usr/bin/g++-$GCC g++
fi

#------------------------------- SDL dev libraries --------------------------------------------

if [ "$CHECK_SDL2" = "1" ]; then
	DOWNLOAD_SDL2=1
	BUILD_SDL2=1

	# discover SDL2 prefix, if it is present
	set +e
	SDL2_LOCATION=`sdl2-config --prefix 2>/dev/null`
	set -e

	# check existing installation
	if [ -e "$SDL2_LOCATION/include/SDL2/SDL_config.h" ]; then
		set +e
		SDL_VIDEO_ES2=`grep -c "#define SDL_VIDEO_OPENGL_ES2\ 1" $SDL2_LOCATION/include/SDL2/SDL_config.h`
		SDL_VIDEO_X11=`grep -c "#define SDL_VIDEO_DRIVER_X11\ 1" $SDL2_LOCATION/include/SDL2/SDL_config.h`
		SDL_VIDEO_RPI=`grep -c "#define SDL_VIDEO_DRIVER_RPI\ 1" $SDL2_LOCATION/include/SDL2/SDL_config.h`
		set -e

		#if SDL was configured with GLES V2 support
		if [ "$SDL_VIDEO_ES2" != "" ]; then
			BUILD_SDL2=0
		fi

		if [ "$X11" == "1" ] && [ "$SDL_VIDEO_X11" != "1" ]; then
			BUILD_SDL2=1
		fi

		if [ "$X11" == "2" ] && [ "$SDL_VIDEO_X11" != "0" ]; then
			BUILD_SDL2=1
		fi

		if [ "$SDL_VIDEO_RPI" == "0" ]; then
			echo "SDL2 is missing the Raspberry PI Driver. You will not be able to run mupen64plus in the console."
			sleep 5
		fi
	fi

	if [ -e "${BUILDDIR}/${SDL2}" ]; then
		DOWNLOAD_SDL2=0
	fi

	if [ "$BUILD_SDL2" == "1" ] && [ "$DOWNLOAD_SDL2" = "1" ]; then
		pushd "${BUILDDIR}"
		echo "************************************ Downloading SDL2"
		wget http://www.libsdl.org/release/$SDL2.tar.gz
		tar -zxf $SDL2.tar.gz
		popd
	fi

	if [ "$BUILD_SDL2" == "1" ]; then
		pushd ${BUILDDIR}/${SDL2}

		if [ -e "Makefile" ] && [ "$CLEAN_SDL2" = "1" ]; then
			echo "************************************ Cleaning SDL2 Source"
			make clean
			make distclean
		fi

		CONFIGURE_SDL2=1

		#check to see if local build is configured correctly. A make distclean will remove config.status but not SDL_config.h
		if [ -e "include/SDL_config.h" ] && [ -e "config.status" ]; then
			set +e
			SDL_VIDEO_ES2=`grep -c "#define SDL_VIDEO_OPENGL_ES2\ 1" include/SDL_config.h`
			SDL_VIDEO_X11=`grep -c "#define SDL_VIDEO_DRIVER_X11\ 1" include/SDL_config.h`
			set -e

			#if SDL was configured with GLES V2 support
			if [ "$SDL_VIDEO_ES2" != "" ]; then
				CONFIGURE_SDL2=0
			fi

			if [ "$X11" == "1" ] && [ "$SDL_VIDEO_X11" != "1" ]; then
				CONFIGURE_SDL2=1
			fi
			if [ "$X11" == "2" ] && [ "$SDL_VIDEO_X11" != "0" ]; then
				CONFIGURE_SDL2=1
			fi
		fi

		if [ "$CONFIGURE_SDL2" == "1" ]; then
			echo "************************************ Configuring SDL2"
			echo "./configure $SDL_CFG"
			./configure $SDL_CFG
		fi

		# Check to see if previous build was done before configure.
		# This should save users some time if the script was run without root and failed to install
		if [ -e "${BUILDDIR}/${SDL2}/build/.libs/libSDL2.so" ]; then
			if [ `stat -c %Y "${BUILDDIR}/${SDL2}/build/.libs/libSDL2.so"` -lt `stat -c %Y "${BUILDDIR}/${SDL2}/config.status"` ]; then
				echo "************************************ Building SDL2"
				make
			fi
		else
			echo "************************************ Building SDL2"
			make
		fi

		if [ "$IAM" = "root" ]; then
			echo "************************************ Install SDL2"
			make install prefix=$SDL2_LOCATION
		else
			echo "You need to install SDL2 libraries"
			echo "Either run this script with sudo/root or run 'pushd ${BUILDDIR}/$SDL2; sudo make install prefix=$SDL2_LOCATION; popd'"
			exit 1
		fi
		popd
	fi

	# we could statically link by using the following:
	#SDL_CFLAGS="-I${BUILDDIR}/${SDL2}/include -I/opt/vc/include -I/opt/vc/include/interface/vcos/pthreads -I/opt/vc/include/interface/vmcs_host/linux -D_REENTRANT "
	#SDL_LDLIBS="${BUILDDIR}/${SDL2}/build/.libs/libSDL2.a -Wl,-rpath,/usr/local/lib -lpthread "
	#SDL_CFLAGS=`sdl2-config --cflags`
  	#SDL_LDLIBS=`sdl2-config --libs`
fi

#------------------------------- Setup Information to debug problems --------------------------------

if [ 1 -eq 1 ]; then
	echo ""
	echo "--------------- Setup Information -------------"
	git --version
	free -h
	gcc -v 2>&1 | tail -n 1
#	g++ -v 2>&1 | tail -n 1
	GCC=`gcc -v 2>&1 | tail -n 1 | cut -d " " -f 3`

	RESULT=`git log -n 1 | head -n 1`
	echo "Build script: $RESULT"

	# output video core IV binary version
	vcgencmd version

	echo "DEV: $DEV"

	echo "SDL2 `sdl2-config --version` located at $SDL2_LOCATION"

	if [ -e "/boot/config.txt" ]; then
		set +e
		GPU_SET=`grep -c gpu_mem /boot/config.txt`
		set -e

		if [ "$GPU_SET" = "1" ]; then
			cat /boot/config.txt | grep "gpu_mem"
			GPU=`cat /boot/config.txt | grep "gpu_mem" | cut -d "=" -f 2`
		else
			echo "gpu_mem not set in /boot/config.txt"
		fi
	fi

	uname -a

	if [ -e "/etc/issue" ]; then
		cat /etc/issue
	fi

	echo "-----------------------------------------------"
fi

#------------------------------- Download/Update plugins --------------------------------------------

IFS=`echo -e "\t\n\f"`
for component in ${M64P_COMPONENTS}; do
	plugin=`echo "${component}" | cut -d , -f 1`
	repository=`echo "${component}" | cut -d , -f 2`
	branch=`echo "${component}" | cut -d , -f 3`
	upstream=`echo "${component}" | cut -d , -f 4`

	if [ -z "$plugin" ]; then
		continue
	fi

	#If COMP is set and does not contain the plugin name then skip building it
	if [ -n "$COMP" ]; then
		if [[ "$COMP" != *"$plugin"* ]]; then
			continue
		fi
	fi

	if [ -z "$repository" ]; then
		repository=$REPO
	fi

	if [ -z "$branch" ]; then
		branch="master"
	fi

	IFS=`echo -e "\t\n\f "`

	if [ ! -e "${BUILDDIR}/$repository/mupen64plus-${plugin}" ]; then
		if [ "$DEV" = "0" ]; then
			CLONE_DEPTH=" --depth 1 --branch $branch"
		fi

		echo "************************************ Downloading ${plugin} from ${repository} to ${BUILDDIR}/$repository/mupen64plus-${plugin}"
		git clone $CLONE_DEPTH https://github.com/${repository}/mupen64plus-${plugin} ${BUILDDIR}/$repository/mupen64plus-${plugin}

		if [ "$DEV" = "1" ]; then
			pushd "${BUILDDIR}/$repository/mupen64plus-${plugin}" >&3
			git checkout $branch
			popd >&3
		fi
	else
		if [ "$DEV" = "0" ]; then
			pushd "${BUILDDIR}/$repository/mupen64plus-$plugin" >&3
			echo "checking $plugin from $repository is up-to-date"
			echo `git pull origin $branch`
			popd >&3
		fi
	fi

	if [ -n "$upstream" ] && [ "$DEV" = "1" ]; then
               	pushd ${BUILDDIR}/$repository/mupen64plus-$plugin >&3
		current=`git remote | grep upstream`
		if [ "$current" = "" ]; then
                	echo "Setting upstream remote on $repository to $upstream"
                	git remote add upstream https://github.com/$upstream/mupen64plus-$plugin
		fi
            	git fetch upstream
        	popd >&3
    	fi
	IFS=`echo -e "\t\n\f"`
done

#-------------------------------------- set API Directory ----------------------------------------

for component in ${M64P_COMPONENTS}; do
	plugin=`echo "${component}" | cut -d , -f 1`
	repository=`echo "${component}" | cut -d , -f 2`

	if [ "$plugin" = "core" ]; then
		APIDIR="../../../../$repository/mupen64plus-core/src/api"
		break
	fi
done

#-------------------------------------- Change Branch --------------------------------------------

for component in ${M64P_COMPONENTS}; do
	plugin=`echo "${component}" | cut -d , -f 1`
	repository=`echo "${component}" | cut -d , -f 2`
	branch=`echo "${component}" | cut -d , -f 3`

	if [ -z "$plugin" ]; then
		continue
	fi

	#If COMP is set and does not contain the plugin name then skip building it
	if [ -n "$COMP" ]; then
		if [[ "$COMP" != *"$plugin"* ]]; then
			continue
		fi
	fi

	if [ -z "$branch" ]; then
		branch="master"
	fi

	IFS=`echo -e "\t\n\f "`

	if [ "$DEV" = "0" ]; then
		pushd "${BUILDDIR}/$repository/mupen64plus-${plugin}" >&3

		currentBranch=`git branch | grep [*] | cut -b 3-;`
		if [ ! "$branch" = "$currentBranch" ]; then
			echo "************************************ Changing branch from ${currentBranch} to ${branch} for mupen64plus-${plugin}"
			git checkout $branch
		fi
		popd >&3
	fi

	IFS=`echo -e "\t\n\f"`
done

IFS=`echo -e "\t\n\f "`

#--------------------------------------- Check free memory --------------------------------------------


RESULT=`free -m -t | grep "Total:" | sed -r 's: +:\t:g' | cut -f 2`

if [ $RESULT -lt $MEM_REQ ]; then
	echo "Not enough memory to build"

	#does /etc/dphys-swapfile specify a value?
	if [ -e "/etc/dphys-swapfile" ]; then
		SWAP_RESULT="grep CONF_SWAPSIZE /etc/dphys-swapfile"

		RESULT=`free -m | grep "Mem:" | sed -r 's: +:\t:g' | cut -f 2`

		REQ=`expr $MEM_REQ - $RESULT`

		if [ `echo "$SWAP_RESULT" | cut -c1 ` = "#" ]; then
			echo "Please enable CONF_SWAPSIZE=$REQ in /etc/dphys-swapfile and run 'sudo dphys-swapfile setup; sudo reboot'"
		else
			echo "Please set CONF_SWAPSIZE to >= $REQ in /etc/dphys-swapfile and run 'sudo dphys-swapfile setup; sudo reboot'"
		fi
	fi
	exit
fi

#--------------------------------------- Build plugins --------------------------------------------

IFS=`echo -e "\t\n\f"`
for component in ${M64P_COMPONENTS}; do
	plugin=`echo "${component}" | cut -d , -f 1`
	repository=`echo "${component}" | cut -d , -f 2`
	flags=`echo "${component}" | cut -d , -f 5- | sed -r 's:,:\ :g'`

	if [ -z "$plugin" ]; then
		continue
	fi

	#If COMP is set and does not contain the plugin name then skip building it
	if [ -n "$COMP" ]; then
		if [[ "$COMP" != *"$plugin"* ]]; then
			continue
		fi
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

	echo "************************************ Building ${plugin} ${component_type}"

	IFS=`echo -e "\t\n\f "`

	# Buster: sh -c retains quotes within $flags, namely for OPTFLAGS="-mflto -mfpu-neon"
	if [ "$CLEAN" = "1" ]; then
		sh -c "$MAKE -C ${BUILDDIR}/$repository/mupen64plus-${plugin}/projects/unix clean"
	fi

	#if this is the console then do a clean so that COREDIR will be compiled correctly
	if [ "$CLEAN" = "0" ] && [ "${plugin}" = "ui-console" ]; then
		`touch "${BUILDDIR}"/$repository/mupen64plus-ui-console/src/core_interface.c`
	fi

	# In ricrpi/mupen64plus-core we cannot compile with -03 on pi however some 03 optimizations can be applied i.e.
	# RPIFLAGS ?= -fgcse-after-reload -finline-functions -fipa-cp-clone -funswitch-loops -fpredictive-commoning -ftree-loop-distribute-patterns -ftree-vectorize
	# These break in versions < 4.7.3 so override RPIFLAGS
	if [ `echo "$GCC 4.7.3" | awk '{print ($1 < $2)}'` -eq 1 ]; then
		if [ "$V" = "1" ]; then
			echo "$> $MAKE -C ${BUILDDIR}/$repository/mupen64plus-${plugin}/projects/unix all $flags COREDIR=$COREDIR RPIFLAGS=\" \""
		fi
		sh -c "$MAKE -C ${BUILDDIR}/$repository/mupen64plus-${plugin}/projects/unix all $flags COREDIR=$COREDIR RPIFLAGS=\" \""
	else
		if [ "$V" = "1" ]; then
			echo "$> $MAKE -C ${BUILDDIR}/$repository/mupen64plus-${plugin}/projects/unix all $flags COREDIR=$COREDIR"
		fi
		sh -c "$MAKE -C ${BUILDDIR}/$repository/mupen64plus-${plugin}/projects/unix $flags COREDIR=$COREDIR all"
	fi

	# dev_build can install into test folder
	if [ "$DEV" = "1" ]; then
		if [ "$V" = "1" ]; then
			echo "$MAKE -C ${BUILDDIR}/$repository/mupen64plus-${plugin}/projects/unix install $flags ${MAKE_INSTALL} DESTDIR=\"${BUILDDIR}/test\""
		fi
		sh -c "$MAKE -C ${BUILDDIR}/$repository/mupen64plus-${plugin}/projects/unix install $flags ${MAKE_INSTALL} DESTDIR=\"${BUILDDIR}/test\""
	fi

	IFS=`echo -e "\t\n\f"`
done
