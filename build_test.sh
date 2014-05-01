#!/bin/sh
#/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
# *   Mupen64plus - m64p_build.sh                                           *
# *   Mupen64Plus homepage: http://code.google.com/p/mupen64plus/           *
# *   Copyright (C) 2009 Richard Goedeken                                   *
# *                                                                         *
# *   This program is free software; you can redistribute it and/or modify  *
# *   it under the terms of the GNU General Public License as published by  *
# *   the Free Software Foundation; either version 2 of the License, or     *
# *   (at your option) any later version.                                   *
# *                                                                         *
# *   This program is distributed in the hope that it will be useful,       *
# *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
# *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
# *   GNU General Public License for more details.                          *
# *                                                                         *
# *   You should have received a copy of the GNU General Public License     *
# *   along with this program; if not, write to the                         *
# *   Free Software Foundation, Inc.,                                       *
# *   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.          *
# * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

# terminate the script if any commands return a non-zero error code
set -e

if [ -z "$MAKE" ]; then
	MAKE=make
fi

if [ -z "$M64P_COMPONENTS" ]; then
	M64P_COMPONENTS="ricrpi/core mupen64plus/rom mupen64plus/ui-console ricrpi/audio-omx ricrpi/input-sdl ricrpi/rsp-hle ricrpi/video-gles2rice ricrpi/video-gles2n64"
fi

#Set Environment Variable for compiling for RASPBERRY_PI
RASPBERRY_PI=1


mkdir -p ./test/
MAKE_INSTALL="PLUGINDIR= SHAREDIR= BINDIR= MANDIR= LIBDIR= INCDIR=api LDCONFIG=true "

for component in ${M64P_COMPONENTS}; do
	plugin=`echo "${component}" | cut -d / -f 2`
	repository=`echo "${component}" | cut -d / -f 1`

	if [ ! -e "./mupen64plus-${plugin}" ]; then
		echo "************************************ Downloading ${plugin} from ${repository}"
		git clone https://github.com/${repository}/mupen64plus-${plugin} ../mupen64plus-${plugin}
	fi

	if [ "${plugin}" = "core" ]; then
		component_type="library"
	elif  [ "${plugin}" = "rom" ]; then
		echo "************************************ Building test ROM"
		mkdir -p ./test/
		cp ./mupen64plus-rom/m64p_test_rom.v64 ./test/
		continue
	elif  [ "${plugin}" = "ui-console" ]; then
		component_type="front-end"
	else
		component_type="plugin"
	fi

	echo "************************************ Building ${plugin} ${component_type}"
	if [ -n "$CLEAN" ]; then
	"$MAKE" -C ./mupen64plus-${plugin}/projects/unix clean $@
	fi
	"$MAKE" -C ./mupen64plus-${plugin}/projects/unix all $@
	"$MAKE" -C ./mupen64plus-${plugin}/projects/unix install $@ ${MAKE_INSTALL} DESTDIR="$(pwd)/test/"

	mkdir -p ./test/doc
	for doc in LICENSES README RELEASE; do
		if [ -e "./mupen64plus-${component}/${doc}" ]; then
			cp "./mupen64plus-${plugin}/${doc}" "./test/doc/${doc}-mupen64plus-${plugin}"
		fi
	done
	for subdoc in gpl-license font-license lgpl-license module-api-versions.txt; do
		if [ -e "./mupen64plus-${plugin}/doc/${subdoc}" ]; then
			cp "./mupen64plus-${plugin}/doc/${subdoc}" ./test/doc/
		fi
	done
done
