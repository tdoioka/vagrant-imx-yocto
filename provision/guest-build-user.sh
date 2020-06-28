#!/bin/bash

set -ueo pipefail
source $(dirname $(realpath $0))/common.sh

umask 0022
project=~/work/$PROJECT

download() {
  (mkdir -p $project &&
     cd $project &&
     repo init -u $MANIFEST_URL -b $MANIFEST_BRANCH -m $MANIFEST_FILE &&
     repo sync)
}

configure() {
  (cd $project &&
     bash -c "MACHINE=$BUILD_MACHINE DISTRO=$BUILD_DISTRO EULA=1 \
          source $BUILD_SETUPSCRIPT -b $BUILD_DIR")
}

build() {
  (cd $project && \
     bash -c "source setup-environment $BUILD_DIR && \
     bitbake $BUILD_IMAGE")
}

runalluser $@
