#!/bin/bash
# Script to build docs for travis usage

set -e

SOURCE_BRANCH=$TRAVIS_BRANCH

if [ -n "$TRAVIS_TAG" ]; then
    SOURCE_BRANCH=$TRAVIS_TAG
fi

# Use YARD to build docs
bundle exec yard

# Move to correct folder
mkdir -p docs/$SOURCE_BRANCH
mv doc/* docs/$SOURCE_BRANCH/
