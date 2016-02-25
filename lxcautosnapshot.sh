#!/bin/bash
###
# Backupscript for LXC
# using btrfs snapshots
###

# Setup
BLACKLIST=()

# Paths
LXCPATH=/var/lib/lxc
BACKUPPATH=/root/backup

DATE=$(date +%Y%m%dT%H%M)

# Controler
RUNNING_CONTAINERS="$(lxc-ls --active)"
LXCAUTOSTART=',delayedstart'

# Admin email
MAIL="email-address"

# Email Tag
EMAIL_SUBJECT_TAG="[backup of $SOURCE_DIR@$HOST]"

# Number of day the daily backup keep ( 2 day = 2 daily backup retention)
RETENTION_DAY=5

# Number of day the weekly backup keep (14 day = 2 weekly backup retention )
RETENTION_WEEK=7

# Number of day the monthly backup keep (30 day = 2 monthly backup retention)
RETENTION_MONTH=30

# Monthly date backup option (day of month)
MONTHLY_BACKUP_DATE=1

# Weekly day to backup option (day of week - 1 is monday )
WEEKLY_BACKUP_DAY=6


## STARTING BACKUP SCRIPT

#Check date

## Generate list of container to snapshot
SNAPSHOT=()
for container in $(ls ${LXCPATH}); do
	skip=
	echo $container
	for i in ${BLACKLIST[@]}; do
		[[ $container == $i ]] && { skip=1; break; }
	done
	if [ -n $skip ]
		then
		SNAPSHOT+=$container
	fi
done

# Get current month and week day number
month_day=`date +"%d"`
week_day=`date +"%u"`

# On first month day do
  if [ "$month_day" -eq $MONTHLY_BACKUP_DATE ] ; then
    BACKUP_TYPE='-monthly'
    RETENTION_DAY_LOOKUP=$RETENTION_MONTH
  else
  # On saturdays do
    if [ "$week_day" -eq $WEEKLY_BACKUP_DAY ] ; then
    # weekly - keep for RETENTION_WEEK
    BACKUP_TYPE='-weekly'
    RETENTION_DAY_LOOKUP=$RETENTION_WEEK
    else
    # On any regular day do
      BACKUP_TYPE=''
      RETENTION_DAY_LOOKUP=$RETENTION_DAY
    fi
  fi

# Cleanup expired backups
echo "Removing expired backups..."
for i in $(ls {$LXCPATH}); do
	find $LXCPATH/$i/snaps -maxdepth 1 -mtime +$RETENTION_DAY_LOOKUP -exec rm -rv {} \;
done

function movingSnapshots(){
	v=$1
	name="$date-${BACKUP_TYPE}"
	# Moving Backup
	echo "Save incremental Backup"
	for i in $(ls {$LXCPATH}); do
		find $LXCPATH/$i/snaps -maxdepth 1 -mtime +$RETENTION_DAY_LOOKUP -name '*$v*' -exec bash -c 'mv $0 $LXCPATH/$i/snaps/$name}' {} \;
	done
}

function stopLXC(){
	for container in $RUNNING_CONTAINERS; do
		lxc-stop --name $container
	done
}

function startLXC(){
	lxc-autostart -g ${LXCAUTOSTART}
	RUNNING_AFTER_START="$(lxc-ls --active)"
	START_CONTAINER=()
        for i in $RUNNING_CONTAINERS; do
                skip= 
                for j in $RUNNING_AFTER_START; do
                        [[ $i == $j ]] && { skip=1; break; }
                done
                [[ -n $skip ]] || START_CONTAINER+=("$i")
        done
        for container in ${START_CONTAINER[@]}; do
                echo "Start $container..."
                lxc-start --name $container
        done
}

function validate(){
	if [ ! -f $source/archive.tgz ]; then
		ls -l $source/ | mail your@email.com -s "[backup script] Daily backup failed! Please check for missing files."
	fi
}

function backup(){
	#stopLXC
	
	echo "Processing snapshots..."
	for i in ${SNAPSHOT[@]}; do
		lxc-snapshot -n $container
	done

}

backup
