#!/bin/bash -eu


REPO=${REPO:-tkris-sd}
BRANCH=${BRANCH:-main-dev}

function setup_progress () {
	echo $@
}


  function curlwrapper () {
  setup_progress "curl -s  $@"
  while ! curl --fail "$@"
  do
    setup_progress "'curl $@' failed, retrying" > /dev/null
    sleep 3
  done
}

function get_script () {
  local local_path="$1"
  local name="$2"
  local remote_path="${3:-}"

  curlwrapper -o "$local_path/$name" https://raw.githubusercontent.com/"$REPO"/teslausb/"$BRANCH"/"$remote_path"/"$name"
  chmod +x "$local_path/$name"
  setup_progress "Downloaded $local_path/$name ..."
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
  
  get_script /tmp create-backingfiles-partition.sh setup/pi
  get_script /tmp create-backingfiles.sh setup/pi
  get_script /tmp make-root-fs-readonly.sh setup/pi
  get_script /tmp configure.sh setup/pi
