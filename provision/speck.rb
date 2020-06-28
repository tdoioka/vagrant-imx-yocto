# -*- mode: ruby -*-
# vi: set ft=ruby :

# Use from shell and ruby and Makefile

# Deployment machine specs.
# ================================================================

# Virtualbox image name
VMC_NAME="yocto"

# build userneame
VMC_USER="yoctouser"

# Export machine spec.
VMC_MEMORY=2
VMC_CPU=1
VMC_VRAM=16
VMC_HDD=256


# Provision parameter.
# ================================================================

# Provision machine spec. only to use provision.
VMC_BUILD_MEMORY=32
VMC_BUILD_CPU=6

# When need to use sync folder enable line.
# SHARED_DIR=vagrant


# Build image configuration.
# ================================================================

# Build work directory.
PROJECT="imx"

# Fetch configuration
MANIFEST_URL="https://source.codeaurora.org/external/imx/imx-manifest"
MANIFEST_BRANCH="imx-linux-zeus"
MANIFEST_FILE="imx-5.4.3-1.0.0.xml"

# Configure and build configuration
BUILD_MACHINE="imx8mmevk"
BUILD_DISTRO="fsl-imx-xwayland"
BUILD_SETUPSCRIPT="imx-setup-release.sh"
BUILD_DIR="build"
# BUILD_IMAGE="fsl-image-machine-test"
BUILD_IMAGE="core-image-minimal"
# BUILD_IMAGE="imx-image-core"
# BUILD_IMAGE="imx-image-multimedia"

# Don't touch unless you know what you're doing!  Following paramater
# ================================================================

# Task cache directory name. for detecting change task.
BUILD_CACHE=".build"
# Workd directory on guest.
PROVD="/.provision"
# Host Provision directory name, must be this dir name.
PROVS="provision"
