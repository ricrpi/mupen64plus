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

if [ -n "$PLUGIN_FILE" ]; then
	defaultPluginList="$PLUGIN_FILE"
fi

#get file contents, ignore comments, blank lines and replace multiple tabs with single comma
M64P_COMPONENTS=`cat "$defaultPluginList" | grep -v -e '^#' -e '^$' | cut -d '#' -f 1 | sed -r 's:\t+:,:g'`

read -p "Username: " USER
read -p "Email:    " EMAIL

for component in ${M64P_COMPONENTS}; do
	plugin=`echo "${component}" | cut -d , -f 1`
	repository=`echo "${component}" | cut -d , -f 2`
	
	if [ -z "$plugin" ]; then
		continue
	fi

	cd $repository/mupen64plus-${plugin}
	
	git config --global user.email "$USER"
	git config --global user.name "$EMAIL"

	cd ../..
done

