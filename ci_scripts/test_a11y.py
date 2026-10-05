#!/usr/bin/env python3
"""Vérifie `check_a11y.py` sur des cas écrits exprès, sans réseau ni Xcode.

Une barrière d'intégration continue qui se trompe coûte plus cher que le défaut qu'elle cherche :
elle bloque une sortie un dimanche soir, et la fois d'après on la contourne. Ce qui est vérifié
ici, c'est donc surtout ce que l'analyseur doit LAISSER PASSER.
"""
import sys
import check_a11y as ck

cas = []


def cas_test(nom):
    def decorateur(f):
        cas.append((nom, f))
        return f
    return decorateur


def attendu(src, nombre, nom):
    trouves = ck.sans_nom(src)
    assert len(trouves) == nombre, f"{nom} : {nombre} attendu(s), {len(trouves)} trouvé(s) → {trouves}"


# ── Le défaut qu'on cherche ───────────────────────────────────────────────────────────────────

@cas_test("un bouton qui n'a qu'une icône est signalé")
def _():
    attendu('''
        Button { fermer() } label: {
            Image(systemName: "xmark")
        }
        .buttonStyle(PressableStyle())
    ''', 1, "icône nue")


@cas_test("la forme Button(action:) est signalée aussi")
def _():
    attendu('''
        Button(action: fermer) {
            Image(systemName: "xmark").font(.system(size: 14))
        }
    ''', 1, "icône nue, forme action:")


@cas_test("un NavigationLink qui n'a qu'un chevron est signalé")
def _():
    attendu('''
        NavigationLink(value: item) {
            Image(systemName: "chevron.right")
        }
    ''', 1, "chevron nu")


# ── Ce qu'il doit laisser passer ──────────────────────────────────────────────────────────────

@cas_test("une icône nommée à la main passe")
def _():
    attendu('''
        Button { fermer() } label: { Image(systemName: "xmark") }
            .accessibilityLabel("Fermer")
    ''', 0, "nommé")


@cas_test("une icône assumée décorative passe")
def _():
    attendu('''
        Button { rien() } label: { Image(systemName: "sparkles") }
            .accessibilityHidden(true)
    ''', 0, "décoratif")


@cas_test("une icône fusionnée avec un voisin qui parle passe")
def _():
    attendu('''
        Button { ouvrir() } label: { Image(systemName: "gear") }
            .accessibilityElement(children: .combine)
    ''', 0, "fusionné")


@cas_test("une icône accompagnée de texte passe")
def _():
    attendu('''
        Button { partager() } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Partager")
            }
        }
    ''', 0, "icône + texte")


@cas_test("un bouton sans icône n'est pas regardé")
def _():
    attendu('Button("CONTINUER") { suivant() }', 0, "texte seul")


@cas_test("un bouton nommé par une variable n'est pas regardé")
def _():
    # Il a un nom ; ce script ne sait simplement pas lequel. Le doute profite au code.
    attendu('Button(monLibelle) { agir() }', 0, "libellé variable")


# ── Les pièges de l'analyse ───────────────────────────────────────────────────────────────────

@cas_test("un bouton cité dans un commentaire ne compte pas")
def _():
    attendu('''
        // Avant, c'était un Button { Image(systemName: "lock") } purement décoratif.
        let x = 1
    ''', 0, "commentaire")


@cas_test("une accolade dans un commentaire ne décale pas la fin du bouton")
def _():
    attendu('''
        Button { fermer() } label: {
            // Une accolade orpheline { dans un commentaire, et un "guillemet orphelin
            Image(systemName: "xmark")
        }
        .accessibilityLabel("Fermer")
    ''', 0, "accolade commentée")


@cas_test("une accolade dans une chaîne ne décale pas la fin du bouton")
def _():
    attendu('''
        Button { envoyer("{") } label: {
            Image(systemName: "paperplane")
        }
        .accessibilityLabel("Envoyer")
    ''', 0, "accolade en chaîne")


@cas_test("le nom doit appartenir au bouton, pas à son voisin")
def _():
    # Le défaut classique de l'analyse naïve : avaler le frère suivant et croire qu'on est nommé.
    attendu('''
        Button { a() } label: { Image(systemName: "xmark") }
        Button { b() } label: { Image(systemName: "gear") }
            .accessibilityLabel("Réglages")
    ''', 1, "voisin nommé")


@cas_test("deux boutons nus donnent deux signalements")
def _():
    attendu('''
        Button { a() } label: { Image(systemName: "xmark") }
        Button { b() } label: { Image(systemName: "gear") }
    ''', 2, "deux nus")


@cas_test("un modificateur à closure ne coupe pas la chaîne avant le nom")
def _():
    attendu('''
        Button { a() } label: { Image(systemName: "bell") }
            .overlay(alignment: .topTrailing) {
                Circle().fill(.red).frame(width: 6, height: 6)
            }
            .accessibilityLabel("Notifications")
    ''', 0, "overlay puis nom")


def main():
    echecs = 0
    for nom, f in cas:
        try:
            f()
            print(f"  ok   {nom}")
        except AssertionError as e:
            echecs += 1
            print(f"  ÉCHEC {nom}\n        {e}")
    print(f"\n{len(cas) - echecs}/{len(cas)} cas passent.")
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
