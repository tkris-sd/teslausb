#!/bin/bash -eu

log "Moving clips to archive..."

NUM_FILES_MOVED=0
NUM_FILES_FAILED=0
NUM_FILES_DELETED=0

function connectionmonitor {
  while true
  do
    for i in $(seq 1 10)
    do
      if timeout 3 /root/bin/archive-is-reachable.sh $ARCHIVE_HOST_NAME
      then
        # sleep and then continue outer loop
        sleep 5
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

function moveclips() {
  ROOT="$1"
  PATTERN="$2"
  SUB=$(basename $ROOT)

  if [ ! -d "$ROOT" ]
  then
    log "$ROOT does not exist, skipping"
    return
  fi

  while read file_name
  do
    if [ -d "$ROOT/$file_name" ]
    then
      log "Creating output directory '$SUB/$file_name'"
      if ! mkdir -p "$ARCHIVE_MOUNT/$SUB/$file_name"
      then
        log "Failed to create '$SUB/$file_name', check that archive server is writable and has free space"
        return
      fi
    elif [ -f "$ROOT/$file_name" ]
    then
      size=$(stat -c%s "$ROOT/$file_name")
      if [ $size -lt 100000 ]
      then
        log "'$SUB/$file_name' is only $size bytes"
        rm "$ROOT/$file_name"
        NUM_FILES_DELETED=$((NUM_FILES_DELETED + 1))
      else
        log "Moving '$SUB/$file_name'"
        outdir=$(dirname "$file_name")
        if mv -f "$ROOT/$file_name" "$ARCHIVE_MOUNT/$SUB/$outdir"
        then
          log "Moved '$SUB/$file_name'"
          NUM_FILES_MOVED=$((NUM_FILES_MOVED + 1))
        else
          log "Failed to move '$SUB/$file_name'"
          NUM_FILES_FAILED=$((NUM_FILES_FAILED + 1))
        fi
      fi
    else
      log "$SUB/$file_name not found"
    fi
  done <<< $(cd "$ROOT"; find $PATTERN)
}

connectionmonitor $$ &

if [ -z "$CIFS_Use_Rsync" ];
  then
	# new file name pattern, firmware 2019.*
	moveclips "$CAM_MOUNT/TeslaCam/SavedClips" '*'

	# v10 firmware adds a SentryClips folder
	moveclips "$CAM_MOUNT/TeslaCam/SentryClips" '*'
  else
    log "Copying Sentry and Saved clips to Archive... using rsync"
	RsyncLog=/mutable/archive_rsync.log
	# make sure both the sub dirs exist so rsync does not hit an error.
	mkdir -p $CAM_MOUNT/TeslaCam/SavedClips $CAM_MOUNT/TeslaCam/SentryClips > /dev/null 2>&1
	rsync -avH --stats --ignore-existing $CAM_MOUNT/TeslaCam/SavedClips $CAM_MOUNT/TeslaCam/SentryClips $ARCHIVE_MOUNT > $RsyncLog 2>&1
	if [ $? == 0 ]; 
	  then
	    /bin/rm -rf $CAM_MOUNT/TeslaCam/SavedClips/* 
	  else
	    log "Not removing SavedClips, rsync did not exit clean. Check Yo Space."
		/root/bin/send-push-message "TeslaUSB Rsync:" "Not removing SavedClips after rsync - Check your space"
	fi
	
	Added=`grep "Number of" $RsyncLog`
	log "Rsync complete, $Added"
	Created=`grep "Number of created files:" $RsyncLog | cut -d: -f2`
	Deleted=`grep "Number of deleted files:" $RsyncLog | cut -d: -f2`
	if [ $Created -gt 0 ] || [ $Deleted -gt 0 ]; 
	  then
	  log "Sending message"
	  /root/bin/send-push-message "TeslaUSB Archive Rsync:" "Copied $Created file(s), removed $Deleted"
	fi
  fi

kill %1

# delete empty directories under SavedClips and SentryClips
rmdir --ignore-fail-on-non-empty "$CAM_MOUNT/TeslaCam/SavedClips"/* "$CAM_MOUNT/TeslaCam/SentryClips"/* || true

log "Moved $NUM_FILES_MOVED file(s), failed to copy $NUM_FILES_FAILED, deleted $NUM_FILES_DELETED."

if [ $NUM_FILES_MOVED -gt 0 ]
then
  /root/bin/send-push-message "TeslaUSB:" "Moved $NUM_FILES_MOVED dashcam file(s), failed to copy $NUM_FILES_FAILED, deleted $NUM_FILES_DELETED."
fi

log "Finished moving clips to archive."
