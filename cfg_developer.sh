#!/bin/sh

# terminate the script if any commands return a non-zero error code
set -e

if [ "$1" = "-h" -o "$1" = "--help" ]; then
	echo "Script to set Username and email address for updating github repositories"
	echo "Usage:"
	echo "[Environment Vars] ./cfg-developer.sh"
	echo
	echo "Environment Variable options:"
	echo ""
	echo "    PLUGIN_FILE=[defaultList] File with List of plugins to build"
	echo ""

	exit 0
fi

defaultPluginList="defaultList"
read -p "Username: " USER
read -p "Email:    " EMAIL

if [ -n "$PLUGIN_FILE" ]; then
	defaultPluginList="$PLUGIN_FILE"
fi

#get file contents, ignore comments, blank lines and replace multiple tabs with single comma
M64P_COMPONENTS=`cat "$defaultPluginList" | grep -v -e '^#' -e '^$' | cut -d '#' -f 1 | sed -r 's:\t+:,:g'`

git config --global user.email "$USER"
git config --global user.name "$EMAIL"

for component in ${M64P_COMPONENTS}; do
	plugin=`echo "${component}" | cut -d , -f 1`
	repository=`echo "${component}" | cut -d , -f 2`
	upstream=`echo "${component}" | cut -d , -f 4`

	if [ -z "$plugin" ]; then
		continue
	fi

	echo "************************* $repository/mupen64plus-$plugin"
	
	cd $repository/mupen64plus-${plugin}
	
	echo "Setting user name and email"
	git config --global user.email "$USER"
	git config --global user.name "$EMAIL"

	if [ -n "$upstream" ]; then
		if [ `git remote | grep -c upstream` -eq 0 ]; then
			echo "Adding upstream respository to $repository/mupen64plus-${plugin}"
			git remote add upstream https://github.com/$upstream/mupen64plus-$plugin

			echo "Fetching $upstream/mupen64plus-$plugin"
			git fetch upstream
		fi
	fi
	cd ../..
done

#----------------------------------- Build Symbolic Links ----------------------------------------

if [ 1 -eq 1 ]; then
	echo "************************* Building Symbolic Links"
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

