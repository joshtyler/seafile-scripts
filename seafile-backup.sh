#!/bin/bash
###############################
# Seafile server backup script (cold sqlite backup)
# Adapted from https://gist.github.com/3c7/cacf066e418ce1a1f8d3 by Nils Kuhnert by Josh Tyler 20171123
# Author: Nils Kuhnert
# Last change: 2014-07-27
# Website: 3c7.me
###############################

# Variables
DATE=`date +%F`
TIME=`date +%H%M`
SEAFDIR=/home/josh/seafile
SEAFDATADIR=/media/server-files/seafile
TEMPDIR=/media/server-files/seafile-backup

{
	echo "Subject: Seafile backup status"
	# Shutdown seafile
	echo Shutting down seafile
	$SEAFDIR/seafile-server-latest/seahub.sh stop
	$SEAFDIR/seafile-server-latest/seafile.sh stop

	# Create directories
	if [ ! -d $TEMPDIR ]
	  then
	  echo Create temporary directory $TEMPDIR
	  mkdir -pm 0600 $TEMPDIR
	  mkdir -m 0600 $TEMPDIR/databases
	  mkdir -m 0600 $TEMPDIR/data
	fi

	# Dump data / copy data
	echo Dumping GroupMgr database
	sqlite3 $SEAFDIR/ccnet/GroupMgr/groupmgr.db .dump > $TEMPDIR/databases/groupmgr.db.bak
	if [ -e $TEMPDIR/databases/groupmgr.db.bak ]; then echo ok.; else echo ERROR.; fi
	echo Dumping UserMgr database...
	sqlite3 $SEAFDIR/ccnet/PeerMgr/usermgr.db .dump > $TEMPDIR/databases/usermgr.db.bak
	if [ -e $TEMPDIR/databases/usermgr.db.bak ]; then echo ok.; else echo ERROR.; fi
	echo Dumping SeaFile database...
	sqlite3 $SEAFDIR/seafile-data/seafile.db .dump > $TEMPDIR/databases/seafile.db.bak
	if [ -e $TEMPDIR/databases/seafile.db.bak ]; then echo ok.; else echo ERROR.; fi
	echo Dumping SeaHub database...
	sqlite3 $SEAFDIR/seahub.db .dump > $TEMPDIR/databases/seahub.db.bak
	if [ -e $TEMPDIR/databases/seahub.db.bak ]; then echo ok.; else echo ERROR.; fi

	echo Copying seafile directory
	rsync -az $SEAFDATADIR/* $TEMPDIR/data
	if [ -d $TEMPDIR/data/seafile-data ]; then echo ok.; else echo ERROR.; fi

	# Start the server
	echo Restarting seafile
	$SEAFDIR/seafile-server-latest/seafile.sh start
	$SEAFDIR/seafile-server-latest/seahub.sh start-fastcgi

	# Send data to backblaze
	echo Syncing to backblaze
	b2 sync --delete --keepDays 5 $TEMPDIR b2://joshtyler-seafile-backup/

	# Cleanup
	echo Deleting temporary files...
	rm -Rf $TEMPDIR
	if [ ! -d $TEMPDIR ]; then echo ok.; else echo ERROR.; fi

} | tee | sendmail -f josh.tyler@btinternet.com josh.tyler@btinternet.com