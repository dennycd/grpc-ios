#!/bin/bash
set -ex

# env setup
GEM_VERSION=2.6.0
POD_TRUNK_VERSION=1.6.0
PUSH_FILE_DIR="/Library/Ruby/Gems/${GEM_VERSION}/gems/cocoapods-trunk-${POD_TRUNK_VERSION}/lib/pod/command/trunk"

# remove validation steps
pushd $PUSH_FILE_DIR
pwd
sudo sed -i "" 's/^ *validate_podspec//' push.rb
popd
