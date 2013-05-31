blackbird dotfiles
==================

Commons dotfiles for Blackbird Team, for unix system, with vim, git, pry and tmux.
Install some must-have plugins and aliases for developping with rails framework.

Requirements
------------

Install and set **zsh** as your login shell.

   chsh -s /bin/zsh

Recommandations
---------------

Some aliases and plugins recommand/use following programmes:

Install [ag](https://github.com/ggreer/the_silver_searcher) (ack-like more powerfull):

    git clone https://github.com/ggreer/the_silver_searcher

Install [hub](https://github.com/defunkt/hub) (git wrapper for github):

    git clone https://github.com/defunkt/hub 

Install [rvm](https://rvm.io) (Ruby Version Manager) :

		

Install
-------

Clone onto your laptop:
    
    git clone https://github.com/blackbirdco/dotfiles.git

Install:

    cd dotfiles
    ./install.sh

This will create symlinks for config files in your home directory. If you
include the line "DO NOT EDIT BELOW THIS LINE" anywhere in a config file, it
will copy that file over instead of symlinking it, and it will leave
everything above that line in your local config intact.

You can safely run `./install.sh` multiple times to update.

Make your own customizations
----------------------------

Put your customizations at the top of files, separated by "DO NOT EDIT BELOW
THIS LINE."

For example, the top of your `~/.gitconfig` might look like this:

    [user]
      name = Loïc Delmaire 
      email = loic@blackbird.co

    # DO NOT EDIT BELOW THIS LINE

    [color]
      diff = auto

The top of your `~/.zshrc` might look like this:

    # Productivity
    alias todo='$EDITOR ~/.todo'

    # DO NOT EDIT BELOW THIS LINE

    # add the current branch name in green
    git_prompt_info() {


What's in it?
-------------

[zsh](http://www.zsh.org/) for default shell:

* Add git branch to right prompt
* Some common options and configurations extract from oh-my-zsh

[vim](http://www.vim.org/) configuration:

* [Rails.vim](https://github.com/tpope/vim-rails) for enhanced navigation of
  Rails file structure via `gf` and `:A` (alternate), `:Rextract` partials,
  `:Rinvert` migrations, etc.
* Run [RSpec](https://www.relishapp.com/rspec) specs from vim.
* Syntax highlighting for : CoffeeScript, Cucumber, Haml, Markdown, and
  HTML5.
* Use [Ag](https://github.com/ggreer/the_silver_searcher) instead of Grep when
  available.
* Use [Exuberant Ctags](http://ctags.sourceforge.net/) for tab completion.
* Use [Vundle](https://github.com/gmarik/vundle) to manage plugins.

Details in vimrc.bundles for others plugins.

You can use your a local configuration in `~/.vimrc.local`.

[tmux](http://tmux.sourceforge.net/) configuration.
* Set prefix to `Ctrl+a` (like GNU screen).

[git](http://git-scm.com/) configuration.

Shell aliases and scripts:

* `b` for `bundle`.
* `g` with no arguments is `git status` and with arguments acts like `git`.
* `m` for `rake db:migrate && rake db:rollback && rake db:migrate && rake db:test:prepare`.
* `mcd` to make a directory and change into it.
* `rake` is `zeus rake` if using [Zeus](https://github.com/burke/zeus) on the
  project in current directory.
* `rk` for `rake`.
* `rspec` is `zeus rspec` if using Zeus on the project in current directory.
* `tat` to attach to tmux session named the same as the current directory.
* `v` for `$VISUAL`.

[pry](https://github.com/pry/pry) configuration:

* Set pry as the default ruby/rails console (pry-everywhere)
* Add hirb for rails console

TODO
----

* More tests needed

Credits
-------

Inspired by [thoughtbot's dotfiles](https://github.com/thoughtbot/dotfiles)

It is free software and may be
redistributed under the terms specified in the [LICENSE](LICENSE) file.
