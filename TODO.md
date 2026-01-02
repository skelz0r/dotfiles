# TODO - Améliorations Dotfiles

## Organisation & Structure

- [ ] **Nettoyer fichiers non versionnés** - `.rubocop.yml`, `Gemfile*`, `sampler.yml`, `user.rb` semblent orphelins
- [x] **Organiser vim/colors/** - Déplacer `peachpuff.vim` dans le dossier approprié
- [x] **Ajouter .gitignore** - Ignorer `.netrwhist`, fichiers temporaires, `*.local`

## Scripts bin/

- [x] **Uniformiser les shebangs** - Mélange de `#!/bin/bash`, `#!/bin/sh`, `#!/usr/bin/env ruby`
- [x] **Ajouter --help** à tous les scripts - Documentation inline manquante
- [x] **Renommer `git-clean-merged-branchs`** - Typo: "branchs" → "branches"
- [x] **Script `kill_port`** - Ajouter validation du port (numérique, range valide)

## Installation

- [x] **Idempotence install.sh** - Vérifier existence avant création symlinks
- [ ] **Support Linux** - Certains scripts hardcodés macOS (`dscacheutil`, `diskutil`)
- [x] **Backup automatique** - Sauvegarder fichiers existants avant symlink
- [x] **Dry-run mode** - Option `--dry-run` pour preview des changements

## Zsh

- [ ] **Migrer vers modern prompt** - Considérer starship ou powerlevel10k
- [ ] **Lazy loading** - nvm/rbenv/pyenv ralentissent le démarrage
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
- [ ] **SSH config** - Ajouter config SSH avec best practices
- [ ] **Secrets management** - Documenter gestion des tokens/API keys

## Documentation

- [ ] **README complet** - Screenshots, prerequisites, quickstart
- [ ] **Changelog** - Historique des changements majeurs
- [ ] **Documenter claude/commands/** - Expliquer workflow Claude

## Nouvelles fonctionnalités

- [x] **Script migration** - Ajouté `bin/migration`
- [ ] **Dotfiles diff** - Comparer config locale vs repo
- [ ] **Health check** - Script vérifiant dépendances installées
- [ ] **Profile switching** - Configs work vs personal
