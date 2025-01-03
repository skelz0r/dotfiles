#!/bin/sh

./symlink.sh
rvm --default use `cat ruby-version`
gem install ruby-lsp
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
git clone https://github.com/gmarik/vundle.git ~/.vim/bundle/vundle
nvim -u ~/.vimrc.bundles +BundleInstall +qa

rm -f ~/.config/nvim/coc-settings.json
ln -s ~/dotfiles/config/coc-settings.json ~/.config/nvim/coc-settings.json
