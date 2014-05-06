#!/bin/sh

# terminate the script if any commands return a non-zero error code
set -e

if [ "$1" = "-h" -o "$1" = "--help" ]; then
	echo "Script to set remote URL for updating github repositories using SSH"
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

for component in ${M64P_COMPONENTS}; do
	plugin=`echo "${component}" | cut -d , -f 1`
	repository=`echo "${component}" | cut -d , -f 2`
	
	if [ -z "$plugin" ]; then
		continue
	fi

	cd $repository/mupen64plus-${plugin}
	
	NEW_REMOTE=`git remote -v | cut -f 2 | grep "fetch" | cut -d '(' -f 1 | sed -r 's:https\://github\.com/:git@github.com\::g'`
	git remote  set-url origin "$NEW_REMOTE"
	cd ../..
done

