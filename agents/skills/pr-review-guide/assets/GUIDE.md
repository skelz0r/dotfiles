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

<!-- Avant / après quand la PR change un comportement : une liste par
couloir, un nœud par élément ; deux couloirs d'un même flow commencent par
des puces différentes (- puis *). -->

::: flows
::: {.flow title="avant"}
- <point d'entrée>
- <étape>
- [<ce qui sort, et pourquoi c'est faux>]{.none}
:::

::: {.flow title="cette PR"}
- <point d'entrée>
- ↓ <étiquette de flèche, facultative>
- <étape>
  - [<issue attendue>]{.ok}
  - <autre issue>
:::
:::

## Ce que la PR livre

| Surface | Ce qu'on y trouve |
| --- | --- |
| <route, écran, commande, SDK> | <ce que l'utilisateur y voit ou y obtient> |

## Ce qu'on peut survoler

<!-- Chiffres tirés du diff (git diff --numstat), pas estimés. -->

::: {.chart .stack}
**Lignes ajoutées par zone**

| Zone | Lignes |
| --- | --- |
| <zone> | <N> |
:::

| Zone | Volume | Nature |
| --- | --- | --- |
| [`<dossier généré>`](tree:<dossier>) | +<N> / −<N> | généré par `<commande>` |

<Ce qui garantit que les fichiers générés correspondent au code.> Le code
écrit à la main tient en environ <N> lignes, détaillées dans l'onglet
« Architecture ».

## Changements visibles par les utilisateurs

<!-- Quand des specs mesurent une valeur par cas (notifications envoyées,
requêtes, erreurs), la même valeur sur la branche de base et sur la PR,
relevée en exécutant les specs sur le code de base. Une ligne aux cellules
de valeur vides est un intertitre. Sans cible, retirer target. -->

::: {.chart .bars target=1}
**<Valeur mesurée>, par cas**

<D'où viennent les chiffres : quelles specs, sur quel commit.>

| Cas | <branche de base> | cette PR |
| --- | --- | --- |
| <groupe> | | |
| <cas> | <N> | <N> |
:::

| Avant | Après | Pourquoi |
| --- | --- | --- |
| <comportement> | <comportement> | <raison> |

<!-- Une décision qui repose sur une supposition est présentée comme telle. -->

::: {.callout .warning}
**Hypothèse**

<Ce qu'on suppose, pourquoi, et qui devra s'adapter si c'est faux.>
:::

<!-- tab: Design -->
<!-- Seulement si la PR touche une interface. Voir references/design.md. -->

::: callout
**Fonctionnel, design à reprendre**

<Ce que la feature permet, en deux phrases.> Les écrans ci-dessous sont la
version fonctionnelle, posée sans maquette. Livrable attendu : <où le
designer dépose ses maquettes, nommé comme dans son outil>.
:::

## Le parcours

::: steps
1. **<Verbe>.** <Ce que fait l'utilisateur à cette étape.>
2. **<Verbe>.** <…>
:::

<!-- subtab: Écrans -->

## <Moment du parcours>

<Ce qui se passe à ce moment, en une ou deux phrases.>

::: gallery
::: shot
![<Titre de l'écran>](img/<capture>.png)

**<Titre de l'écran>**

<Ce qu'on y voit, ou l'état montré.>
:::
:::

<Ce que les captures ne montrent pas : animation, vibration, état
impossible à figer.>

<!-- subtab: À redessiner -->

## À redessiner en priorité

::: cards
::: card
[<Écran · zone>]{.where}

**<Élément>**

<Ce qui manque, et ce qu'il doit faire.>
:::
:::

## Ce que le système impose

<Composants natifs qu'on peut teinter mais pas remplacer sans coût.>

## Contraintes à garder

- **<Contrainte>.** <Pourquoi, venue du code ou d'un échec.>

<!-- subtab: Règles -->

## Règles à respecter

| Règle | Détail |
| --- | --- |
| <Taille, titre, droits…> | <La règle métier, telle que le code l'applique> |

<!-- subtab: États et textes -->

## Les états à couvrir

| # | Brique | Où | États à couvrir |
| --- | --- | --- | --- |
| 1 | <élément> | <écrans> | <repos, chargement, vide, erreur, plein, désactivé…> |

## Tous les textes affichés

| Brique | Texte |
| --- | --- |
| <élément> | « <texte exact relevé dans le code> » · « <…> » |

<!-- subtab: Tokens -->

## Les tokens de l'app

| Token | Valeur | Rôle |
| --- | --- | --- |
| [`<token>`](gh:<fichier du design system>) | <valeur> | <où il sert> |

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

<!-- Quand le cas traverse une interface, chaque étape qui produit ou lit un
écran montre ses captures juste après sa requête, dans une petite galerie. -->

::: gallery
::: shot
![<Ce que montre la capture>](img/<capture>.png)

**<Ce que montre la capture>**

<Le lien avec la requête ou la réponse ci-dessus.>
:::
:::

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
