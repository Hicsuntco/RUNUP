# RUNUP

RUNUP est une app iOS native (SwiftUI, iOS 17+) de coaching de course à pied avec un coach IA
conversationnel réel. Reconstruite nativement à partir d'un handoff design complet
(`design_handoff_runup_app/`) — voir ce dossier pour le README de handoff détaillé (tokens de
design, description écran par écran, prototype de référence).

## Fonctionnalités

- Onboarding multi-étapes adaptatif selon l'objectif (course, progression, perte de poids, reprise, forme)
- Accueil avec anneaux d'activité, séance du jour, plan de 9 semaines
- Suivi de course en direct avec MapKit + CoreLocation (vraie géolocalisation)
- Coach IA conversationnel branché sur l'API Anthropic (Claude)
- Mécanique de plan adaptatif : le ressenti post-course fait évoluer le programme
- Intégration Apple Santé (HealthKit) pour la forme du jour
- Stats, historique, club social (mock), paywall premium
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
├── Services/                    — HealthKit, CoreLocation, Anthropic API, Keychain, persistance,
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
│   ├── Paywall/
│   ├── ProgramEnd/
│   └── Components/               — primitives partagées (anneaux, cartes, boutons, tab bar…)
└── Resources/
    ├── Fonts/                   — Bebas Neue, DM Sans, DM Mono (.ttf, licence OFL)
    └── Assets.xcassets
```

## Clé API Anthropic

Le coach IA appelle directement l'API Anthropic (Messages API) depuis l'app avec la clé de
l'utilisateur, saisie et stockée dans le Keychain via Profil → Réglages. Voir
[IOS_SETUP.md](IOS_SETUP.md) pour le détail et les alternatives possibles avant une diffusion
grand public.
