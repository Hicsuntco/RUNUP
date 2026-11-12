#!/usr/bin/env python3
"""Les pages publiées de RUNUP, déclarées une fois — côté outillage.

Le pendant de `RunUp/Models/Liens.swift`, qui raconte ce que neuf copies ont coûté. Les deux
valeurs doivent être identiques, et `check_liens.py` le vérifie.
"""

BASE = "https://hukaia.github.io/RUNUP"

CONFIDENTIALITE = f"{BASE}/privacy.html"
ASSISTANCE = f"{BASE}/support.html"

#: Le fichier du dépôt derrière chaque page publiée. Une URL qui ne pointe sur rien est le
#: deuxième défaut de cette histoire : la page d'assistance existait depuis des semaines, et la
#: fiche App Store envoyait vers la politique de confidentialité à sa place.
FICHIERS = {CONFIDENTIALITE: "privacy.html", ASSISTANCE: "support.html"}
