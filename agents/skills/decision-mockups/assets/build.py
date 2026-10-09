#!/usr/bin/env python3
"""Generates the decision mockups. Edit this file, then run `python3 build.py`.

Every HTML file is overwritten on each run: never edit them by hand.
"""

import html
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).parent

TITLE = "Paiement : page du prestataire ou formulaire intégré"
INTRO = """
    <p>Deux façons d'encaisser une commande sur la Boutique Exemple. Elles ne diffèrent que sur <b>l'endroit où la carte est saisie</b> — et donc qui porte la conformité et l'expérience du paiement.</p>
    <p>Chaque option se déroule du panier jusqu'à l'écran final. Aucune donnée n'est transmise, les identités sont fictives.</p>
"""
FOOTER = "Maquettes — aucune donnée n'est transmise, les identités sont fictives."

LABELS = {
    "annotations": "Annotations",
    "position": "écran {num} sur {total}",
    "off_path": "écran hors parcours",
    "back_to_index": "Toutes les options",
    "screens": "{n} écrans",
    "walk": "Dérouler le parcours",
    "scenario": "Scénario.",
    "requires": "Ce que ça demande.",
    "matrix": "Synthèse",
    "criterion": "Critère",
    "screens_row": "Écrans",
    "reading": "Lire les maquettes",
    "you_are_on": "Vous êtes sur {name}",
    "actors_legend": "L'en-tête change de couleur à chaque changement de service : {actors}. C'est une convention propre à ces maquettes, pour rendre visible qui affiche quoi.",
    "notes_legend": "Les commentaires sont en marge, numérotés, et renvoient à des repères dans l'écran : {info} un constat, {good} un point fort, {weak} une faiblesse.",
    "not_shown": "Ce que les maquettes ne montrent pas",
}

LOGO = ""

ACTORS = {
    "shop": {"name": "Boutique Exemple", "tag": "Commande", "style": "light", "legend": "blanc"},
    "psp": {"name": "Paiement Exemple", "tag": "Page de paiement sécurisée", "style": "primary", "legend": "sombre"},
}
INDEX_ACTOR = "shop"

CLIENT = "Camille DUPONT"
CLIENT_MAIL = "camille.dupont@exemple.fr"
ORDER = "C-10042"
AMOUNT = "42,00 €"

OPTIONS = {
    "option-1": {
        "label": "Option 1",
        "title": "Page du prestataire",
        "where": "paiement chez le prestataire",
        "scenario": "Le client est redirigé vers la page de paiement du prestataire, saisit sa carte, puis revient sur la boutique.",
        "requires": "Presque rien côté boutique : une redirection et une URL de retour. Le prestataire porte la conformité.",
        "reco": False,
    },
    "option-2": {
        "label": "Option 2",
        "title": "Formulaire intégré",
        "where": "paiement sur la boutique",
        "scenario": "Le client ne quitte jamais la boutique. Les champs de carte sont fournis par le prestataire et intégrés à la page.",
        "requires": "Intégrer le SDK du prestataire, gérer les erreurs de paiement et l'authentification forte dans notre page.",
        "reco": True,
    },
}

CRITERIA = [
    ("Rupture de parcours", {
        "option-1": ("weak", "Oui, aller-retour chez le prestataire"),
        "option-2": ("good", "Aucune"),
    }),
    ("Conformité des données de carte", {
        "option-1": ("good", "Entièrement chez le prestataire"),
        "option-2": ("info", "Champs hébergés par le prestataire, page chez nous"),
    }),
    ("Travail côté boutique", {
        "option-1": ("good", "Redirection et URL de retour"),
        "option-2": ("weak", "SDK, erreurs, authentification forte"),
    }),
    ("Connaissance du résultat", {
        "option-1": ("weak", "Dépend d'une notification serveur"),
        "option-2": ("good", "Réponse synchrone"),
    }),
]

NOT_SHOWN = [
    "<b>Le remboursement.</b> Identique dans les deux options : c'est de l'outillage interne, pas un écran client.",
]


KINDS = ("info", "good", "weak")
WALKTHROUGHS = []


def m(n, kind="info"):
    suffix = "" if kind == "info" else f" marker--{kind}"
    return f'<span class="marker{suffix}">{n}</span>'


def header(actor_key):
    actor = ACTORS[actor_key]
    style = actor.get("style", "light")
    modifier = "" if style == "light" else f" who--{style}"
    hdr_modifier = "" if style == "light" else f" hdr--{style}"
    logo = actor.get("logo", LOGO)
    return f"""<div class="who{modifier}">{LABELS["you_are_on"].format(name=actor["name"])}</div>
<div class="hdr{hdr_modifier}"><div class="hdr-in">
  {logo}
  <div><div class="name">{actor["name"]}</div><div class="tag">{actor.get("tag", "")}</div></div>
</div></div>"""


def notes_html(notes):
    if not notes:
        return '<div class="notes"></div>'
    out = [f'<div class="notes"><h2>{LABELS["annotations"]}</h2>']
    for i, (kind, title, body) in enumerate(notes, 1):
        modifier = "" if kind == "info" else f" note--{kind}"
        out.append(f'<div class="note{modifier}"><span class="n">{i}</span>'
                   f'<div><b>{title}</b><p>{body}</p></div></div>')
    out.append("</div>")
    return "\n".join(out)


def document(*, title, strip, actor, body, notes, narrow, single=False):
    layout = "layout layout--single" if single else "layout"
    main = "main main--narrow" if narrow else "main"
    notes_block = "" if single else notes_html(notes)
    return f"""<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>{title}</title>
<link rel="stylesheet" href="{"style.css" if single else "../style.css"}">
</head>
<body>
{strip}
{header(actor)}
<div class="{layout}">
  <div class="{main}">
{body}
  </div>
{notes_block}
</div>
<footer><div class="in">{FOOTER}</div></footer>
</body>
</html>
"""


MARKER_PATTERN = re.compile(r'class="marker(?: marker--(good|weak))?">(\d+)<')


def check_markers(where, body, notes):
    for kind, number in MARKER_PATTERN.findall(body):
        kind = kind or "info"
        index = int(number)
        if index > len(notes):
            warn(f"{where}: marker {index} has no annotation")
        elif notes[index - 1][0] != kind:
            warn(f"{where}: marker {index} is {kind}, annotation is {notes[index - 1][0]}")
    for kind, _, _ in notes:
        if kind not in KINDS:
            warn(f"{where}: unknown annotation kind {kind!r}")


class Walkthrough:
    def __init__(self, key):
        self.key = key
        self.option = OPTIONS[key]
        self.screens = []
        self.asides = []
        WALKTHROUGHS.append(self)

    def screen(self, name, **kwargs):
        self.screens.append((name, kwargs))

    def aside(self, name, **kwargs):
        self.asides.append((name, kwargs))

    @property
    def first(self):
        return f"{self.key}/{self.screens[0][0]}"

    def write(self):
        total = len(self.screens)
        for num, (name, kwargs) in enumerate(self.screens, 1):
            self._write(name, LABELS["position"].format(num=num, total=total), **kwargs)
        for name, kwargs in self.asides:
            self._write(name, LABELS["off_path"], **kwargs)

    def _write(self, name, position, *, title, actor, body, notes=(), narrow=True):
        label = self.option["label"]
        strip = (f'<div class="strip"><b>{label}</b> · {self.option["title"]} · {position}'
                 f'<a href="../index.html">{LABELS["back_to_index"]}</a></div>')
        check_markers(f"{self.key}/{name}", body, notes)
        path = ROOT / self.key / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(document(title=f"{label} — {title}", strip=strip, actor=actor,
                                 body=body, notes=notes, narrow=narrow), encoding="utf-8")


def mail(*, sender, to, subject, body):
    return f"""    <div class="mail">
      <div class="mail-h">
        <div><b>De</b> {sender}</div>
        <div><b>À</b> {to}</div>
        <div><b>Objet</b> {subject}</div>
      </div>
      <div class="mail-b">
{body}
      </div>
    </div>"""


def http(*, caption, method, path, request="", status, response=""):
    status_class = "st-ok" if str(status).startswith("2") else "st-ko"
    return f"""    <div class="http">
      <div class="http-cap">{caption}</div>
      <div class="http-grid">
        <div class="http-part"><h4>Requête</h4><p class="http-line">{method} {html.escape(path)}</p><pre>{html.escape(request)}</pre></div>
        <div class="http-part"><h4>Réponse</h4><p class="http-line"><span class="{status_class}">{html.escape(str(status))}</span></p><pre>{html.escape(response)}</pre></div>
      </div>
    </div>"""


def terminal(lines):
    rendered = []
    for line in lines:
        if line.startswith("$ "):
            rendered.append(f'<span class="prompt">$</span> {html.escape(line[2:])}')
        else:
            rendered.append(f'<span class="dim">{html.escape(line)}</span>')
    return '    <div class="term">' + "\n".join(rendered) + "</div>"


def sequence(steps):
    items = "\n".join(f'      <li><span class="who-acts">{actor}</span><span>{text}</span></li>'
                      for actor, text in steps)
    return f'    <ol class="seq">\n{items}\n    </ol>'


def code(text):
    return f'    <div class="code"><pre>{html.escape(text)}</pre></div>'


def screen_cart(w, *, next_href, notes_extra=()):
    w.screen("1-panier.html", title="Panier", actor="shop", body=f"""
    <h1>Votre panier</h1>
    <div class="callout"><p><b>Ceci est un exemple.</b> Le client, la commande et les montants sont fictifs, ici comme sur tous les écrans qui suivent.{m(1)}</p></div>
    <div class="card">
      <div class="card-h"><h2>Commande {ORDER}</h2><span class="aside">{CLIENT}</span></div>
      <p>1 × Carnet de notes — {AMOUNT}</p>
    </div>
    <div class="acts"><a class="btn" href="{next_href}">Payer {AMOUNT}</a></div>
""", notes=[
        ("info", "Toutes les données sont fictives",
         "Client, commande, montants : rien ne désigne une personne réelle, sur aucun écran."),
        *notes_extra,
    ])


def option_1():
    w = Walkthrough("option-1")
    screen_cart(w, next_href="2-paiement.html")

    w.screen("2-paiement.html", title="Page du prestataire", actor="psp", body=f"""
    <h1>Paiement de {AMOUNT}</h1>
    <p>Boutique Exemple — commande {ORDER}{m(1, "good")}</p>
    <div class="card">
      <div class="fg"><label for="cc">Numéro de carte <span class="req">*</span></label><input type="text" id="cc"></div>
      <div class="cols">
        <div class="fg"><label for="exp">Expiration <span class="req">*</span></label><input type="text" id="exp"></div>
        <div class="fg"><label for="cvc">Cryptogramme <span class="req">*</span></label><input type="text" id="cvc"></div>
      </div>
    </div>
    <div class="acts">
      <a class="btn" href="3-confirmation.html">Payer</a>
      <a class="btn btn2" href="abandon.html">Et si le client ferme l'onglet&nbsp;?{m(2, "weak")}</a>
    </div>
""", notes=[
        ("good", "Rien à développer",
         "La page existe chez le prestataire : on n'y maîtrise que le logo et l'URL de retour."),
        ("weak", "Le retour n'est pas garanti",
         "Si le client ferme l'onglet après le paiement, la boutique ne l'apprend que par la notification serveur."),
    ])

    w.screen("3-confirmation.html", title="Confirmation", actor="shop", body=f"""
    <div class="banner-ok"><h1>Commande payée</h1><p>Commande {ORDER} — {AMOUNT}</p></div>
    <p>Un reçu a été envoyé à {CLIENT_MAIL}.{m(1, "weak")}</p>
""", notes=[
        ("weak", "Sur quoi s'appuie ce message ?",
         "Une redirection ne prouve pas le paiement : il faut attendre la notification serveur ou interroger le prestataire."),
    ])

    w.aside("abandon.html", title="Onglet fermé", actor="shop", body=f"""
    <div class="banner-ko"><h1>Paiement en attente</h1><p>Commande {ORDER}</p></div>
    <p>Nous n'avons pas encore reçu la confirmation de votre paiement.{m(1, "weak")}</p>
    <div class="acts"><a class="btn btn2" href="2-paiement.html">Revenir à l'écran précédent</a></div>
""", notes=[
        ("weak", "Le client ne sait pas s'il a payé",
         "Il risque de payer deux fois. L'écran doit se mettre à jour dès réception de la notification."),
    ])
    return w


def option_2():
    w = Walkthrough("option-2")
    screen_cart(w, next_href="2-paiement.html")

    w.screen("2-paiement.html", title="Formulaire intégré", actor="shop", body=f"""
    <h1>Paiement de {AMOUNT}</h1>
    <div class="card">
      <div class="card-h"><h2>Carte bancaire</h2><span class="aside">Champs fournis par Paiement Exemple{m(1)}</span></div>
      <div class="fg"><label for="cc">Numéro de carte <span class="req">*</span></label><input type="text" id="cc"></div>
      <div class="cols">
        <div class="fg"><label for="exp">Expiration <span class="req">*</span></label><input type="text" id="exp"></div>
        <div class="fg"><label for="cvc">Cryptogramme <span class="req">*</span></label><input type="text" id="cvc"></div>
      </div>
    </div>
    <div class="acts"><a class="btn" href="3-serveur.html">Payer{m(2, "good")}</a></div>
""", notes=[
        ("info", "Les champs restent chez le prestataire",
         "Intégrés dans notre page, mais la carte ne transite jamais par nos serveurs."),
        ("good", "Aucune rupture de parcours",
         "Le client reste sur la boutique du panier à la confirmation."),
    ])

    w.screen("3-serveur.html", title="Côté serveur", actor="shop", narrow=False, body=f"""
    <h1>Ce qui se passe au clic</h1>
    <p>Écran technique : ce que le client ne voit pas, mais qui distingue cette option.</p>
{sequence([
        ("Navigateur", "envoie la carte au prestataire, reçoit un jeton à usage unique"),
        ("Boutique", "confirme le paiement avec ce jeton"),
        ("Prestataire", "répond de façon synchrone"),
    ])}
{http(caption=f"Confirmation du paiement{m(1, 'good')}", method="POST", path="/v1/payments",
      request='{\n  "token": "tok_exemple",\n  "amount": 4200,\n  "order": "C-10042"\n}',
      status="201 Created", response='{\n  "id": "pay_exemple",\n  "status": "succeeded"\n}')}
    <div class="acts"><a class="btn" href="4-confirmation.html">Écran suivant</a></div>
""", notes=[
        ("good", "Le résultat est connu tout de suite",
         "Pas d'attente de notification pour afficher la confirmation."),
    ])

    w.screen("4-confirmation.html", title="Confirmation", actor="shop", body=f"""
    <div class="banner-ok"><h1>Commande payée</h1><p>Commande {ORDER} — {AMOUNT}</p></div>
    <p>Un reçu a été envoyé à {CLIENT_MAIL}.</p>
""")
    return w


def index():
    cards = []
    for w in WALKTHROUGHS:
        option = w.option
        reco = " opt--reco" if option.get("reco") else ""
        where = " · ".join(filter(None, [LABELS["screens"].format(n=len(w.screens)), option.get("where")]))
        cards.append(f"""      <div class="opt{reco}">
        <div class="where">{where}</div>
        <h3>{option["label"]}. {option["title"]}</h3>
        <div class="grow">
          <p><b>{LABELS["scenario"]}</b> {option["scenario"]}</p>
          <p><b>{LABELS["requires"]}</b> {option["requires"]}</p>
        </div>
        <a class="btn" href="{w.first}">{LABELS["walk"]}</a>
      </div>""")

    head = "".join(('<th class="reco">' if w.option.get("reco") else "<th>") + w.option["label"] + "</th>"
                   for w in WALKTHROUGHS)
    rows = ["<tr><th>{}</th>{}</tr>".format(
        LABELS["screens_row"], "".join(f"<td>{len(w.screens)}</td>" for w in WALKTHROUGHS))]
    for criterion, cells in CRITERIA:
        tds = []
        for w in WALKTHROUGHS:
            kind, text = cells.get(w.key, ("", ""))
            tds.append(f'<td class="{kind}">{text}</td>')
        rows.append(f"<tr><th>{criterion}</th>{''.join(tds)}</tr>")
    matrix = f"""    <h2>{LABELS["matrix"]}</h2>
    <div class="matrix-wrap"><table class="matrix">
      <thead><tr><th>{LABELS["criterion"]}</th>{head}</tr></thead>
      <tbody>
        {chr(10).join(rows)}
      </tbody>
    </table></div>"""

    actors = ", ".join(f'<b>{a["name"]}</b> en {a.get("legend", a.get("style", "light"))}' for a in ACTORS.values())
    reading = [f'    <h2>{LABELS["reading"]}</h2>']
    if len(ACTORS) > 1:
        reading.append(f'    <p>{LABELS["actors_legend"].format(actors=actors)}</p>')
    reading.append("    <p>" + LABELS["notes_legend"].format(
        info=m(1), good=m(2, "good"), weak=m(3, "weak")) + "</p>")
    if NOT_SHOWN:
        reading.append(f'    <h2>{LABELS["not_shown"]}</h2>\n    <ul>'
                       + "".join(f"<li>{item}</li>" for item in NOT_SHOWN) + "</ul>")

    body = f"""    <h1>{TITLE}</h1>
{INTRO}
    <div class="opts">
{chr(10).join(cards)}
    </div>
{matrix}
{chr(10).join(reading)}"""
    (ROOT / "index.html").write_text(
        document(title=TITLE, strip="", actor=INDEX_ACTOR, body=body, notes=(), narrow=False, single=True),
        encoding="utf-8")


def warn(message):
    WARNINGS.append(message)


WARNINGS = []
HREF_PATTERN = re.compile(r'href="([^"#]+)"')


def clean():
    for key in OPTIONS:
        for page in (ROOT / key).glob("*.html"):
            page.unlink()


def check_links():
    for page in ROOT.rglob("*.html"):
        for target in HREF_PATTERN.findall(page.read_text(encoding="utf-8")):
            if re.match(r"^[a-z]+:", target):
                continue
            if not (page.parent / target).resolve().exists():
                warn(f"{page.relative_to(ROOT)}: broken link {target}")


if __name__ == "__main__":
    clean()
    for build in (option_1, option_2):
        build().write()
    index()
    check_links()
    for message in WARNINGS:
        print(f"warning: {message}", file=sys.stderr)
    print(f"{sum(len(w.screens) + len(w.asides) for w in WALKTHROUGHS)} screens, "
          f"{len(WALKTHROUGHS)} options, {len(WARNINGS)} warnings")
