#!/bin/bash -eu
HEADLESS_SETUP=${HEADLESS_SETUP:-false}
if [ "$HEADLESS_SETUP" = "false" -a -t 0 ]
then
  # running in terminal in non-headless mode
  if [ -f /boot/teslausb_setup_variables.conf -o -f /root/teslausb_setup_variables.conf ]
  then
    # headless setup variables are available
    read -p "Read setup info from teslausb_setup_variables.conf (yes/no/cancel)? " answer
    case ${answer:0:1} in
      y|Y )
          HEADLESS_SETUP=true
      ;;
      n|N )
      ;;
      * )
          exit
      ;;
    esac
  fi
fi

REPO=${REPO:-tkris-sd}
BRANCH=${BRANCH:-main-dev}
USE_LED_FOR_SETUP_PROGRESS=true
CONFIGURE_ARCHIVING=${CONFIGURE_ARCHIVING:-true}
UPGRADE_PACKAGES=${UPGRADE_PACKAGES:-true}
TESLAUSB_HOSTNAME=${TESLAUSB_HOSTNAME:-teslausb}
SAMBA_ENABLED=${SAMBA_ENABLED:-false}
SAMBA_GUEST=${SAMBA_GUEST:-false}
export camsize=${camsize:-90%}
export musicsize=${musicsize:-100%}
export usb_drive=${usb_drive:-''}

function headless_setup_populate_variables () {
  # Pull in the conf file variables to make avail to this script and subscripts
  # If setup-teslausb is run from rc.local, the conf file will have been moved
  # to /root by rc.local
  if [ $HEADLESS_SETUP = "true" ]
  then
    if [ -e /boot/teslausb_setup_variables.conf ]
    then
      setup_progress "reading config from /boot/teslausb_setup_variables.conf"
      source /boot/teslausb_setup_variables.conf
    elif [ -e /root/teslausb_setup_variables.conf ]
    then
      setup_progress "reading config from /root/teslausb_setup_variables.conf"
      source /root/teslausb_setup_variables.conf
    else
      setup_progress "couldn't find config file"
    fi
  fi
  function curlwrapper () {
  setup_progress "curl $@"
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
function get_ancillary_setup_scripts () {
  get_script /tmp create-backingfiles-partition.sh setup/pi
  get_script /tmp create-backingfiles.sh setup/pi
  get_script /tmp make-root-fs-readonly.sh setup/pi
  get_script /tmp configure.sh setup/pi
}

function get_common_scripts () {
  get_script /root/bin remountfs_rw run
  get_script /root/bin make_snapshot.sh run
  get_script /root/bin mount_snapshot.sh run
  get_script /root/bin mount_image.sh run
  get_script /root/bin release_snapshot.sh run
  get_script /root/bin setup-teslausb setup/pi
}

get_common_scripts

get_ancillary_setup_scripts
