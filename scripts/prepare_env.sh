#!/bin/bash

# Scripts to prepare environment for gPRC iOS repo build and test
set -ex

# Prerequisites
# Xcode command line tools and Homebrew should be already installed

# GNU command line tools
brew install coreutils

# Git archiving tool
brew install git-archive-all

# Skip lint during pod trunk push
./scripts/skip_pod_push_lint.sh
