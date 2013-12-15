#!/bin/bash

# #################### Bundle up! #########################
#
# A simple differential backup utility based on git bundles
#
# This utility creates git bundles that are timestamped and
# that contain history hash refs. To unbundle one would simply
# download all the bundles and run the following in a new
# repository:
#
#	find .. -name '*.bundle' | sort | xargs -n1 -I'{}' git pull {} master
#
# This will reassemble all the bundles into the repository.
# Manual assembly may be required if one of the bundles is lost,
# so please be careful with storage.
#
# The script will try to source a backup.conf file from the
# current pwd. This can be overriden by supplying the
# BACKUP_CONFIG_PATH variable.
#
# Setting the BACKUP_REPOSITORY_PATH is also possible. By default
# this is the .backup directory of the current pwd.
#
# There are several functions that you need to override:
#
#	post_create_repository - called when a repository is
#		initialized for the first time. You can set git
#		configurations, optimizations, ignores, large file
#		handling rules, etc.
#	cleanup - called when the repository needs to be reset
#		to an empty state. By default calls rm -rf. Override
#		if needed.
#	do_backup - called when files need to be copied over.
#		Do anything you want at this point.	
#	process_bundle - is called with the bundle name as its
#		one and only agrument. Use this to upload the bundle
#		to anywhere you want it to be.
#

set -e
set -x

BACKUP_REPOSITORY_PATH=${BACKUP_REPOSITORY_PATH:-`pwd`/.backup}
BACKUP_CONFIG_PATH=${BACKUP_CONFIG_PATH:-`pwd`/backup.conf}
REDUNDANCY=${REDUNDANCY:-"3"}

if [ -f "$BACKUP_CONFIG_PATH" ]; then
	source "$BACKUP_CONFIG_PATH"
fi

if [ ! `type post_create_repository` ]; then
	post_create_repository() {
		echo "Running some default setups on the repository"
	}
fi

if [ ! `type do_backup` ]; then
	do_backup() {
		echo "Backing up!"
	}
fi

if [ ! `type cleanup` ]; then
	cleanup() {
		rm -rf *
	}
fi

if [ ! `type process_bundle` ]; then
	process_bundle() {
		echo "Created bundle $1. Upload as necessary."
	}
fi

echo `date`
echo "Starting backup utility..."

if [ ! -d "$BACKUP_REPOSITORY_PATH" ]; then
	echo "** Warning: backup repository path $BACKUP_REPOSITORY_PATH does not exist. Creating..." 1>&2;
	mkdir -p $BACKUP_REPOSITORY_PATH
fi

cd $BACKUP_REPOSITORY_PATH

if [ "`git rev-parse --show-toplevel`" != "$BACKUP_REPOSITORY_PATH" ]; then
	echo "** No repository detected in $BACKUP_REPOSITORY_PATH. Creating..." 1>&2;
	git init
	mkdir - .git/bundles
	post_create_repository
fi

cleanup
do_backup

git add -A
if [ "`git diff --cached --name-only`" ]; then
	git commit -m "Automated backup `date`" --author="`whoami` <`whoami`@`hostname`>"

	CURRENT_CHECKPOINT=`git rev-parse --verify HEAD`
	REDUNDANCY_LIMIT=$((`git rev-list HEAD | wc -l` - 1))

	(($REDUNDANCY < $REDUNDANCY_LIMIT)) || REDUNDANCY=$REDUNDANCY_LIMIT

	if [ ! `git rev-parse --verify HEAD^` ]; then
		BUNDLE="backup."`date +%Y%m%d%H%M%S`".master."$CURRENT_CHECKPOINT".bundle"
		git bundle create "$BUNDLE" HEAD
	else
		LAST_CHECKPOINT=`git rev-parse --verify HEAD^`
		BUNDLE="backup."`date +%Y%m%d%H%M%S`"."$LAST_CHECKPOINT"."$CURRENT_CHECKPOINT".bundle"
		git bundle create "$BUNDLE" "HEAD~$REDUNDANCY"..HEAD
	fi

	cp $BUNDLE .git/bundles/

	process_bundle $BUNDLE
fi

echo "Finished backup utility..."
echo `date`
