import Foundation

/// Exécuter sur l'acteur principal un rappel système dont on SAIT qu'il y arrive déjà.
///
/// # POURQUOI CE N'EST PAS UNE `Task`
///
/// Le dépôt saute déjà sur l'acteur principal à deux endroits — `WatchSessionService` et
/// `VoiceCoachController` — et il y écrit `Task { @MainActor in … }`. C'est la bonne réponse
/// là-bas : WatchConnectivity et `AVSpeechSynthesizer` appellent leur délégué depuis LEUR file,
/// jamais depuis le fil principal, donc le saut est obligatoire et son coût n'a aucune
/// importance — il s'agit d'un état à poser, pas d'une mesure à accumuler.
///
/// CoreLocation, lui, livre ses rappels sur la boucle d'exécution du fil où le gestionnaire a été
/// créé, et les trois services qui en créent un sont construits depuis `@MainActor`
/// (`LiveRunViewModel`, `AppState`, `WeatherBackgroundRefresh`). Le rappel arrive donc déjà sur le
/// fil principal, et une `Task` y serait pire que inutile : **deux `Task` non structurées n'ont
/// aucun ordre garanti entre elles**. Or `LocationService.didUpdateLocations` accumule — il
/// compare chaque point au précédent (`lastLocation`), additionne une distance et alimente un
/// lissage d'altitude. Deux lots de fixes traités à l'envers ne donnent pas un retard : ils
/// donnent une distance fausse et un dénivelé faux, sur la mesure qui est tout le produit.
///
/// `MainActor.assumeIsolated` exécute le travail TOUT DE SUITE, dans le même ordre et la même
/// image qu'aujourd'hui. L'isolation devient vérifiée par le compilateur sans qu'une seule ligne
/// ne change de moment d'exécution.
///
/// # ET LE REPLI, QUI N'EST PAS DE LA SUPERSTITION
///
/// `assumeIsolated` seul FAIT TOMBER le processus si l'hypothèse est fausse. Ce code tourne
/// pendant une sortie de quatre-vingt-dix minutes, écran éteint, en arrière-plan : si une version
/// future de CoreLocation livrait ses rappels ailleurs, un plantage au trentième kilomètre serait
/// un prix absurde pour une vérification de type. On regarde donc d'abord où l'on est, et on ne
/// promet au compilateur que ce qu'on vient de constater.
@inline(__always)
func surLActeurPrincipal(_ travail: @escaping @MainActor () -> Void) {
    if Thread.isMainThread {
        MainActor.assumeIsolated(travail)
    } else {
        Task { @MainActor in travail() }
    }
}
