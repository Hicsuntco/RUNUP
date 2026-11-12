#!/usr/bin/env python3
"""La semaine du plan ne s'écrit QU'À LA GÉNÉRATION.

Le programme est regénéré : au passage de semaine, à chaque changement de réglage, et même
sans que personne ne demande rien — l'allègement du coach expire tout seul au lancement et
déclenche la régénération. Tout ce qui est écrit à la main dans `weekSessions` disparaît donc
au passage suivant.

Deux changements l'avaient oublié. Le déplacement d'une séance permutait deux jours de
`weekSessions` ; l'allègement du jour y réécrivait la séance du jour. Les deux disparaissaient
sans un mot, et le second pouvait RENDRE LA SÉANCE PLUS DURE que la demande qui l'avait
allégée : allégée à 42 minutes en souple le matin, revenue à 45 minutes avec ses intervalles
dès qu'elle écrivait au coach « j'ai mal au genou, allège ».

Aucun des deux défauts n'avait de symptôme. La semaine restait pleine, les séances restaient
justes, rien ne plantait. C'est pour ça que la règle se vérifie ici plutôt que de se répéter
en commentaire : ce qui survit à une régénération, ce sont les ENTRÉES du générateur — voir
`RunUp/Models/ChangementDemande.swift` et `RunUp/Models/TrainingEase.swift`.

LA RÈGLE, ÉTROITE EXPRÈS. Une version large — « aucun champ de séance ne se modifie hors du
moteur » — noierait le rapport sous les constructions légitimes de séances (`CaptureSeed`,
`CourseLibre`, les tests). Ce qui est tenu ici est exactement ce qui a cassé :

  • `…weekSessions[…] = …` et `…weekSessions[…].session = …` sont interdits partout. Poser une
    séance à la main dans la semaine, c'est écrire quelque chose que la prochaine génération
    jettera. Seul `.completed` est permis : il marque ce qui A EU LIEU, et la génération le
    reporte explicitement.
  • `…weekSessions = …` n'est permis qu'au moteur, et seulement depuis `generateWeekSessions`
    ou un instantané d'annulation du coach — plus la restauration d'une sauvegarde.
"""
import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
DOSSIERS = ["RunUp", "RunUpWatch"]

MOTEUR = "RunUp/Services/AdaptivePlanEngine.swift"
RESTAURATION = "RunUp/Services/SauvegardeService.swift"
PRODUCTEURS = ("generateWeekSessions(", "snapshot.weekSessions")

# Un `=` d'affectation, et non une comparaison ou un opérateur composé.
AFFECTATION = re.compile(r"(?<![=!<>+\-*/%&|^~])=(?!=)")


def code_nu(source: str) -> str:
    """Le source sans ses commentaires ni ses littéraux de chaîne.

    Écrit à la main et non par expression régulière, pour la raison trouvée en écrivant
    `check_prive.py` : un découpage naïf des chaînes efface aussi ce qu'il y a DANS une
    interpolation, c'est-à-dire du vrai code. Ici on remplace la chaîne par un jeton et on garde
    les interpolations, qui peuvent parfaitement contenir une affectation.
    """
    sortie = []
    i, n = 0, len(source)
    while i < n:
        deux = source[i:i + 2]
        if deux == "//":
            fin = source.find("\n", i)
            i = n if fin == -1 else fin
        elif deux == "/*":
            fin = source.find("*/", i + 2)
            i = n if fin == -1 else fin + 2
        elif source[i] == '"':
            # Une chaîne : on la remplace par un jeton, en laissant passer le contenu des
            # interpolations `\(…)`, qui est du code.
            i += 1
            sortie.append('""')
            profondeur = 0
            while i < n:
                if source[i] == "\\" and source[i:i + 2] == "\\(":
                    profondeur += 1
                    i += 2
                    debut = i
                    niveau = 1
                    while i < n and niveau:
                        if source[i] == "(":
                            niveau += 1
                        elif source[i] == ")":
                            niveau -= 1
                        i += 1
                    sortie.append(source[debut:i - 1])
                    profondeur -= 1
                elif source[i] == "\\":
                    i += 2
                elif source[i] == '"':
                    i += 1
                    break
                elif source[i] == "\n":
                    break
                else:
                    i += 1
        else:
            sortie.append(source[i])
            i += 1
    return "".join(sortie)


def ecarts_dans(relatif: str, source: str):
    """La règle, sur UN fichier, sans toucher au disque.

    Séparée du parcours de l'arborescence pour que `test_entrees.py` puisse la nourrir
    d'extraits figés. Un test qui relirait le dépôt passerait tant que la faute y est, et
    échouerait à la seconde où elle est corrigée.
    """
    problemes = []
    nu = code_nu(source)
    for numero, ligne in enumerate(nu.splitlines(), start=1):
        if "weekSessions" not in ligne:
            continue
        # TOUTES les affectations de la ligne, pas seulement la première.
        #
        # `if let v = p.weekSessions { profil.weekSessions = v }` en porte deux, et c'est la
        # SECONDE qui écrit. Une version ne regardant que la première laissait passer cette
        # forme-là — qui est précisément celle du fichier de restauration, donc une forme qu'on
        # recopie. Le côté gauche se lit depuis le dernier séparateur d'instruction, sinon la
        # première moitié de la ligne s'y retrouverait.
        for trouve in AFFECTATION.finditer(ligne):
            gauche = ligne[:trouve.start()]
            coupe = max(gauche.rfind(c) for c in "{};")
            gauche = gauche[coupe + 1:].strip()
            droite = ligne[trouve.end():].strip()
            problemes.extend(
                (numero, g, r) for g, r in _verdict(relatif, gauche, droite)
            )
    return problemes


def _verdict(relatif: str, gauche: str, droite: str):
    """Ce qu'il faut dire d'UNE affectation, ou rien."""
    if ".weekSessions[" in gauche:
        if gauche.endswith(".completed"):
            return
        yield (
            gauche,
            "Une séance posée à la main dans la semaine sera effacée par la prochaine "
            "génération. Enregistre une ENTRÉE du générateur (voir "
            "`ChangementDemande.swift`) ; seul `.completed` s'écrit ici.",
        )
    elif gauche.endswith(".weekSessions"):
        if relatif == RESTAURATION:
            return
        # LE SQUELETTE VIDE N'EST PAS UN PLAN. `UserProfile.init` pose sept jours sans
        # séance, parce qu'une propriété de `@Model` doit avoir une valeur. Il n'y a là
        # aucune séance à effacer, et la règle n'a rien à dire. Reconnu à `session: nil` et
        # non au fichier : écrire une VRAIE séance au même endroit reste un défaut, et
        # serait signalé.
        if "session: nil" in droite:
            return
        if relatif == MOTEUR and any(p in droite for p in PRODUCTEURS):
            return
        yield (
            gauche,
            "La semaine entière ne se remplace qu'au moteur, depuis `generateWeekSessions` "
            "ou un instantané d'annulation du coach.",
        )


def ecarts():
    problemes = []
    for dossier in DOSSIERS:
        racine = RACINE / dossier
        if not racine.is_dir():
            continue
        for fichier in sorted(racine.rglob("*.swift")):
            relatif = fichier.relative_to(RACINE).as_posix()
            for numero, gauche, raison in ecarts_dans(relatif, fichier.read_text(encoding="utf-8")):
                problemes.append((relatif, numero, gauche, raison))
    return problemes


def main() -> int:
    problemes = ecarts()
    if problemes:
        print(f"{len(problemes)} écriture(s) à la main dans la semaine du plan :\n")
        for relatif, numero, gauche, raison in problemes:
            print(f"  • {relatif}:{numero} — {gauche} = …")
            for bout in raison.split(". "):
                if bout:
                    print(f"      {bout.rstrip('.')}.")
            print()
        print("Voir l'en-tête de RunUp/Models/ChangementDemande.swift.")
        return 1
    print("Semaine du plan : aucune séance écrite à la main, elle ne vient que du générateur.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
