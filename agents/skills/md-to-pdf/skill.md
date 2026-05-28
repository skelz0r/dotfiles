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

Exemple: document pour "Ecocert" -> proposer vert `#2c5530`

## Prérequis

- `pandoc` (conversion Markdown -> HTML)
- `weasyprint` (conversion HTML -> PDF)

Vérifier avec: `which pandoc weasyprint`

## Workflow

1. Créer un fichier CSS temporaire avec le style ci-dessous
2. Convertir le Markdown en HTML avec pandoc: `pandoc input.md -o temp.html --standalone --css=style.css --embed-resources`
3. Convertir le HTML en PDF avec weasyprint: `weasyprint temp.html output.pdf`
4. Nettoyer les fichiers temporaires

## CSS par défaut (style neutre professionnel)

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

table {
  width: 100%;
  border-collapse: collapse;
  margin: 10px 0;
  font-size: 8.5pt;
}

th {
  background: #2d3748;
  color: white;
  padding: 6px 8px;
  text-align: left;
  font-weight: 600;
}

td {
  padding: 5px 8px;
  border-bottom: 1px solid #e2e8f0;
}

tr:nth-child(even) {
  background: #f7fafc;
}

td:last-child, th:last-child {
  text-align: right;
}

strong {
  color: #1a202c;
}

code {
  background: #edf2f7;
  padding: 2px 4px;
  border-radius: 3px;
  font-size: 8pt;
}

pre {
  background: #edf2f7;
  padding: 10px;
  border-radius: 4px;
  font-size: 8pt;
  overflow: hidden;
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
  margin: 6px 0;
  padding-left: 20px;
}

li {
  margin: 3px 0;
}
```

## Personnalisation couleur

Pour changer la couleur principale, remplacer dans le CSS:
- `#2d3748` -> couleur principale (headers tableaux, bordures titres)
- `#1a202c` -> couleur foncée (h1, strong)
- `#f7fafc` -> couleur claire (lignes alternées)

Exemples de palettes:
- **Bleu corporate**: `#1e40af` (principal) / `#1e3a8a` (foncé) / `#eff6ff` (clair)
- **Vert**: `#166534` / `#14532d` / `#f0fdf4`
- **Rouge**: `#b91c1c` / `#991b1b` / `#fef2f2`
- **Violet**: `#6d28d9` / `#5b21b6` / `#f5f3ff`

## Exemple de commande complète

```bash
# Créer le CSS
cat > /tmp/style.css << 'EOF'
[contenu CSS ci-dessus]
EOF

# Markdown -> HTML
pandoc input.md -o /tmp/temp.html --standalone --css=/tmp/style.css --embed-resources

# HTML -> PDF
weasyprint /tmp/temp.html output.pdf 2>/dev/null

# Nettoyer
rm /tmp/style.css /tmp/temp.html
```

## Options avancées

- **Format paysage**: Ajouter `@page { size: A4 landscape; }` dans le CSS
- **Marges réduites**: Modifier `margin: 1cm;` dans `@page`
- **Police plus grande**: Changer `font-size: 9pt;` dans `body`
