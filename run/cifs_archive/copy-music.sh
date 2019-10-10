#!/bin/bash -eu

log "Copying music from archive..."


SRC="/mnt/musicarchive"
DST="/mnt/music"

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

if ! findmnt --mountpoint $DST
then
  log "$DST not mounted, skipping"
  exit
fi

connectionmonitor $$ &

log "Copying music from Archive... using rsync"
RsyncLog=/mutable/music_rsync.log
rsync -avH --stats --ignore-existing --exclude .DS_Store --exclude desktop.ini --exclude Thumbs.db --exclude \*.jpg --delete $SRC/ $DST > $RsyncLog 2>&1

Added=`grep "Number of" $RsyncLog`
log "Rsync complete, $Added"
Created=`grep "Number of created files:" $RsyncLog | cut -d: -f2`
Deleted=`grep "Number of deleted files:" $RsyncLog | cut -d: -f2`
if [ $Created -gt 0 ] || [ $Deleted -gt 0 ]; 
  then
  log "Sending message"
  /root/bin/send-push-message "TeslaUSB Music Rsync:" "Copied $Created music file(s), removed $Deleted"
fi

kill %1

