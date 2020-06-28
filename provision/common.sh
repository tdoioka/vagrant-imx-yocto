#!/bin/bash

SCRPATH=$(realpath $0)
SCRBASE=$(dirname $SCRPATH)
source $SCRBASE/speck.rb

vbox=vboxmanage
type $vbox >&/dev/null || {
  vbox=VBoxManage.exe
}

umask 0000

err() {
  echo "$0 => $@" >&2
}

_cache() {
  mkdir -p $(dirname $1) &&
    echo $2 > $1
}

_is_cached() {
  local before="0"
  local next="$2"
  if [[ -e $1 ]]; then
    before=$(cat $1)
  fi
  if [[ "$before" != "$next" ]]; then
    printf "function hash changed: %032s => %032s\n" "${before}" "${next}"
    return 1
  fi
  return 0
}

_findfuncs() {
  FUNC_LIST=(${FUNC_LIST[@]} $1)
  script=($(declare -f $1))
  for tok in ${script[@]}; do
    if declare -F $tok >&/dev/null ; then
      if  echo " ${FUNC_LIST[@]} " | grep -q " $tok "; then
        :
      else
        _findfuncs $tok
      fi
    fi
  done
}

_functions() {
  FUNC_LIST=()
  _findfuncs $1
  declare -f ${FUNC_LIST[@]}
}

run() {
  local name=$1
  local built="${SCRBASE}/${BUILD_CACHE}/$(basename ${0})..${1}"
  err "\"$name\" ... run"

  local hash="$(_functions $1 | md5sum - | awk '{print $1}')"
  if _is_cached $built "$hash"; then
    err "\"$name\" ... already done skip"
  else
    $@
    err "\"$name\" ... done"
    _cache $built $hash
  fi
}

runall() {
  if echo " $@ " | grep -q " -f "; then
    for task in $@; do
      case $task in
        -*) ;;
        *) $task
      esac
    done
  else
    for task in $@; do
      run $task
    done
  fi
}

runalluser() {
  if [[ "${USER}" != "${VMC_USER}" ]] ; then
    chmod 755 $SCRPATH
    sudo -u "$VMC_USER" -i $SCRPATH $@
  else
    runall $@
  fi
}
