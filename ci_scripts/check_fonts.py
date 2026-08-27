#!/usr/bin/env python3
"""Refuse un build où une police demandée par le code n'est pas livrée.

`Font.custom("Nom-Graisse", …)` ne lève rien quand le nom est introuvable : SwiftUI retombe en
silence sur la police système. Un nom mal orthographié, un fichier oublié dans une cible, une
famille dont le nom PostScript n'est pas celui qu'on croit — rien de tout ça ne casse le build ni
ne produit d'avertissement. Ça se voit seulement sur l'appareil, écran par écran.

Ce script fait ce que le compilateur ne fait pas. Pour chaque cible, il compare :
  - les noms que le code demande (littéraux + interpolations \\(DisplayFont.family) et
    \\(bodyFamily), résolues depuis les constantes),
  - les fichiers que l'Info.plist de CETTE cible enregistre dans UIAppFonts,
  - les noms PostScript réellement contenus dans ces fichiers.

Une police livrée mais non enregistrée est inerte ; une police enregistrée dans une cible ne l'est
pas dans les autres. Les trois listes doivent coïncider, cible par cible.
"""
import re, struct, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
FONT_DIR = ROOT / "RunUp/Resources/Fonts"


def postscript_name(path):
    """Le nom PostScript (name ID 6) — celui que `Font.custom` attend, pas le nom de famille."""
    d = path.read_bytes()
    n = struct.unpack(">H", d[4:6])[0]
    tables = {}
    for i in range(n):
        o = 12 + 16 * i
        tag = d[o:o + 4].decode("latin1")
        off, ln = struct.unpack(">II", d[o + 8:o + 16])
        tables[tag] = (off, ln)
    if "name" not in tables:
        return None
    off = tables["name"][0]
    count, str_off = struct.unpack(">HH", d[off + 2:off + 6])
    for i in range(count):
        o = off + 6 + 12 * i
        pid, _eid, _lid, nid, ln, so = struct.unpack(">HHHHHH", d[o:o + 12])
        if nid != 6:
            continue
        raw = d[off + str_off + so: off + str_off + so + ln]
        try:
            return raw.decode("utf-16-be") if pid == 3 else raw.decode("latin1")
        except UnicodeDecodeError:
            continue
    return None


def constants():
    """Les familles nommées une seule fois dans le code, à résoudre dans les interpolations."""
    out = {}
    src = (ROOT / "RunUp/Shared/DisplayFont.swift").read_text(encoding="utf-8")
    m = re.search(r'static let family\s*=\s*"([^"]+)"', src)
    if m:
        out["DisplayFont.family"] = m.group(1)
        out["family"] = m.group(1)
    typo = (ROOT / "RunUp/DesignSystem/Typography.swift").read_text(encoding="utf-8")
    m = re.search(r'bodyFamily\s*=\s*(?:DisplayFont\.family|"([^"]+)")', typo)
    if m:
        out["bodyFamily"] = m.group(1) or out.get("DisplayFont.family", "")
    return out


def requested_names(swift_files, consts):
    """Tous les noms passés à `.custom(...)`, interpolations résolues."""
    names = {}
    pat = re.compile(r'\.custom\(\s*"((?:[^"\\]|\\\([^)]*\))*)"')
    for f in swift_files:
        for i, line in enumerate(f.read_text(encoding="utf-8").split("\n"), 1):
            for raw in pat.findall(line):
                resolved = raw
                for var in re.findall(r"\\\(([^)]*)\)", raw):
                    key = var.strip()
                    if key not in consts:
                        print(f"  ! interpolation non résolue \\({key}) dans {f}:{i}")
                        return None
                    resolved = resolved.replace(f"\\({var})", consts[key])
                names.setdefault(resolved, f"{f.relative_to(ROOT)}:{i}")
    return names


def registered(target_block):
    """Les fichiers listés dans l'UIAppFonts de cette cible, dans project.yml."""
    m = re.search(r"UIAppFonts:\n((?:\s*-\s*\S+\n)+)", target_block)
    if not m:
        return []
    return re.findall(r"-\s*(\S+\.ttf)", m.group(1))


def main():
    consts = constants()
    if not consts.get("DisplayFont.family"):
        print("ECHEC: impossible de lire DisplayFont.family")
        return 1
    print(f"Famille déclarée : {consts['DisplayFont.family']}")

    ps = {}
    for f in sorted(FONT_DIR.glob("*.ttf")):
        name = postscript_name(f)
        if not name:
            print(f"ECHEC: {f.name} n'expose aucun nom PostScript")
            return 1
        ps[f.name] = name

    project = (ROOT / "project.yml").read_text(encoding="utf-8")
    # Chaque cible commence en colonne 2 dans `targets:` ; on découpe là-dessus.
    blocks = re.split(r"\n  (?=\w[\w]*:\n)", project.split("targets:", 1)[1])
    targets = {}
    for b in blocks:
        m = re.match(r"\s*(\w+):", b)
        if m:
            targets[m.group(1)] = b

    def source_paths(block):
        """Les chemins que CETTE cible compile, lus dans project.yml plutôt que devinés.

        Les deviner est précisément l'erreur que ce script existe pour attraper : la montre ne
        prend de `RunUp/Shared` que deux fichiers nommés un par un, et le widget n'y prend pas
        `DesignSystem` du tout. Une liste écrite à la main ici finirait par diverger du projet
        réel, et ce script se mettrait à valider une cible qui n'existe pas.
        """
        m = re.search(r"\n    sources:\n(.*?)(?=\n    \w+:|\Z)", block, re.S)
        if not m:
            return []
        return re.findall(r"-\s*path:\s*(\S+)", m.group(1))

    failed = False
    failed = False
    for target, block in targets.items():
        files = registered(block)
        if not files:
            continue  # une cible sans UIAppFonts ne dessine aucun texte à elle
        missing_files = [f for f in files if f not in ps]
        if missing_files:
            print(f"ECHEC [{target}]: UIAppFonts référence des fichiers absents : {missing_files}")
            failed = True
        available = {ps[f] for f in files if f in ps}

        swift = []
        for d in source_paths(block):
            path = ROOT / d
            if path.is_dir():
                swift += sorted(path.rglob("*.swift"))
            elif path.suffix == ".swift" and path.exists():
                swift.append(path)
        names = requested_names(swift, consts)
        if names is None:
            return 1
        unknown = {n: loc for n, loc in names.items() if n not in available}
        print(f"[{target}] {len(names)} noms demandés, {len(files)} polices enregistrées "
              f"→ {'OK' if not unknown else str(len(unknown)) + ' INTROUVABLE(S)'}")
        for n, loc in sorted(unknown.items()):
            print(f"    « {n} » demandé en {loc} — retombera en silence sur la police système")
            print(f"      disponibles ici : {', '.join(sorted(available))}")
            failed = True

    if failed:
        print("\nUne police demandée n'est pas livrée dans la cible qui la demande.")
        return 1
    print("\nToutes les polices demandées sont livrées et enregistrées dans leur cible.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
