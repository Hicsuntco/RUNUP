import Foundation

/// The 101 real French départements, each with the URL slug `runningmap.org` uses for its
/// département-filtered race calendar (`/course-a-pied/france/{slug}`) — no public API exists for
/// official race listings in France (checked: neither the FFA calendar nor RunningMap.org, the
/// only two real sources, expose one), so rather than store or fabricate race data ourselves,
/// "Courses officielles" deep-links out to RunningMap.org's own always-current calendar, already
/// filtered to whichever département she picks. This list is stable reference data (the
/// départements themselves), not the races — nothing here goes stale the way a cached race list
/// would.
struct FrenchDepartement: Identifiable, Hashable {
    var id: String { slug }
    var name: String
    var code: String
    var slug: String

    var calendarURL: URL {
        URL(string: "https://runningmap.org/course-a-pied/france/\(slug)")!
    }
}

extension FrenchDepartement {
    static let all: [FrenchDepartement] = [
        .init(name: "Ain", code: "01", slug: "ain-01"),
        .init(name: "Aisne", code: "02", slug: "aisne-02"),
        .init(name: "Allier", code: "03", slug: "allier-03"),
        .init(name: "Alpes-de-Haute-Provence", code: "04", slug: "alpes-de-haute-provence-04"),
        .init(name: "Hautes-Alpes", code: "05", slug: "hautes-alpes-05"),
        .init(name: "Alpes-Maritimes", code: "06", slug: "alpes-maritimes-06"),
        .init(name: "Ardèche", code: "07", slug: "ardeche-07"),
        .init(name: "Ardennes", code: "08", slug: "ardennes-08"),
        .init(name: "Ariège", code: "09", slug: "ariege-09"),
        .init(name: "Aube", code: "10", slug: "aube-10"),
        .init(name: "Aude", code: "11", slug: "aude-11"),
        .init(name: "Aveyron", code: "12", slug: "aveyron-12"),
        .init(name: "Bouches-du-Rhône", code: "13", slug: "bouches-du-rhone-13"),
        .init(name: "Calvados", code: "14", slug: "calvados-14"),
        .init(name: "Cantal", code: "15", slug: "cantal-15"),
        .init(name: "Charente", code: "16", slug: "charente-16"),
        .init(name: "Charente-Maritime", code: "17", slug: "charente-maritime-17"),
        .init(name: "Cher", code: "18", slug: "cher-18"),
        .init(name: "Corrèze", code: "19", slug: "correze-19"),
        .init(name: "Corse-du-Sud", code: "2A", slug: "corse-du-sud-201"),
        .init(name: "Haute-Corse", code: "2B", slug: "haute-corse-202"),
        .init(name: "Côte-d'Or", code: "21", slug: "cote-dor-21"),
        .init(name: "Côtes-d'Armor", code: "22", slug: "cotes-darmor-22"),
        .init(name: "Creuse", code: "23", slug: "creuse-23"),
        .init(name: "Dordogne", code: "24", slug: "dordogne-24"),
        .init(name: "Doubs", code: "25", slug: "doubs-25"),
        .init(name: "Drôme", code: "26", slug: "drome-26"),
        .init(name: "Eure", code: "27", slug: "eure-27"),
        .init(name: "Eure-et-Loir", code: "28", slug: "eure-et-loir-28"),
        .init(name: "Finistère", code: "29", slug: "finistere-29"),
        .init(name: "Gard", code: "30", slug: "gard-30"),
        .init(name: "Haute-Garonne", code: "31", slug: "haute-garonne-31"),
        .init(name: "Gers", code: "32", slug: "gers-32"),
        .init(name: "Gironde", code: "33", slug: "gironde-33"),
        .init(name: "Hérault", code: "34", slug: "herault-34"),
        .init(name: "Ille-et-Vilaine", code: "35", slug: "ile-et-vilaine-35"),
        .init(name: "Indre", code: "36", slug: "indre-36"),
        .init(name: "Indre-et-Loire", code: "37", slug: "indre-et-loire-37"),
        .init(name: "Isère", code: "38", slug: "isere-38"),
        .init(name: "Jura", code: "39", slug: "jura-39"),
        .init(name: "Landes", code: "40", slug: "landes-40"),
        .init(name: "Loir-et-Cher", code: "41", slug: "loir-et-cher-41"),
        .init(name: "Loire", code: "42", slug: "loire-42"),
        .init(name: "Haute-Loire", code: "43", slug: "haute-loire-43"),
        .init(name: "Loire-Atlantique", code: "44", slug: "loire-atlantique-44"),
        .init(name: "Loiret", code: "45", slug: "loiret-45"),
        .init(name: "Lot", code: "46", slug: "lot-46"),
        .init(name: "Lot-et-Garonne", code: "47", slug: "lot-et-garonne-47"),
        .init(name: "Lozère", code: "48", slug: "lozere-48"),
        .init(name: "Maine-et-Loire", code: "49", slug: "maine-et-loire-49"),
        .init(name: "Manche", code: "50", slug: "manche-50"),
        .init(name: "Marne", code: "51", slug: "marne-51"),
        .init(name: "Haute-Marne", code: "52", slug: "haute-marne-52"),
        .init(name: "Mayenne", code: "53", slug: "mayenne-53"),
        .init(name: "Meurthe-et-Moselle", code: "54", slug: "meurthe-et-moselle-54"),
        .init(name: "Meuse", code: "55", slug: "meuse-55"),
        .init(name: "Morbihan", code: "56", slug: "morbihan-56"),
        .init(name: "Moselle", code: "57", slug: "moselle-57"),
        .init(name: "Nièvre", code: "58", slug: "nievre-58"),
        .init(name: "Nord", code: "59", slug: "nord-59"),
        .init(name: "Oise", code: "60", slug: "oise-60"),
        .init(name: "Orne", code: "61", slug: "orne-61"),
        .init(name: "Pas-de-Calais", code: "62", slug: "pas-de-calais-62"),
        .init(name: "Puy-de-Dôme", code: "63", slug: "puy-de-dome-63"),
        .init(name: "Pyrénées-Atlantiques", code: "64", slug: "pyrenees-atlantiques-64"),
        .init(name: "Hautes-Pyrénées", code: "65", slug: "hautes-pyrenees-65"),
        .init(name: "Pyrénées-Orientales", code: "66", slug: "pyrenees-orientales-66"),
        .init(name: "Bas-Rhin", code: "67", slug: "bas-rhin-67"),
        .init(name: "Haut-Rhin", code: "68", slug: "haut-rhin-68"),
        .init(name: "Rhône", code: "69", slug: "rhone-69"),
        .init(name: "Haute-Saône", code: "70", slug: "haute-saone-70"),
        .init(name: "Saône-et-Loire", code: "71", slug: "saone-et-loire-71"),
        .init(name: "Sarthe", code: "72", slug: "sarthe-72"),
        .init(name: "Savoie", code: "73", slug: "savoie-73"),
        .init(name: "Haute-Savoie", code: "74", slug: "haute-savoie-74"),
        .init(name: "Paris", code: "75", slug: "paris-75"),
        .init(name: "Seine-Maritime", code: "76", slug: "seine-maritime-76"),
        .init(name: "Seine-et-Marne", code: "77", slug: "seine-et-marne-77"),
        .init(name: "Yvelines", code: "78", slug: "yvelines-78"),
        .init(name: "Deux-Sèvres", code: "79", slug: "deux-sevres-79"),
        .init(name: "Somme", code: "80", slug: "somme-80"),
        .init(name: "Tarn", code: "81", slug: "tarn-81"),
        .init(name: "Tarn-et-Garonne", code: "82", slug: "tarn-et-garonne-82"),
        .init(name: "Var", code: "83", slug: "var-83"),
        .init(name: "Vaucluse", code: "84", slug: "vaucluse-84"),
        .init(name: "Vendée", code: "85", slug: "vendee-85"),
        .init(name: "Vienne", code: "86", slug: "vienne-86"),
        .init(name: "Haute-Vienne", code: "87", slug: "haute-vienne-87"),
        .init(name: "Vosges", code: "88", slug: "vosges-88"),
        .init(name: "Yonne", code: "89", slug: "yonne-89"),
        .init(name: "Territoire de Belfort", code: "90", slug: "territoire-de-belfort-90"),
        .init(name: "Essonne", code: "91", slug: "essonne-91"),
        .init(name: "Hauts-de-Seine", code: "92", slug: "hauts-de-seine-92"),
        .init(name: "Seine-Saint-Denis", code: "93", slug: "seine-saint-denis-93"),
        .init(name: "Val-de-Marne", code: "94", slug: "val-de-marne-94"),
        .init(name: "Val-d'Oise", code: "95", slug: "val-doise-95"),
        .init(name: "Guadeloupe", code: "971", slug: "guadeloupe-971"),
        .init(name: "Martinique", code: "972", slug: "martinique-972"),
        .init(name: "Guyane", code: "973", slug: "guyane-973"),
        .init(name: "Réunion", code: "974", slug: "reunion-974"),
        .init(name: "Mayotte", code: "976", slug: "mayotte-976")
    ]
}
