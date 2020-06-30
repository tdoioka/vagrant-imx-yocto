#!/bin/bash

set -ueo pipefail
source $(dirname $(realpath $0))/common.sh


_sync_sleep() {
  while true; do
    sync
    local info=$(grep -e "Dirty:" -e "Writeback:" /proc/meminfo)
    err "$(echo $info)"
    # err "Dirty:$dt Writeback:$wb"
    local dt=$(echo $info | grep "Dirty:" | awk '{print $2}')
    local wb=$(echo $info | grep "Writeback:" | awk '{print $2}')
    [[ "$dt" == "0" ]] && [[ "$wb" == "0" ]] && break
    err "sync wait 5sec"
    sleep 5
  done
  err "sync wait 5sec"
  sleep 5
}

expand_part() {
  err "Begin resize HDD to run level 1..."
  local dev_num=$(mount | grep -e ' / ' | awk '{print $1}')
  local dm_name=
  if echo $dev_num | grep -q /dev/mapper; then
    # Device mapper is used. so, detect physical volume from lvdisplay,
    # but not consider RAID.
    dm_name=$dev_num
    dev_num=$(lvdisplay -m $dm_name |
            grep 'Physical volume' |
            head -n 1 |
            awk '{ print $NF }')
  fi
  local dev=$(echo $dev_num | tr -d [0-9])
  local part=$(echo $dev_num | sed -e "s@^${dev}@@")

  err "Resize partition..."
  lsblk
  if [[ -n "$dm_name" ]]; then
    pvresize $dev_num
    if ! lvextend -l +100%FREE $dm_name; then
      err "warning at $(basename $0): 'lvextend' skip partitin resize."
      return 0
    fi
  else
    growpart $dev $part || true
  fi
  resize2fs ${dm_name:-$dev_num}
  lsblk

  err "Run check disk ..."
  for dd in ${dev}*; do
    if [[ "$dd" != "$dev_num" ]]; then
      umount $dd || true
      fsck $dd || true
    fi
  done
  touch /forcefsck
  _sync_sleep
}


update() {
  err "package update"
  wget -q https://www.ubuntulinux.jp/ubuntu-ja-archive-keyring.gpg -O- | apt-key add -
  wget -q https://www.ubuntulinux.jp/ubuntu-jp-ppa-keyring.gpg -O- | apt-key add -
  wget https://www.ubuntulinux.jp/sources.list.d/bionic.list -O /etc/apt/sources.list.d/ubuntu-ja.list
  apt-get update
  apt-get upgrade -y
  apt-get full-upgrade -y
  apt-get autoremove -y
  apt-get autoclean
  apt-get clean
}


setup_skel() {
  err "setup skel"
  local skel=/etc/skel
  mkdir -p $skel/.env/rc
  mkdir -p $skel/bin

  if ! grep -e '^source ~/.env/rcloader$' $skel/.bashrc; then
    echo 'source ~/.env/rcloader' >> $skel/.bashrc
  fi
  cat << __eof__ > $skel/.env/rcloader
for file in ~/.env/rc/*.sh; do
  source \$file
done
__eof__

  cat << __eof__ > $skel/.env/rc/path.sh
addpath () {
  if [[ ! :\${PATH}: =~ :\${1}: ]]; then
    PATH="\$1:\$PATH"
  fi
}
addpath ~/bin
__eof__

  echo "setup git"
  apt-get install -y --no-install-recommends \
          git
  cat << __eof__ > $skel/.env/rc/git.sh
if [[ ! -e ~/.gitignore ]]; then
  git config --global user.name "\$(id -nu)"
  git config --global user.email "\$(id -nu)@${VMC_NAME}"
  git config --global \
      url.https://git.yoctoproject.org/git/meta-freescale.insteadof \
      "git://git.yoctoproject.org/meta-freescale"
  git config --global \
      url.https://git.yoctoproject.org/git/poky.insteadof \
      "git://git.yoctoproject.org/poky"
fi
__eof__

  echo "setup repo"
  wget --no-check-certificate -qO $skel/bin/repo \
       https://storage.googleapis.com/git-repo-downloads/repo
  chmod a+x $skel/bin/repo
}


setup_locale() {
  err "setup locale"
  apt-get install -y --no-install-recommends \
          language-pack-ja-base \
          language-pack-ja \
          ibus-mozc \
          fonts-takao \
          gkbd-capplet

  timedatectl set-timezone Asia/Tokyo
  update-locale LANG=ja_JP.UTF-8 LANGUAGE="ja_JP:ja"
  source /etc/default/locale

  sed -ie 's@XKBMODEL.*=.*@XKBMODEL="jp106"@g' /etc/default/keyboard
  sed -ie 's@XKBLAYOUT.*=.*@XKBLAYOUT="jp"@g' /etc/default/keyboard
}


install_desktop() {
  err "install desktop"

  apt-get install -y --no-install-recommends \
	  ubuntu-desktop \
	  gnome-terminal

  # Hide vagrant user.
  if ! sed -ie 's@SystemAccount=false@SystemAccount=true@g' \
       /var/lib/AccountsService/users/vagrant ; then
    cat << __eof__ > /var/lib/AccountsService/users/vagrant
[User]
SystemAccount=true
__eof__
  fi
}


install_yocto_require() {
  err "install yocto required"
  apt-get install -y --no-install-recommends \
          gawk \
          wget \
          git-core \
          diffstat \
          unzip \
          texinfo \
          gcc-multilib \
          build-essential \
          chrpath \
          socat \
          cpio \
          python3 \
          python3-pip \
          python3-pexpect \
          xz-utils \
          debianutils \
          iputils-ping \
          python3-git \
          python3-jinja2 \
          libegl1-mesa \
          libsdl1.2-dev \
          pylint3 \
          xterm
  apt-get install -y --no-install-recommends \
          python
  ln -fs /usr/bin/python3 /usr/bin/python
}


add_user() {
  err "add user ${VMC_USER}"
  local VMC_PASSWD=${VMC_PASSWD:-$VMC_USER}
  if ! grep  -qe "^${VMC_USER}:" /etc/passwd; then
    useradd -m ${VMC_USER} -s /bin/bash
    echo ${VMC_USER}:${VMC_PASSWD} | chpasswd
    sudo usermod -aG sudo ${VMC_USER}
  fi
}


finish() {
  # fill empty spase to zero
  err 'fill zero space...'
  dd if=/dev/zero of=~/zero bs=4M || true
  err 'fill done'
  sync
  rm -rf ~/zero
  touch /forcefsck
  _sync_sleep
}

sync_sleep() {
  _sync_sleep
}

runall $@
