---
title: PR #<n> — <sujet> : revue de conception
kicker: <projet> — revue de conception
lang: fr
repo: <owner>/<repo>
sha: <40 caractères, tête de la PR au moment de la revue>
pr: <n>
checkout: <chemin absolu du clone>
---

<!--
Source unique : on itère ici, jamais dans index.html.
  python3 build.py
  python3 build.py --check-urls
-->

La [PR #<n>](pr:) <ce qu'elle apporte, en une phrase>. Cette page ne relit
pas le code ligne à ligne : elle résume les choix de conception à
reprendre et les décisions prises pendant la revue. Liens figés sur
[`<sha7>`](tree:).

::: {.callout .info}
**Les contraintes engagent, les esquisses illustrent**

Chaque axe pose d'abord les contraintes que toute solution doit tenir :
ce sont elles que la revue de la correction vérifiera. Les options et
les extraits de code qui suivent ne servent qu'à rendre une piste
concrète ; s'en écarter est attendu, tant que les contraintes tiennent.
:::

<!-- tab: Vue d'ensemble -->

::: callout
**En une phrase**

<Verdict : ce qui tient, ce qui est à reprendre, et la direction.>
:::

## Ce que la PR fait aujourd'hui

- <mécanisme, avec lien gh:path#Lx-Ly>

## Les grandes lignes de la revue

| Axe | Dans la PR | Contrainte | Détail |
| --- | --- | --- | --- |
| <axe> | <aujourd'hui> | <ce que toute solution doit garantir> | [<sous-onglet>](#<ancre-du-titre>) |

L'onglet [Cible finale](#cible-finale) montre l'interface obtenue à la
fin, d'un seul tenant ; l'onglet Solutions détaille chaque axe.

## Ordre proposé

1. **<refactor préparatoire>.** <pourquoi d'abord>
2. **<la fonctionnalité>** <se pose ensuite sur le refactor>

## Ce qu'on garde tel quel

- <ce qui est bon dans la PR>

<!-- tab: Cible finale -->

## L'interface à la fin du refactor

::: {.callout .info}
**Une cible possible, pas la cible**

Cet onglet assemble les options recommandées de chaque axe, pour montrer
qu'elles tiennent ensemble. Les noms et le code sont illustratifs. Ce qui
engage, ce sont les contraintes de chaque axe, dans l'onglet Solutions.
:::

### Les contraintes, d'un seul tenant

- <ce que toute solution doit garantir, axe par axe>

### Qui fait quoi

| Pièce | Rôle | Ce qu'elle sait de la fonctionnalité |
| --- | --- | --- |
| <pièce> | <rôle unique> | <rien / déclare / orchestre / contenu> |

### Le parcours d'une requête

```text
<requête>
  │
  ├─ <étape> ── <ce qu'elle fait>
  │
  └─ <réponse>
```

### <Pièce>

```ruby
<esquisse dans les idiomes du dépôt>
```

### Ce qu'un nouveau <endpoint, écran, job> doit écrire

1. <déclaration>

### Ce qui disparaît de la PR

| Élément | Remplacé par |
| --- | --- |
| <élément de la PR> | <pièce de la cible> |

<!-- tab: Solutions -->

Chaque sous-onglet part de ce que fait la PR, explique le problème et
décrit la cible, avec les justifications données en revue.

<!-- subtab: <Axe 1> -->

## <Titre de l'axe 1>

### Aujourd'hui

```ruby
<extrait réel du commit figé>
```

[Source](gh:<path>#L<x>-L<y>).

<Le problème, en quelques puces.>

::: callout
**Décision : <la décision>**

<La justification de l'utilisateur, dans ses mots.>
:::

### Contraintes

- <ce que toute solution doit garantir : qui ne doit pas savoir quoi,
  quels chemins doivent s'accorder, ce que le contrat ne doit pas gagner>

### Options

| Option | Pour | Contre |
| --- | --- | --- |
| <option, dont l'idée de l'utilisateur s'il en avait une> | <gain> | <coût> |

Recommandée : <option>, <pourquoi>.

### Esquisse de l'option recommandée

```ruby
# cible (esquisse)
<esquisse>
```

### Conséquences

- <ce qui change ailleurs : specs, doc, autres appelants>

<!-- subtab: <Axe 2> -->

## <Titre de l'axe 2>

<!-- tab: Décisions produit -->

## Décisions produit

### <Sujet>

<Le constat.>

::: callout
**Décision : <accepté, refusé, reporté>**

<La justification de l'utilisateur.>
:::

### Ouvert

- **<question>** <pourquoi elle reste ouverte, qui tranche>

<!-- tab: Notes -->

## Notes mineures

Pour mémoire, rien de bloquant.

- **<sujet>.** <constat, lien>
