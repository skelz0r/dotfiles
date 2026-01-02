# TODO - Améliorations Dotfiles

## Organisation & Structure

- [ ] **Nettoyer fichiers non versionnés** - `.rubocop.yml`, `Gemfile*`, `sampler.yml`, `user.rb` semblent orphelins
- [x] **Organiser vim/colors/** - Déplacer `peachpuff.vim` dans le dossier approprié
- [x] **Ajouter .gitignore** - Ignorer `.netrwhist`, fichiers temporaires, `*.local`

## Scripts bin/

- [x] **Uniformiser les shebangs** - `#!/usr/bin/env bash` partout
- [x] **Ajouter --help** à tous les scripts - Documentation inline
- [x] **Renommer `git-clean-merged-branchs`** - Typo corrigée
- [x] **Script `kill_port`** - Validation du port (1-65535)
- [x] **Support Linux** - `battery`, `flushdns` cross-platform

## Installation

- [x] **Idempotence install.sh** - Vérifier existence avant création
- [x] **Backup automatique** - Sauvegarde dans `~/.dotfiles_backup/`
- [x] **Dry-run mode** - Option `--dry-run` ajoutée

## Zsh

- [ ] **Migrer vers modern prompt** - Considérer starship ou powerlevel10k
- [x] **Lazy loading** - nvm/rbenv/pyenv chargés à la demande
- [ ] **Complétion moderne** - Ajouter fzf, zoxide pour navigation rapide

## Vim

- [ ] **Migrer vers lazy.nvim** - Vundle obsolète, lazy.nvim plus performant
- [ ] **Nettoyer bundles** - 40+ plugins, certains potentiellement inutilisés
- [ ] **LSP natif neovim** - Considérer nvim-lspconfig vs coc.nvim

## Git

- [ ] **Hooks partagés** - Ajouter pre-commit hooks (lint, tests)
- [ ] **Templates** - PR templates, issue templates

## Sécurité

- [ ] **Audit GPG config** - Vérifier clés expirées
- [x] **SSH config** - Config avec best practices (ed25519, multiplexing)
- [ ] **Secrets management** - Documenter gestion des tokens/API keys

## Documentation

- [x] **README complet** - Quick start, scripts, structure, lazy loading
- [ ] **Changelog** - Historique des changements majeurs
- [ ] **Documenter claude/commands/** - Expliquer workflow Claude

## Nouvelles fonctionnalités

- [x] **Script migration** - `bin/migration` (rsync)
- [x] **Dotfiles diff** - `bin/dotfiles-diff`
- [x] **Health check** - `bin/dotfiles-health`
- [ ] **Profile switching** - Configs work vs personal
