# !/bin/bash
# Scriptname: duplicity_restore_neo4j.sh
#
# This script automatically restore the dump folder of neo4j instance using duplicity
#
# SO, SUGGEST THIS SCRIPT SHOULD BE RUN WHEN SERVER HAS NO RUN ANY NEO4J BACKUP SCRIPT
# params:
#	$1: duplicity backup location, include full and incremental backup
#	$2: temporary folder, where duplicity will extract data
#	$3 [optional]: date to restore (yyyy-MM-dd)
# example:
#	sudo ./duplicity_restore_neo4j.sh /home/tanbt/backup/neo4j_db /usr/local/mio/backup/neo4j_db 2013-10-22

### Duplicity Setup ###
PASSPHRASE="Pr!m#rB@ckup2012"
EXTRADUPLICITYOPTIONS="--archive-dir=/home/tanbt/duplicity-cache"
MAILTO=root@localhost

# Duplicity Parameters #
DUPLICITY_BACKUP_FOLDER=$1
TEMPORARY_RESTORE_FOLDER=$2
TIME_TO_RESTORE=0

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "sudo ./duplicity_restore_neo4j.sh DUPLICITY_BACKUP_FOLDER RESTORE_FOLDER [2013-10-22]"
  exit 2
fi

# check if parameter 3rd not empty (e.g "2013-10-19")
if [ ! -z "$3" ]
then
   TIME_TO_RESTORE="--restore-time=$3"
fi

###### End Of Editable Parts ######

PASSPHRASE_OLD="$(echo $PASSPHRASE)"
export PASSPHRASE=$PASSPHRASE
DUPLICITY="$(which duplicity)"

if [ -z "$DUPLICITY" ]; then
  echo "Duplicity not found."
  exit 2
fi

if [ ! -e /var/lock/subsys/rs_neo4j_db ]; then

  # Create the gating lock file
  /bin/touch /var/lock/subsys/rs_neo4j_db

  # Get a secure tempfile
  TMPFILE1=`/bin/mktemp -t rs_neo4j_db.XXXXXXXXXX` || exit 1

  ### Backup web ###
  /bin/echo "------------ Start restore neo4j database backup folder ------------" >> $TMPFILE1


	DEST_FOLDER="file://${DUPLICITY_BACKUP_FOLDER}"
	SRC_FOLDER="${TEMPORARY_RESTORE_FOLDER}"
	/bin/echo -e "\n*** RESTORE: ${DUPLICITY_BACKUP_FOLDER} ***" >> $TMPFILE1

	if [ ! -z "$3" ]; then
		duplicity restore $EXTRADUPLICITYOPTIONS $TIMEVERSION $DEST_FOLDER $SRC_FOLDER >> $TMPFILE1
	else
		duplicity restore $EXTRADUPLICITYOPTIONS $DEST_FOLDER $SRC_FOLDER >> $TMPFILE1
	fi

  
  /bin/echo "------------ Complete resstore neo4j database backup folder ------------" >> $TMPFILE1
  
  export PASSPHRASE=$PASSPHRASE_OLD

  # send report to administrators
  /bin/cat $TMPFILE1 | /bin/mail -s "Restore Neo4j database backup folder  $(hostname)" $MAILTO

  # Delete the secure tempfile
  /bin/rm -f $TMPFILE1

  # Delete the gating lockfile
  /bin/rm -f /var/lock/subsys/rs_neo4j_db
fi
