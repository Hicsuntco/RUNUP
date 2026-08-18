# RUNUP

RUNUP est une app iOS native (SwiftUI, iOS 17+) de coaching de course à pied avec un coach IA
conversationnel réel. Reconstruite nativement à partir d'un handoff design complet
(`design_handoff_runup_app/`) — voir ce dossier pour le README de handoff détaillé (tokens de
design, description écran par écran, prototype de référence).

## Fonctionnalités

- Onboarding multi-étapes adaptatif selon l'objectif (course, progression, perte de poids, reprise, forme)
- Accueil avec anneaux d'activité, séance du jour, plan de 9 semaines
- Suivi de course en direct avec MapKit + CoreLocation (vraie géolocalisation)
- Coach IA conversationnel branché sur l'API Anthropic (Claude), via un proxy serveur — aucune clé
  à fournir côté utilisatrice
- Mécanique de plan adaptatif : la forme moyenne de la semaine passée fait évoluer la suivante
- Intégration Apple Santé (HealthKit) pour la forme du jour
- Stats, historique, club social réel (comptes Apple/email, classement et fil d'activité
  partagés entre membres, via un backend Vercel + Postgres)
- Flux de fin de programme : récupération → nouvel objectif ou mode course libre

## Démarrage rapide

Voir [IOS_SETUP.md](IOS_SETUP.md) pour générer le projet Xcode et lancer l'app.

## Architecture

```
RunUp/
├── AppState.swift              — store central + routeur (@Observable)
├── AppScreen.swift              — enum des écrans navigables
├── RunUpApp.swift               — point d'entrée
├── Models/                      — SwiftData (@Model) + enums/structs
├── ViewModels/                  — état par écran/flow
├── Services/                    — HealthKit, CoreLocation, appel au proxy coach, persistance,
│                                   moteur du plan adaptatif
├── DesignSystem/                — couleurs, typographie (Bebas Neue/DM Sans/DM Mono), espacements
├── Views/                       — un dossier par section, un fichier par écran
│   ├── Onboarding/
│   ├── Home/
│   ├── Live/
│   ├── Coach/
│   ├── Stats/
│   ├── Club/
│   ├── Race/
│   ├── Profile/
│   ├── ProgramEnd/
│   └── Components/               — primitives partagées (anneaux, cartes, boutons, tab bar…)
└── Resources/
    ├── Fonts/                   — Bebas Neue, DM Sans, DM Mono (.ttf, licence OFL)
    └── Assets.xcassets
```

## Coach backend

Le coach n'appelle jamais l'API Anthropic directement depuis l'app — aucune utilisatrice n'a de
clé à fournir. L'app appelle un proxy (`api/coach.js`, fonction serverless Vercel) qui détient la
vraie clé Anthropic côté serveur. Voir [IOS_SETUP.md](IOS_SETUP.md) pour le déploiement.

## Backend Club (comptes, clubs, activités)

Le Club est un vrai backend multi-utilisateurs — mêmes fonctions serverless Vercel que le coach,
plus une base Postgres (Neon). `api/auth/*.js` (Apple/email), `api/clubs/*.js`,
`api/activities/*.js`, `api/me.js`, `api/account/delete.js` ; schéma dans `db/schema.sql`. Voir
[IOS_SETUP.md](IOS_SETUP.md) § "Backend (comptes, clubs, activités)" pour le déploiement complet
(base de données, variables d'environnement, Sign in with Apple).
