# L'import Strava et la politique d'API du 1er juin 2026

> Relevé le 16 octobre 2026, depuis <https://www.strava.com/legal/api_policy> (date d'effet
> affichée : 1er juin 2026). Ce fichier n'est pas un avis juridique : c'est la lecture des
> sections qui touchent ce que RUNUP fait aujourd'hui, pour que la décision soit prise en
> connaissance de cause et pas découverte un matin par un e-mail de Strava.

## Ce que RUNUP fait aujourd'hui

`StravaService.importActivities` récupère les activités d'une athlète et les écrit dans la base
de l'app comme des `RunRecord` ordinaires, avec `stravaActivityId` pour ne pas les importer deux
fois. Elles y restent **pour toujours** : elles comptent dans l'historique, dans les totaux, dans
la série, dans les records et dans la charge d'entraînement.

## Les trois points de friction, par section

**§6.2 — « You may not retain Strava Data in your cache for longer than seven (7) days. »**
C'est le plus direct. Un import permanent n'est pas un cache de sept jours. Tout dépend de ce que
Strava appelle « cache » pour une donnée que l'athlète a elle-même demandé à importer dans son
propre carnet d'entraînement — et c'est précisément la question à laquelle leur support n'a pas
répondu publiquement.

**§5.5 — « You may not store Strava Data, or any data derived from Strava Data, in any Persistent
Index. »** Une base SwiftData interrogée par date, par discipline et par distance est un index
persistant au sens courant du terme.

**§6.3 — « Deletions must be reflected in your Developer Application expeditiously but in all
cases within forty-eight (48) hours. »** Rien dans l'app ne remarque qu'une activité a été
supprimée côté Strava : l'import est à sens unique et ne repasse jamais sur ce qu'il a déjà pris.
C'est le point le plus facile à corriger des trois, et le seul qui soit purement technique.

## Et le coach ?

**§5.3** interdit l'usage des données d'API « in connection with the development, training,
evaluation, or operation of any AI Application », et la section nomme explicitement
« ingestion into a context window or working memory ». La seule exception est le MCP de Strava
lui-même (§3.5).

Bonne nouvelle : `CoachService.systemPrompt` n'envoie **aucune course** au modèle. Il envoie le
profil — niveau, objectif, date de course, semaine du programme, forme du jour (HealthKit), séance
du jour, série. Aucun `RunRecord` ne part, donc aucune activité Strava ne part.

Restent deux chiffres *dérivés* qui peuvent compter une course importée : la **série** et le
**numéro de semaine**. §5.5 mentionne « any data derived from Strava Data ». Un entier qui vaut
« 12 » est une lecture très large de « derived », mais c'est la lecture prudente, et c'est la
zone grise que le fil de la communauté développeurs signale sans réponse.

## Les options, de la moins à la plus coûteuse

1. **Demander à Strava.** Un ticket au support développeurs sur le cas précis : import à la
   demande de l'athlète, dans son propre carnet, sans partage ni revente. C'est gratuit, ça prend
   un e-mail, et c'est la seule façon d'avoir une réponse qui engage quelqu'un d'autre que nous.
2. **Fermer le trou de §6.3.** Un passage de réconciliation à chaque import : les activités
   importées qui ne sont plus chez Strava sont retirées. Petit, technique, utile de toute façon.
3. **Ne plus rien conserver.** L'import devient une lecture ponctuelle, affichée et jetée. Ça
   vide l'intérêt de la fonctionnalité : l'import existe pour que l'historique soit complet.
4. **Retirer l'import Strava** et laisser Apple Santé, qui n'a aucune de ces restrictions
   (voir la comparaison des politiques : Strava interdit, Garmin autorise, Apple Santé ne dit
   rien parce qu'il n'y a pas d'API tierce — la donnée vient de l'appareil).

Le programme développeur 2026 ajoute par ailleurs un abonnement payant et une revue au-delà de
dix athlètes : à partir du 1er juin 2026, l'import ne peut de toute façon pas servir plus de dix
personnes sans démarche.

## Ce qui n'est PAS décidé ici

Aucune de ces options n'a été appliquée. Retirer ou brider l'import Strava est une décision
produit, visible par les testeuses, et elle n'appartient pas à une passe de correction technique.
