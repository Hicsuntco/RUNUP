# Politique de confidentialité — RUNUP

**Dernière mise à jour : 15 juillet 2026**

Cette politique explique quelles données l'application RUNUP collecte, comment elles sont utilisées, et avec qui elles sont partagées.

## Qui sommes-nous

RUNUP est éditée par **Charlotte Grudé**.
Contact : **charlottegrudep@gmail.com**

## Données collectées

### Données de profil
Prénom, date de naissance, objectif de course (course à préparer, progression, perte de poids, reprise, forme), niveau d'expérience, jours de course choisis. Ces données sont saisies par toi lors de l'inscription (onboarding) et modifiables à tout moment dans Profil → Réglages.

### Données de santé (Apple Santé / HealthKit)
Si tu actives la connexion Apple Santé, RUNUP lit : fréquence cardiaque, nombre de pas, et le type/durée de tes séances de sport (course, renforcement musculaire, mobilité, yoga, pilates) — ces dernières alimentent tes objectifs quotidiens "Renfo & mobilité" et "Pas". RUNUP écrit dans Apple Santé les séances de course que tu termines dans l'app (distance, durée, calories).

**Ces données de santé ne sont jamais transmises à un tiers, ni stockées sur un serveur distant.** Elles restent sur ton appareil et dans ta base Apple Santé, conformément aux règles d'Apple sur les données de santé.

### Localisation (GPS)
Pendant une course, RUNUP utilise ta position pour mesurer la distance parcourue, l'allure et tracer ton itinéraire sur la carte. La localisation n'est utilisée que pendant une séance de course active et n'est pas partagée avec des tiers.

### Historique de course et données de progression
Distance, durée, allure, fréquence cardiaque moyenne et splits de chaque course sont enregistrés localement sur ton appareil pour alimenter tes statistiques, ton historique et l'adaptation de ton programme.

### Messages envoyés au coach
Les messages que tu écris au coach, ainsi qu'un résumé de ton profil et de ta forme du jour (nécessaires pour que le coach te réponde de façon pertinente), sont envoyés à notre serveur, qui les relaie à **l'API d'Anthropic (Claude)** pour générer les réponses du coach. Nous ne stockons pas ces messages sur notre serveur — ils ne font que transiter le temps de la réponse.

Voir la politique de confidentialité d'Anthropic : https://www.anthropic.com/legal/privacy

### Compte Le Club (optionnel)
Le Club (classement, fil d'activité entre membres) est la seule fonctionnalité de RUNUP qui nécessite un vrai compte — tout le reste de l'app fonctionne sans jamais te connecter. Si tu choisis de te connecter (Apple, ou email/mot de passe), nous créons un compte sur notre serveur contenant :

- **Identifiant de connexion** : selon la méthode choisie, un identifiant Apple (jamais ton mot de passe Apple, que nous ne voyons jamais), ou ton email et un mot de passe (stocké sous forme hachée, jamais en clair) si tu choisis email/mot de passe.
- **Prénom** — le tien, ou celui transmis par Apple lors de la première connexion.
- **XP total et activité du Club** : les séances/objectifs que tu termines sont envoyées à notre serveur pour alimenter le classement de ton club et le fil d'activité partagé avec ses membres (ex. "a couru 8.2 km · Sortie longue"). Les autres membres de ton club voient ton prénom, ton XP et ces activités.
- **Appartenance à un club** : le club que tu as créé ou rejoint (nom, code d'invitation).
- **Kudos** : les 👏 que tu donnes ou reçois sur le fil d'activité.

Ces données Club **sont stockées sur notre serveur** (contrairement au reste de tes données, voir ci-dessous) puisque c'est ce qui permet à un classement et un fil d'activité d'être réellement partagés entre plusieurs personnes. Elles ne sont jamais vendues ni partagées avec un tiers en dehors des sous-traitants nécessaires à la connexion (Apple — voir sa propre politique de confidentialité) et de l'hébergement (Vercel).

### Aucune collecte publicitaire
RUNUP ne contient aucun SDK publicitaire, aucun traceur tiers, et ne vend aucune donnée.

## Où sont stockées tes données

Ton profil, ton historique de courses et tes messages au coach restent **localement sur ton appareil** — la suppression de l'application supprime l'ensemble de ces données. Rien de tout ça n'est stocké sur un serveur, y compris si tu te connectes pour le Club.

Si tu te connectes pour utiliser le Club, ton compte (identifiant de connexion, prénom, XP, appartenance à un club, activités postées, kudos — voir "Compte Le Club" ci-dessus) est stocké sur notre serveur (hébergé chez Vercel, base de données Neon), tant que tu ne le supprimes pas.

La seule autre donnée qui quitte ton appareil est celle envoyée à notre serveur pour faire fonctionner le coach conversationnel (voir ci-dessus), et les données Apple Santé que tu choisis explicitement de synchroniser.

## Tes droits

- **Supprimer tes données locales** : désinstalle l'application, ou utilise "Refaire l'onboarding" pour repartir de zéro.
- **Supprimer ton compte Le Club** : Profil → Compte → "Supprimer mon compte" — supprime immédiatement et définitivement ton compte, ton XP, ton appartenance au club et tes activités postées de notre serveur.
- **Se déconnecter sans supprimer le compte** : Profil → Compte → "Se déconnecter".
- **Révoquer l'accès à Apple Santé ou à la localisation** : Réglages iOS → Confidentialité et sécurité → Santé / Service de localisation → RUNUP.

## Âge minimum

RUNUP n'est pas destinée aux enfants de moins de 13 ans.

## Modifications de cette politique

Cette politique peut être mise à jour ; la date de dernière mise à jour est indiquée en haut de page.

## Contact

Pour toute question relative à cette politique ou à tes données : **charlottegrudep@gmail.com**
