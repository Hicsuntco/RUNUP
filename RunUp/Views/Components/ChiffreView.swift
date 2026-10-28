import SwiftUI

/// UN CHIFFRE ET SON UNITÉ, COMPOSÉS UNE FOIS.
///
/// # NEUF FOIS LE MÊME OBJET, NEUF TRAITEMENTS
///
/// L'app pose un grand nombre suivi de son unité à neuf endroits, et aucun ne ressemblait aux
/// autres :
///
///     ClubView (séances tenues)     .small     regular   text2
///     ClubView (km de la semaine)   .small     bold      text2
///     RUStatTile                    .micro     regular   text3
///     WeekKmSummary                 .small     semibold  text3
///     HomeView (tuile de stat)      .small     medium    text3
///     LiveRunView                   .micro     bold + tracking 1,5   Ink.label
///     StatsView (allure récente)    .emphasis  regular   text2
///     WeeklyRecapView               .body      regular   text2
///     FriendsView                   .small     semibold  text3
///
/// Quatre tailles, cinq graisses, trois couleurs. Personne n'a jamais décidé ça : chaque écran a
/// été composé séparément, et l'unité a pris ce qui tombait sous la main. C'est le même défaut
/// que les vingt-six tailles de titrage et les dix-neuf écarts, à ceci près qu'il porte sur
/// l'objet le plus regardé d'une app de course — le chiffre.
///
/// # LE TRAITEMENT RETENU, ET POURQUOI CELUI-LÀ
///
/// L'unité en `.small` demi-gras moyen, `text3`.
///
///   • `.small` (13,1 pt) et non `.micro` (10,6) : à côté d'un chiffre de 30,5 pt, `.micro` donne
///     un rapport de 2,9 — l'unité cesse d'être lisible et devient de la décoration. `.small`
///     donne 2,3, ce qui la laisse nettement subordonnée tout en restant un mot qu'on lit.
///     Et surtout pas `.emphasis` ni `.body` : à 20 pt à côté d'un 48, l'unité RIVALISE.
///   • `.medium` et non `regular` ni `bold` : en gras, l'unité tire l'œil avant le chiffre ; en
///     régulière, elle ressemble à du texte courant égaré dans une carte. Moyenne, elle lit
///     comme une étiquette, ce qu'elle est.
///   • `text3` et non `text2` : le système réserve `text2` à la prose secondaire et `text3` à
///     TOUTES ses micro-étiquettes — la règle est déjà écrite dans `eyebrowStyle`. Une unité est
///     une micro-étiquette.
///
/// # LES CHIFFRES À CHASSE FIXE NE SONT PAS ICI
///
/// Ils sont dans `RUFont.display`, parce que le problème n'était pas propre à ce composant :
/// trois fichiers appelaient `.monospacedDigit()` à la main et tous les autres l'oubliaient, donc
/// les colonnes de l'app dansaient partout sauf à trois endroits.
struct RUChiffre: View {
    /// Déjà mis en forme — « 8,1 », « 42:17 », « 9 240 ». Jamais une clé de catalogue, d'où le
    /// `verbatim` plus bas : « 8,1 » cherché dans Localizable n'y est pas, et ne doit pas l'être.
    var valeur: String
    /// « km », « KM », « /km », « au départ en moyenne ». Passé par `LocalizedStringKey` pour que
    /// les unités qui SONT des clés se traduisent, les autres retombant sur leur texte brut —
    /// même mécanisme et même raison que `EyebrowLabel`.
    var unite: String? = nil
    var cran: RUDisplaySize = .figure
    var couleur: Color = RUColor.textPrimary
    /// Pour les fonds qui ne sont pas ceux du thème — l'écran de course en cours a son propre
    /// encrier. Le défaut couvre tout le reste.
    var couleurDeLUnite: Color = RUColor.text3

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(verbatim: valeur)
                .displayStyle(cran)
                .foregroundColor(couleur)
                // Le chiffre rétrécit plutôt que de se couper : dans une tuile de grille il n'a
                // qu'un demi-écran, et « 1 2… » ne veut rien dire.
                .lineLimit(1).minimumScaleFactor(0.6)
            if let unite {
                Text(LocalizedStringKey(unite))
                    .font(RUFont.sans(.small, weight: .medium))
                    .foregroundColor(couleurDeLUnite)
            }
        }
        // Le chiffre et son unité sont UNE valeur : « 8,1 » puis, deux arrêts plus loin, « km »
        // oblige à recoller les deux de tête.
        .accessibilityElement(children: .combine)
    }
}
