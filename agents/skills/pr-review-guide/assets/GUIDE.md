---
title: PR #<n> — <sujet> : guide de revue
kicker: <projet> — guide de revue
lang: fr
repo: <owner>/<repo>
sha: <40 caractères, tête de la branche poussée>
pr: <n>
checkout: <chemin absolu du clone ou du worktree>
---

<!--
Source unique du guide : on itère ici, jamais dans index.html.
  python3 build.py               # zéro warning attendu
  python3 build.py --check-urls  # avant de publier
Les commentaires HTML comme celui-ci ne sont pas publiés.
-->

La [PR #<n>](pr:) fait <N> fichiers et <N> lignes, dont l'essentiel est
<généré | mécanique>. Ce guide dit ce qui a changé, où regarder et dans quel
ordre. Les liens pointent sur le commit [`<sha7>`](tree:), tête de la branche
au moment de la rédaction.

<!-- tab: Vue d'ensemble -->

::: callout
**En une phrase**

<Ce que la PR change, pour qui, et ce qui garantit que ça tient.>
:::

## Ce que la PR livre

| Surface | Ce qu'on y trouve |
| --- | --- |
| <route, écran, commande, SDK> | <ce que l'utilisateur y voit ou y obtient> |

## Ce qu'on peut survoler

<!-- Chiffres tirés du diff (git diff --numstat), pas estimés. -->

| Zone | Volume | Nature |
| --- | --- | --- |
| [`<dossier généré>`](tree:<dossier>) | +<N> / −<N> | généré par `<commande>` |

<Ce qui garantit que les fichiers générés correspondent au code.> Le code
écrit à la main tient en environ <N> lignes, détaillées dans l'onglet
« Architecture ».

## Changements visibles par les utilisateurs

| Avant | Après | Pourquoi |
| --- | --- | --- |
| <comportement> | <comportement> | <raison> |

<!-- Une décision qui repose sur une supposition est présentée comme telle. -->

::: {.callout .warning}
**Hypothèse**

<Ce qu'on suppose, pourquoi, et qui devra s'adapter si c'est faux.>
:::

<!-- tab: Exemple de bout en bout -->

## <Un cas réel, nommé>, de la déclaration à l'écran

<Le cas choisi et pourquoi il est représentatif.>

### 1. Ce que le code déclare

<Chaque extrait est suivi du lien vers la ligne concernée.>

```ruby
<extrait réel>
```

### 2. Ce que le système en déduit

### 3. Ce que l'utilisateur peut consulter

<!-- Dire ce qui distingue cette étape de la précédente : « ce qui peut
arriver » n'est pas « ce qui arrive ». -->

### 4. Ce que reçoit l'appelant quand ça arrive

```http
HTTP/1.1 <statut> <raison>
Content-Type: application/json
```

```json
<réponse réelle, tronquée explicitement avec "…">
```

### 5. Ce que l'écran affiche

![<ce que montre la capture>](img/<capture>.png)

<!-- tab: Architecture -->

## 1. <Première brique>

[`<fichier>`](gh:<chemin>#L<n>-L<m>) — <son rôle en une phrase>.

<!-- tab: Garde-fous -->

## Ce qui empêche une régression

| Test | Échoue quand |
| --- | --- |
| [`<spec>`](gh:<chemin>) | <condition> |

## Ce que voit un développeur qui se trompe

```
<message d'échec réel, copié de la sortie du test>
```

## Limites connues

- <Ce que les garde-fous ne voient pas, et pourquoi.>

<!-- tab: Commits & tests -->

## Lire la PR commit par commit

| # | Commit | À regarder |
| --- | --- | --- |
| 1 | [<sujet>](commit:<sha>) | <fichiers ou idée> |

## Tester

```bash
<commandes exactes, dans le bon dossier>
```
