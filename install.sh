#!/bin/sh

./symlink.sh
rvm --default use `cat ruby-version`
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
git clone https://github.com/gmarik/vundle.git ~/.vim/bundle/vundle
nvim -u ~/.vimrc.bundles +BundleInstall +qa
