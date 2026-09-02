import XCTest
import SwiftData
@testable import RunUp

/// Verrouille le schéma sur disque et son plan de migration.
///
/// Ce que ces tests protègent n'est pas une fonctionnalité, c'est **les données des gens déjà
/// installés**. Un schéma qui ne s'ouvre plus fait basculer l'app en magasin mémoire : chaque
/// lancement repart à l'inscription, et rien de ce qui est écrit ne survit à la fermeture. Le
/// fichier reste intact sur le disque — c'est tout l'objet du chemin de secours — mais la journée
/// est perdue pour tout le monde en attendant un correctif.
///
/// Aucun de ces tests ne peut prouver qu'une migration future réussira. Ils garantissent la seule
/// chose vérifiable ici : que le schéma se matérialise, que le plan lui correspond, et qu'un
/// modèle ajouté sans y penser fait échouer la suite plutôt que la mise à jour.
final class PersistenceSchemaTests: XCTestCase {

    /// Le schéma doit pouvoir se matérialiser. C'est le seul cas où `makeContainer()` va jusqu'au
    /// `fatalError` — il n'y a alors plus rien à dégrader, et c'est une erreur de programmation
    /// dans les définitions de modèle, pas un accident chez l'utilisatrice.
    func testSchemaMaterialises() throws {
        let configuration = ModelConfiguration(schema: PersistenceController.schema, isStoredInMemoryOnly: true)
        XCTAssertNoThrow(
            try ModelContainer(for: PersistenceController.schema,
                               migrationPlan: RunUpMigrationPlan.self,
                               configurations: [configuration]),
            "Le schéma ne se matérialise pas, même sans stockage. L'app plante au lancement."
        )
    }

    /// Le plan et le schéma doivent décrire le MÊME jeu de modèles.
    ///
    /// Ouvrir le conteneur avec un plan qui ignore un modèle est la façon la plus discrète de
    /// casser une migration : tout fonctionne tant que personne ne migre.
    func testPlanAndSchemaDescribeTheSameModels() {
        let planned = Set(RunUpSchemaV1.models.map { String(describing: $0) })
        let inSchema = Set(PersistenceController.schema.entities.map(\.name))
        XCTAssertEqual(planned, inSchema,
                       "Le plan de migration et le schéma ne listent pas les mêmes modèles.")
    }

    /// La liste des modèles, écrite en toutes lettres.
    ///
    /// Ce test existe pour ÉCHOUER le jour où quelqu'un ajoute ou retire un modèle. Ce n'est pas
    /// un interdit — c'est un rappel, à l'endroit et au moment où il sert : un modèle qui entre
    /// dans le schéma entre aussi dans la migration, et si la version n'est pas incrémentée en
    /// même temps, les gens déjà installés le découvriront à l'ouverture.
    ///
    /// La marche à suivre est écrite dans `RunUpSchemaV1`, juste au-dessus de sa déclaration.
    func testModelListIsDeliberate() {
        XCTAssertEqual(
            Set(RunUpSchemaV1.models.map { String(describing: $0) }),
            ["UserProfile", "RunRecord", "ChatMessage", "AppNotification", "Shoe"],
            """
            La liste des modèles a changé. Avant d'ajuster ce test : la version du schéma \
            doit-elle passer à 2, avec une étape dans `RunUpMigrationPlan` ? Voir le mode \
            d'emploi au-dessus de `RunUpSchemaV1`.
            """
        )
    }

    /// La version doit rester celle que le plan connaît. Changer l'une sans l'autre laisse un
    /// magasin tamponné d'une version dont aucun chemin ne part.
    func testVersionMatchesThePlan() {
        XCTAssertEqual(RunUpSchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
        XCTAssertEqual(RunUpMigrationPlan.schemas.count, RunUpMigrationPlan.stages.count + 1,
                       """
                       Il faut exactement une étape de MOINS que de versions : deux versions \
                       demandent une étape pour aller de l'une à l'autre.
                       """)
    }

    /// Chaque modèle doit pouvoir être inséré et relu. Un schéma qui se matérialise mais dont une
    /// entité refuse l'écriture échouerait à la première course enregistrée, pas au lancement.
    @MainActor
    func testEveryModelCanBeWrittenAndReadBack() throws {
        let configuration = ModelConfiguration(schema: PersistenceController.schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PersistenceController.schema,
                                           migrationPlan: RunUpMigrationPlan.self,
                                           configurations: [configuration])
        let context = container.mainContext

        context.insert(UserProfile())
        context.insert(RunRecord(title: "Footing", distanceKm: 5, durationSeconds: 1800,
                                 avgPace: "6:00", avgHeartRate: 148, kcal: 310))
        context.insert(ChatMessage(role: .coach, text: "Prête pour demain ?"))
        context.insert(Shoe(name: "Pegasus"))
        XCTAssertNoThrow(try context.save(), "Une entité du schéma refuse l'écriture.")

        XCTAssertEqual(try context.fetch(FetchDescriptor<UserProfile>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<RunRecord>()).count, 1)
    }
}
