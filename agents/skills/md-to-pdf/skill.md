# Skill: Markdown to PDF

Génère un PDF stylé depuis un fichier Markdown.

## Trigger

Utiliser quand l'utilisateur demande de convertir un Markdown en PDF, ou de "faire un PDF" depuis un document.

## Personnalisation contextuelle

**Toujours adapter les couleurs au contexte du projet/client.**

Avant de générer le PDF:
1. Regarder si le projet a une charte graphique connue (logo, couleurs dans les fichiers existants)
2. Demander à l'utilisateur s'il veut une couleur spécifique ou utiliser le style neutre
3. Si le document mentionne un client/entreprise, proposer d'adapter les couleurs

Exemple: document pour "Ecocert" -> proposer vert `#2c5530`. Document DINUM / `.gouv.fr` -> proposer bleu Marianne DSFR `#000091`.

## Prérequis

- `pandoc` (conversion Markdown -> HTML)
- `weasyprint` (conversion HTML -> PDF)

Vérifier avec: `which pandoc weasyprint`

Installation si manquant: `brew install pandoc weasyprint` (macOS) ou `apt install pandoc weasyprint` (Debian/Ubuntu).

## Workflow

1. **Pré-traiter le markdown** (cf. section "Pré-traitement obligatoire") : ajouter les lignes vides manquantes avant les listes, sinon pandoc ne les reconnait pas.
2. Créer un fichier CSS temporaire avec le style ci-dessous.
3. Convertir le Markdown en HTML avec pandoc : `pandoc input.md -o /tmp/temp.html --standalone --css=/tmp/style.css --embed-resources`
   - **NE PAS passer `--metadata title=...`** : pandoc créerait un titre en plus du H1 du markdown, créant un double titre dans le PDF.
4. Convertir le HTML en PDF avec weasyprint : `weasyprint /tmp/temp.html output.pdf`
5. Nettoyer les fichiers temporaires.

## Pré-traitement obligatoire : lignes vides avant les listes

Pandoc (en mode markdown strict / CommonMark) exige une **ligne vide** entre un paragraphe et le début d'une liste. Sans cette ligne, les items ne sont pas reconnus comme une liste et apparaissent en texte continu dans le PDF.

Problème typique :

```markdown
La plateforme :
1. Récupère les données
2. Génère un PDF
```

Pandoc traitera ça comme une suite de paragraphes, pas une liste.

Correctif automatique avec ce script Python à exécuter avant pandoc :

```python
import re, sys

path = sys.argv[1]
with open(path) as f:
    lines = f.readlines()

result = []
for line in lines:
    is_list_item = re.match(r'^([0-9]+\.|[-*+])\s', line)
    if is_list_item and result:
        prev = result[-1]
        prev_is_list = re.match(r'^([0-9]+\.|[-*+])\s', prev)
        prev_is_continuation = re.match(r'^\s{2,}', prev)
        prev_is_blank = prev.strip() == ''
        if not (prev_is_list or prev_is_continuation or prev_is_blank):
            result.append('\n')
    result.append(line)

with open(path, 'w') as f:
    f.writelines(result)
```

À appeler : `python3 fix_lists.py input.md` avant le pandoc.

**Important** : ce script modifie le markdown source. Si l'utilisateur ne veut pas modifier son source, faire une copie d'abord.

## CSS par défaut (style neutre professionnel)

Ce CSS gère correctement le **wrapping** (texte qui passe à la ligne dans les tableaux, code, URLs, items de liste multi-paragraphes). Ne pas l'alléger sans raison, chaque règle traite un cas vu en production.

```css
@page {
  size: A4;
  margin: 1.5cm;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
  font-size: 9pt;
  line-height: 1.4;
  color: #333;
  word-wrap: break-word;
  overflow-wrap: break-word;
}

h1 {
  font-size: 16pt;
  color: #1a202c;
  border-bottom: 2px solid #2d3748;
  padding-bottom: 8px;
  margin-top: 20px;
}

h2 {
  font-size: 12pt;
  color: #2d3748;
  margin-top: 16px;
  border-bottom: 1px solid #e2e8f0;
  padding-bottom: 4px;
}

h3 {
  font-size: 10pt;
  color: #4a5568;
  margin-top: 12px;
}

blockquote {
  background: #fffbeb;
  border-left: 4px solid #f59e0b;
  padding: 10px 15px;
  margin: 15px 0;
  font-size: 8.5pt;
}

blockquote strong {
  color: #b45309;
}

/* Tableaux : table-layout fixed + word-wrap pour forcer le respect
   des largeurs de colonnes et faire passer le texte à la ligne. */
table {
  width: 100%;
  border-collapse: collapse;
  margin: 10px 0;
  font-size: 8.5pt;
  table-layout: fixed;
  word-wrap: break-word;
}

th {
  background: #2d3748;
  color: white;
  padding: 6px 8px;
  text-align: left;
  font-weight: 600;
  word-wrap: break-word;
}

td {
  padding: 5px 8px;
  border-bottom: 1px solid #e2e8f0;
  word-wrap: break-word;
  overflow-wrap: break-word;
  vertical-align: top;
}

tr:nth-child(even) {
  background: #f7fafc;
}

strong {
  color: #1a202c;
}

/* Code inline : break-all pour permettre la coupure des URLs / tokens
   longs qui sinon débordent de la cellule ou de la page. */
code {
  background: #edf2f7;
  padding: 2px 4px;
  border-radius: 3px;
  font-size: 8pt;
  word-break: break-all;
  overflow-wrap: anywhere;
}

/* Pre : pre-wrap pour préserver la mise en forme tout en autorisant
   le retour à la ligne (vs overflow:hidden qui couperait). */
pre {
  background: #edf2f7;
  padding: 10px;
  border-radius: 4px;
  font-size: 8pt;
  white-space: pre-wrap;
  word-wrap: break-word;
  overflow-wrap: break-word;
}

pre code {
  background: transparent;
  padding: 0;
  word-break: normal;
}

hr {
  border: none;
  border-top: 1px solid #e2e8f0;
  margin: 20px 0;
}

p {
  margin: 6px 0;
}

ul, ol {
  margin: 8px 0;
  padding-left: 22px;
}

li {
  margin: 5px 0;
  word-wrap: break-word;
  overflow-wrap: break-word;
}

/* Items de liste avec plusieurs paragraphes : garder un peu d'espace
   entre les paragraphes mais coller au bord de l'item (pas de double
   marge en début/fin). NE PAS mettre display:inline qui collapserait
   les paragraphes en une seule ligne. */
li p {
  margin: 4px 0;
}

li p:first-child {
  margin-top: 0;
}

li p:last-child {
  margin-bottom: 0;
}

li > ul, li > ol {
  margin: 4px 0;
}
```

## Personnalisation couleur

Pour changer la couleur principale, remplacer dans le CSS:
- `#2d3748` -> couleur principale (headers tableaux, bordures titres, h2)
- `#1a202c` -> couleur foncée (h1, strong)
- `#f7fafc` -> couleur claire (lignes alternées des tableaux)

Exemples de palettes:
- **Bleu corporate**: `#1e40af` (principal) / `#1e3a8a` (foncé) / `#eff6ff` (clair)
- **Vert**: `#166534` / `#14532d` / `#f0fdf4`
- **Rouge**: `#b91c1c` / `#991b1b` / `#fef2f2`
- **Violet**: `#6d28d9` / `#5b21b6` / `#f5f3ff`
- **Bleu Marianne DSFR** (gouv français): `#000091` / `#000074` / `#f5f5fe`

## Considérations typographiques

- **Tirets cadratins (`—`)** : weasyprint les rend bien, mais si le document est destiné à être réutilisé en texte brut (mail, paste), envisager de les remplacer par des tirets demi-cadratin ou des virgules.
- **Caractères accentués** : aucun problème avec le `-apple-system` font stack. S'assurer que le markdown est en UTF-8.
- **Code long / URLs / tokens** : grâce à `word-break: break-all` sur `code`, les chaînes longues se coupent. Pour les chemins UNIX qu'on ne veut pas couper, utiliser du texte normal au lieu de `` `code` ``.

## Exemple de commande complète

```bash
# 1. Pré-traiter le markdown (ajout lignes vides avant listes)
python3 -c "
import re
path = 'input.md'
with open(path) as f: lines = f.readlines()
result = []
for line in lines:
    is_li = re.match(r'^([0-9]+\.|[-*+])\s', line)
    if is_li and result:
        p = result[-1]
        if not (re.match(r'^([0-9]+\.|[-*+])\s', p) or re.match(r'^\s{2,}', p) or p.strip()==''):
            result.append('\n')
    result.append(line)
with open(path, 'w') as f: f.writelines(result)
"

# 2. Créer le CSS
cat > /tmp/style.css << 'EOF'
[contenu CSS ci-dessus]
EOF

# 3. Markdown -> HTML (PAS de --metadata title, ça crée un double titre)
pandoc input.md -o /tmp/temp.html --standalone --css=/tmp/style.css --embed-resources

# 4. HTML -> PDF
weasyprint /tmp/temp.html output.pdf 2>/dev/null

# 5. Nettoyer
rm /tmp/style.css /tmp/temp.html
```

## Options avancées

- **Format paysage**: Ajouter `@page { size: A4 landscape; }` dans le CSS
- **Marges réduites**: Modifier `margin: 1cm;` dans `@page`
- **Police plus grande**: Changer `font-size: 9pt;` dans `body`
- **Colonnes de tableau de largeurs spécifiques**: ajouter `colgroup` dans le markdown HTML brut, ou utiliser `nth-child(n) { width: X%; }` sur `th`/`td`

## Troubleshooting

| Symptôme | Cause probable | Correctif |
|----------|----------------|-----------|
| Listes apparaissent en paragraphe continu | Pas de ligne vide avant la liste dans le markdown | Pré-traitement (cf. section dédiée) |
| Double titre en haut du PDF | `--metadata title` passé à pandoc en plus du H1 | Retirer l'option `--metadata title` |
| Texte de tableau déborde / est coupé | Cellule sans wrapping | Vérifier `table-layout: fixed` + `word-wrap: break-word` sur `td` |
| URLs longues dépassent de la page | `code` sans break | Vérifier `word-break: break-all` sur `code` |
| Items de liste multi-paragraphes collés sur une ligne | CSS `li > p { display: inline }` | Retirer ce style, utiliser `margin: 0` à la place |
| Avertissements weasyprint sur `gap` / `overflow-x` | CSS par défaut de pandoc | Ignorables, sans impact visuel |
| `weasyprint: command not found` | Pas installé | `brew install weasyprint` ou `pip install weasyprint` |
| Caractères mal rendus | Markdown pas en UTF-8 | `file -I input.md` pour vérifier l'encodage |
