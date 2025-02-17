#!/bin/bash -eu

log "Copying music from archive..."

NUM_FILES_COPIED=0
NUM_FILES_SKIPPED=0
NUM_FILES_ERROR=0
SRC="/mnt/musicarchive"
DST="/mnt/music"

function connectionmonitor {
  while true
  do
    for i in $(seq 1 10)
    do
      if timeout 3 /root/bin/archive-is-reachable.sh $ARCHIVE_HOST_NAME
      then
	  if [ -x /root/bin/tesla_api.py ]
        then
		  log "Sending wake command to vehicle while copy continues..."
                /root/bin/tesla_api.py wake_up_vehicle &>> ${LOG_FILE}
		fi
        # sleep and then continue outer loop
        sleep 30
        continue 2
      fi
    done
    log "connection dead, killing archive-clips"
    # The archive loop might be stuck on an unresponsive server, so kill it hard.
    # (should be no worse than losing power in the middle of an operation)
    kill -9 $1
    return
  done
}

if ! findmnt --mountpoint $DST
then
  log "$DST not mounted, skipping"
  exit
fi

connectionmonitor $$ &

if [  "${CIFS_Use_Rsync:-true}" != "true" ];
  then
	while read file_name
	do
	  if [ ! -e "$DST/$file_name" ]
	  then
		dir=$(dirname "$file_name")
		if ! mkdir -p "$DST/$dir"
		then
		  log "couldn't make directory $DST/$dir"
		  NUM_FILES_ERROR=$((NUM_FILES_ERROR + 1))
		  continue
		fi
		if ! cp "$SRC/$file_name" "$DST/$dir/__tmp__"
		then
		  log "Couldn't copy $SRC/$file_name"
		  NUM_FILES_ERROR=$((NUM_FILES_ERROR + 1))
		  continue
		fi
		if ! mv "$DST/$dir/__tmp__" "$DST/$file_name"
		then
		  log "Couldn't move to $DST/$file_name"
		  NUM_FILES_ERROR=$((NUM_FILES_ERROR + 1))
		  continue
		fi
		NUM_FILES_COPIED=$((NUM_FILES_COPIED + 1))
	  else
		NUM_FILES_SKIPPED=$((NUM_FILES_SKIPPED + 1))
	  fi
	done <<< "$(cd "$SRC"; find * -type f)"
  else
	log "Copying music from Archive... using rsync"
	RsyncLog=/mutable/music_rsync.log
	rsync -avH --stats --ignore-existing --exclude .DS_Store --exclude desktop.ini --exclude Thumbs.db --exclude \*.jpg --delete $SRC/ $DST > $RsyncLog 2>&1
	Added=`grep "Number of" $RsyncLog`
	log "Rsync complete, $Added"
	Created=`grep "Number of created files:" $RsyncLog | cut -d: -f2`
	Deleted=`grep "Number of deleted files:" $RsyncLog | cut -d: -f2`
	if [ $Created -gt 0 ] || [ $Deleted -gt 0 ]; 
	  then
	  /root/bin/send-push-message "TeslaUSBMusicRsync:" "Copied $Created music file(s), removed $Deleted"
	fi
  fi

kill %1

log "Copied $NUM_FILES_COPIED music file(s), skipped $NUM_FILES_SKIPPED previously-copied files, encountered $NUM_FILES_ERROR errors."

if [ $NUM_FILES_COPIED -gt 0 ]
then
  /root/bin/send-push-message "TeslaUSB:" "Copied $NUM_FILES_COPIED music file(s), skipped $NUM_FILES_SKIPPED previously-copied files, encountered $NUM_FILES_ERROR errors."
fi
