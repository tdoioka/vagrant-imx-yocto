#!/bin/bash

set -ueo pipefail
source $(dirname $(realpath $0))/common.sh

_install_plugin() {
  if echo " ${PLUGINLIST} " | grep -qe " $1 "; then
    echo "$1 is aleady installed."
  else
    vagrant plugin install $1
  fi
}

plugin() {
  PLUGINLIST=$(vagrant plugin list | awk '{print $1}' | tr '\n' ' ')

#  _install_plugin vagrant-proxyconf
#  _install_plugin vagrant-disksize
  _install_plugin vagrant-reload
}

_vagrant_status() {
  vagrant status --machine-readable | grep -e default,state, | grep -o [^,]*$
}

pre_provision() {
  local status=$(_vagrant_status)
  if [[ "$status" == "not_created" ]]; then
    PRE_PROVISION=1 vagrant up --no-provision
  fi
  if [[ "$status" == "not_created" ]] || [[ "$status" == "running" ]]; then
    vagrant halt
  fi
}

expand_part() {
  local hddinfo=$($vbox showvminfo ${VMC_NAME} |
                    grep -e '\(\.vmdk\|\.vdi\) ')
  [[ -n "$hddinfo" ]] || return 1
  local ctrl=$(echo $hddinfo |
                 sed -e 's@^\([A-Za-z0-9 ]*\) .*@\1@')
  local port=$(echo $hddinfo |
                 sed -e 's@.*(\([0-9]*\), [0-9]*):.*@\1@')
  local device=$(echo $hddinfo |
                   sed -e 's@.*[0-9], \([0-9]*\)):.*@\1@')
  local orgpath=$(echo $hddinfo |
                    sed -e 's@^[^:]*: \(.*\) ([^(]*$@\1@g')

  local spath=$orgpath
  local drive=
  if [[ "$VAGRANT_WSL_ENABLE_WINDOWS_ACCESS" != "" ]]; then
    local drive=/mnt/$(echo $orgpath | sed 's@^\([^:]\):.*@\1@g' | tr [A-Z] [a-z])
    spath=$(echo $orgpath | tr '\\' '/' | sed 's@^[^:]*:@@g')
  fi
  local dpath=${spath/.*/.vdi}

  # Resize disk.
  if [[ "$spath" != "$dpath" ]]; then
    err 'Resize disk...'
    # Remove old disks.
    if $vbox list hdds | tr '\\' '/' | grep -q "$dpath"; then
      $vbox closemedium disk "$dpath" --delete
    fi
    [[ ! -e "$drive$dpath" ]] || rm -rf "$drive$dpath"

    # Clone and resize HDD, and delete original HDD image.
    $vbox clonehd "$spath" "$dpath" --format VDI
    $vbox modifyhd "$dpath" --resize $((${VMC_HDD}*1024))
    $vbox storageattach "${VMC_NAME}" --storagectl "${ctrl}" \
                --port ${port} --device ${device} --medium "$dpath"
    $vbox closemedium disk "$spath" --delete
  fi
}

provision() {
  local status=$(_vagrant_status)
  case "$status" in
    "running")  vagrant provision ;;
    *)          vagrant up --provision ;;
  esac
}

build() {
  local status=$(_vagrant_status)
  case "$status" in
    "running")  BUILD=1 vagrant provision ;;
    *)          BUILD=1 vagrant up --provision ;;
  esac
}

_vagrant_shutdown() {
  local status=$(_vagrant_status)
  case "$status" in
    "poweroff") ;;
    "not_created")
      err "ERROR: can not finalize status is $status"
      return 1
      ;;
    *) vagrant halt ;;
  esac
}

finalize() {
  local status=$(_vagrant_status)
  case "$status" in
    "not_created")
      err "ERROR: can not finalize status is $status"
      return 1
      ;;
    "running")  FINALIZE=1 vagrant provision ;;
    *)          FINALIZE=1 vagrant up --provision ;;
  esac
  vagrant halt
  # Remove unfriendry options to friendry.
  $vbox modifyvm $VMC_NAME \
              --cpus   $VMC_CPU \
              --memory $(($VMC_MEMORY * 1024)) \
              --nic2 none
  # Remove shared folder if exists
  if [[ -n "${SHARED_DIR:-}" ]]; then
    $vbox sharedfolder remove $VMC_NAME --name $SHARED_DIR
  fi
}

export() {
  _vagrant_shutdown || return
  # Shutdown.
  if $vbox list runningvms | grep -q \"$VMC_NAME\"; then
    $vbox controlvm $VMC_NAME acpipowerbutton
  fi
  # Export.
  rm -rf $VMC_NAME; mkdir -p $VMC_NAME
  $vbox export ${VMC_NAME} -o ${VMC_NAME}/${VMC_NAME}.ovf
}

runall $@
