#!/bin/bash
# Install from brew.list & brew-cask.list

while read $app; do
  brew install $app
done < brew.list

while read $app; do
  brew cask install $app
done < brew-cask.list
