# Maquettes — <sujet>

<N> options pour un même besoin : <besoin>. Elles ne diffèrent que sur
**<le point de décision>**.

Point d'entrée : `index.html`. Les fichiers vivent dans `~/share/<slug>`,
avec un lien symbolique `mockups/` depuis `<dossier de travail>`.

## Règle d'itération

**Tout est engendré par `build.py`. On itère là, jamais dans les fichiers
HTML**, écrasés à chaque exécution :

```bash
cd ~/share/<slug> && python3 build.py
```

Les écrans communs sont engendrés une seule fois et régénérés dans chaque
option : modifier un fragment le met à jour partout. Le script signale les
liens cassés et les repères sans annotation correspondante.

## Les options

| Option | Écrans | <axe de décision> | Scénario |
|---|---|---|---|
| `option-1` | | | |

## Écrans repris de l'existant

<Quels écrans sont décalqués de pages réelles, d'après quelle capture ou URL,
et ce qui a été ajouté ou retiré par rapport à l'original.>

## Conventions de lecture

- Un bandeau en haut de chaque écran rappelle l'option et la position.
- L'en-tête change de couleur à chaque changement de service : <acteur> en
  <couleur>… Convention propre aux maquettes <, l'en-tête réel de X est Y>.
- Les commentaires sont en marge, numérotés, et renvoient à des repères
  dans l'écran : bleu pour un constat, vert pour un point fort, orange pour
  une faiblesse.
- Toutes les données sont fictives, seul <le nom réel conservé> est réel.

## Ce que les maquettes ne montrent pas

- **<élément retiré>.** <pourquoi : n'existe pas, hors décision, identique
  dans toutes les options>.
