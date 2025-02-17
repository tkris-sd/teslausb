#!/bin/bash -eu

/root/bin/remountfs_rw
TempDir=/tmp/manual_update
mkdir -p $TempDir
REPO=${REPO:-tkris-sd}
BRANCH=${BRANCH:-main-dev}

function setup_progress () {
	echo $@
}


  function curlwrapper () {
  echo "curl -s  $@" >> /tmp/manual_update.log
  while ! curl -s --fail "$@"
  do
    setup_progress "'curl $@' failed, retrying" 
    sleep 3
  done
}

function get_script () {
  local local_path="$1"
  local name="$2"
  local remote_path="${3:-}"

  curlwrapper -o "$TempDir/$name" https://raw.githubusercontent.com/"$REPO"/teslausb/"$BRANCH"/"$remote_path"/"$name"
  chmod +x "$TempDir/$name"
  dos2unix "$TempDir/$name" > /dev/null 2>&1
  echo -n "Checking $name ..."
  Changes="`diff $TempDir/$name $local_path/$name | wc -l`"
  if [ $Changes -ge 1 ]; then
	echo "Changes found in $name, updating local copy from github $REPO/$BRANCH"
	  if [ "$name" == "manual_update.sh" ]; then
		echo "Changes to this script found, please rerun this script due to update."
		cp $TempDir/$name	$local_path/$name
		exit
	  fi
	  cp $TempDir/$name	$local_path/$name
	else
	  echo "No changes found."
  fi
  /bin/rm -f $TempDir/$name
  #setup_progress "Downloaded $local_path/$name ..."
}

# Update the updaters
  get_script /root/bin manual_update.sh setup/pi
  get_script /root/bin setup-teslausb setup/pi
  
# Update the runtime tools
  get_script /root/bin send-push-message run
  get_script /root/bin send_sns.py run
  get_script /root/bin archiveloop run
  get_script /root/bin tesla_api.py run
  get_script /root/bin remountfs_rw run
  get_script /root/bin remountfs_ro run
  get_script /root/bin make_snapshot.sh run
  get_script /root/bin mount_snapshot.sh run
  get_script /root/bin mount_image.sh run
  get_script /root/bin release_snapshot.sh run

# Update cifs specific tools
  get_script /root/bin archive-clips.sh run/cifs_archive
  get_script /root/bin connect-archive.sh run/cifs_archive
  get_script /root/bin disconnect-archive.sh run/cifs_archive
  get_script /root/bin write-archive-configs-to.sh run/cifs_archive
  get_script /root/bin archive-is-reachable.sh run/cifs_archive
  get_script /root/bin copy-music.sh run/cifs_archive
  
# pull down copy of the setup files, jsut in case they might be handy
  
  #get_script /root/bin/tools create-backingfiles-partition.sh setup/pi
  #get_script /root/bin/tools create-backingfiles.sh setup/pi
  #get_script /root/bin/tools make-root-fs-readonly.sh setup/pi
  #get_script /root/bin/tools configure.sh setup/pi
  /root/bin/remountfs_ro
