# !/bin/bash
# Scriptname: auto_neo4j_backup.sh
#
# This script automatically dump neo4j database to a folder and backup that folder using duplicity
#
# SO, SUGGEST THIS SCRIPT SHOULD BE RUN WHEN SERVER HAS THE FEWEST TRANSACTIONS
# params:
#	$1: duplicity backup location, include full and incremental backup
#	$2: Neo4j dump folder, where neo4j_backup scrip will dump Neo4j Instance Database to
#	$3  Neo4j Instance access (e.g, single://[ip]:[port])
# example:
#	sudo ./auto_neo4j_backup.sh /home/tanbt/backup/neo4j_db /usr/local/mio/backup/neo4j_db single://192.168.68.102:6366

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
  echo "This script expects at least 3 parameters."
  exit 2
fi


DUPLICITY_BACKUP_FOLDER=$1
NEO4J_DUMP_FOLDER=$2
NEO4J_INSTANCE=$3
MAILTO=root@localhost

# Which day do you want weekly backups? (1 to 7 where 1 is Monday)
DOWEEKLY=6

PASSPHRASE="Pr!m#rB@ckup2012"
EXTRADUPLICITYOPTIONS="--archive-dir=/home/tanbt/duplicity-cache"

# Get a secure tempfile
TMPFILE1=`/bin/mktemp -t bk_neo4j_duplicity.XXXXXXXXXX` || exit 1

###### End Of Editable Parts ######
# Neo4j duplicity function
duplicity_backup () {
	PASSPHRASE_OLD="$(echo $PASSPHRASE)"
	export PASSPHRASE=$PASSPHRASE
	DUPLICITY="$(which duplicity)"

	if [ -z "$DUPLICITY" ]; then
	  echo "Duplicity not found."
	  exit 2
	fi

	# Day number of the week 1 to 7 where 1 represents Monday
	DNOW=`date +%u`

	### Backup web ###
	/bin/echo "------------ Start backup web files ------------" >> $TMPFILE1

	DEST_FOLDER="file://$2"
	SRC_FOLDER=$1

	/bin/echo -e "\n*** BACKUP: $1 ***" >> $TMPFILE1

	duplicity remove-older-than 2W $EXTRADUPLICITYOPTIONS --force $DEST_FOLDER >> $TMPFILE1

	if [ $DNOW = $DOWEEKLY ]; then
		duplicity full $EXTRADUPLICITYOPTIONS $SRC_FOLDER $DEST_FOLDER >> $TMPFILE1
	else
		duplicity $EXTRADUPLICITYOPTIONS $SRC_FOLDER $DEST_FOLDER >> $TMPFILE1
	fi

	  
	/bin/echo "------------ Complete backup web files ------------" >> $TMPFILE1
	  
	export PASSPHRASE=$PASSPHRASE_OLD

	# send report to administrators
	/bin/cat $TMPFILE1 | /bin/mail -s "Daily backup web files on $(hostname)" $MAILTO

}


############ MAIN WORK #############

# Dump neo4j database to a backup folder
if [ ! -e /var/lock/subsys/bk_neo4j_dumping ] \
&& [ ! -e /var/lock/subsys/bk_neo4j_data_ready ]; then

   # Create the gating lock file
   /bin/touch /var/lock/subsys/bk_neo4j_dumping

   # In case iowait too high
   /bin/touch /var/lock/subsys/bk_neo4j_data_ready		

   # Run the process
   mkdir ${NEO4J_DUMP_FOLDER} -P
   /usr/local/mio/neo4j-enterprise-1.9.2/bin/neo4j-backup -from ${NEO4J_INSTANCE} -to ${NEO4J_DUMP_FOLDER} >> $TMPFILE1

   # Remove the gating lock file
   /bin/rm -f /var/lock/subsys/bk_neo4j_dumping
fi

# Save backup folder using duplicity

if [ -e /var/lock/subsys/bk_neo4j_data_ready ] \
&& [ ! -e /var/lock/subsys/bk_neo4j_dumping ] \
&& [ ! -e /var/lock/subsys/bk_neo4j_duplicity ]; then

   # Create the gating lock file
   /bin/touch /var/lock/subsys/bk_neo4j_duplicity

   # Run the process (params: source, target)
   duplicity_backup ${NEO4J_DUMP_FOLDER} ${DUPLICITY_BACKUP_FOLDER}

   # Delete the gating lockfile
   /bin/rm -f /var/lock/subsys/bk_neo4j_data_ready
   /bin/rm -f /var/lock/subsys/bk_neo4j_duplicity
fi

# Delete the secure tempfile
/bin/rm -f $TMPFILE1
