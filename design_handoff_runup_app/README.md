# Handoff: RUNUP 4.0 — Coach IA Running App

## Overview
RUNUP is a running-coach mobile app. This handoff covers a full redesign ("Midnight Rose" visual direction) plus a from-scratch interactive prototype: onboarding, home/program, live run tracking, an AI running coach, stats, social/club, profile & settings, a premium paywall, and end-of-program flows (recovery → new goal or free-run mode).

The long-term goal stated by the client is to ship this as a **native iOS app on the App Store**. This handoff is written to support that: recommendations below assume SwiftUI as the primary target, with React Native/Expo as a secondary option if the team prefers to stay in JS/TS and also ship Android later.

## About the Design Files
The files in `prototype/` are **design references built in HTML/React (in-browser Babel, no build step)** — they exist to communicate exact layout, motion, copy, and interaction logic. **They are not production code.** Do not embed a WebView or ship this HTML directly. The task is to **recreate these screens natively** (SwiftUI recommended) using the design tokens and behavior specs below.

The one exception: the **system prompt sent to the AI coach** (see `app.jsx`, function `sendCoach`) is worth porting almost verbatim — it encodes real product logic (what the coach knows, its tone rules, safety rule about never claiming to be an AI).

## Fidelity
**High-fidelity.** Colors, type scale, spacing, and copy in the HTML are final — implement pixel-close, not just "inspired by." Where a value is described as approximate below (e.g. procedurally generated pace numbers in the run simulation), use your judgement, but all fixed colors/type/spacing should be exact.

## Recommended Stack for App Store shipping
- **SwiftUI** (iOS 16+) is the natural choice for a solo/small-team native App Store app — it maps well to this design's card-based layout, and Apple's own HealthKit/Apple Health integration (which this design references) is first-party.
- If cross-platform (iOS + Android) matters more than platform-native polish, **React Native + Expo** is the pragmatic alternative — the existing React component structure in `prototype/*.jsx` translates conceptually (state, context, component boundaries) even though the JSX itself must be rewritten for RN primitives (`View`/`Text` instead of `div`/`span`, no CSS strings).
- Either way: rebuild from scratch using the codebase's/framework's own patterns — don't try to interpret raw CSS pixel values as gospel; treat the **Design Tokens** section below as the source of truth.

## Global Chrome
- **Device**: designed for a 390×844 canvas (iPhone-sized), status bar at top (`StatusBar` component in `ui.jsx` — cosmetic only, use the OS status bar in production).
- **Tab bar**: floating pill, frosted glass, positioned 18px from the bottom, 64px tall, `rgba(18,18,26,.72)` background with `blur(28px) saturate(1.4)`, `1px solid rgba(255,255,255,.09)` border, `24px` corner radius. Contains 5 items: Programme (list icon), Coach (chat icon), **Run** (center, raised, circular rose-gradient button, 50×50px, play icon), Stats (bars icon), Club (people icon). Active tab: icon + label in rose (`#FF4D7D`), small dot indicator above. Inactive: `rgba(255,255,255,.4)`.
- **Screen transitions**: simple fade/slide (`.fade`/`.rise` CSS classes, ~250-300ms ease). Nothing exotic — standard push/fade is fine natively.

## Design Tokens

### Colors
| Token | Hex/Value | Usage |
|---|---|---|
| `--bg` | `#0E0E14` | primary background |
| `--bg2` | `#15151E` | secondary background |
| Rose (primary) | `#FF0F5B` | primary actions, active states, key accents |
| Rose 2 | `#FF4D7D` | secondary rose (highlights, active tab labels) |
| Violet | `#7C5CFF` | secondary accent (XP/level, premium, gradient pairs) |
| Lime | `#C8FF3D` | success/positive (rings "active" segment, premium-active state) |
| Cyan | `#38E0D0` | tertiary accent (rings "run" segment, VO2/stats) |
| Text secondary | `rgba(255,255,255,.5)` | `--t2` |
| Text tertiary | `rgba(255,255,255,.32)` | `--t3` |
| Text quaternary | `rgba(255,255,255,.2)` | `--t4` |
| Card fill | `rgba(255,255,255,.045)` | `--card` |
| Card fill 2 | `rgba(255,255,255,.03)` | `--card2` |
| Hairline border | `rgba(255,255,255,.08)` | `--line` |
| Warning/amber | `#FFB03D` | GPS-loss + coach-offline error states |

Brand gradient (used on the logo mark, coach avatar, premium paywall): `linear-gradient(135deg, #FF0F5B, #7C5CFF)`.

### Typography
- **Display/numerals**: "Bebas Neue" — used for all big numbers, headlines, buttons (class `.b`). Tight letter-spacing (0.5px).
- **Body**: "DM Sans" (300–700 weights + italic) — all body copy, labels.
- **Monospace**: "DM Mono" — timestamps, XP counters, precise numeric readouts (class `.m`).
- **Eyebrow label** style (`.eye`): 9px, letter-spacing 3px, uppercase, weight 700 — used above every section/card title.
- Never go below 24px for anything a user reads as a "big number" on the run screen; body copy sits around 12–14px; eyebrows 8-10px.

### Spacing / Shape
- Card corner radius: 16–20px standard, 14px for compact rows, 44px for the outer phone screen mask (n/a natively), 99px for pills/chips.
- Card border: always `.5px solid var(--line)` hairline, fill `--card` (barely-there white overlay on dark bg) — never solid opaque cards.
- Standard horizontal page padding: 18px.
- Buttons: primary CTA is full-width, 14–15px vertical padding, 14px radius, rose fill, `0 6px 22px rgba(255,15,91,.35)` shadow, Bebas Neue label, letter-spaced.

## Screens / Views

### 1. Pre-onboarding welcome
**Purpose**: pitch the app before asking questions (no progress bar — not counted as a step).
- Logo mark (see Assets) at 88px, `26px` radius, centered-left aligned block.
- Headline "COURS COMME SI TU AVAIS UN COACH" (Bebas Neue, 42px).
- Subhead: one sentence positioning statement.
- 3 value-prop rows, each: 38×38px icon tile (card bg, hairline border, small stroke SVG icon in rose), title (14px/600) + description (12px, secondary text).
- Small social-proof line: 5 lime stars + "Rejoins des milliers de coureurs qui progressent chaque semaine."
- Primary CTA "COMMENCER" pinned to bottom.
- Skip-style "Plus tard" link, top-right, tertiary text color (13px) — dismisses welcome without completing onboarding (same treatment used later on the paywall).

### 2. Onboarding (multi-step, progress bar top)
Total steps = 8 for a "race" goal path, adapts for non-race goals. Progress bar: thin (3px) segmented bar, filled segments in rose, unfilled `rgba(255,255,255,.1)`.
Steps, in order:
1. **Prénom** (first name) — single text input.
2. **Date de naissance** (birthdate) — native date input; used to compute age (drives HR-zone/VO2 copy).
3. **Objectif** (goal) — 5 selectable cards (icon + title + description + radio check): Préparer une course 🏁, Progresser 📈, (Re)commencer 🌱, Perdre du poids 🔥, Rester en forme ⚡.
4. **Deep-dive personnalisé** — content branches by goal:
   - *Race*: distance chips (5k/10k/semi/marathon/**Autre distance** with free-text field) → target-time chips (goal-specific presets + "Juste finir" + "Mon propre temps" free field) → race date (native date picker, computes days-remaining).
   - *Weight loss*: current weight / target weight (kg) / height (cm) — 3 numeric fields.
   - *Progress*: priority chips (vitesse/endurance/régularité/dénivelé) + optional "best recent performance" free text.
   - *Restart*: "last ran" recency chips + injury/pain area chips.
   - *Health*: weekly time-budget chips + preferred time-of-day chips.
5. **Jours de course** (running days) — 7-cell day-of-week picker (min 2 required, inline validation message).
6. **Niveau** (experience level) — 3 selectable cards (Débutante/Intermédiaire/Confirmée).
7. **Connexions santé** — 3 rows (Apple Santé / Strava / Garmin Connect), each tappable to "connect": shows a spinner (~1.1s) then a lime "CONNECTÉ ✓" state. Optional — CTA label swaps between "PLUS TARD" and "CONTINUER" based on whether anything is connected.
8. **Building/loading screen** — a ring (rose, animates 0→100% over ~3s) plus a 4-item checklist that reveals items with checkmarks in sequence ("Ton profil analysé", "Ta forme de départ estimée", "Séances calées sur tes N jours", goal-specific closing line). Auto-advances to home after ~3.8s.

### 3. Home ("Programme")
- Header: eyebrow = weekday + week number (or "Mode course libre" once in free-run mode), title "Salut {name}". Right side: notification bell (with red unread dot) + circular avatar button (first-initial) → opens Profile.
- 7-cell week strip: done (solid rose, ✓), today (rose-tinted outline), rest (dot, dim), upcoming (empty outline).
- **Forme du jour** card: gradient dark-rose→bg background, small readiness ring (0–100, lime) + one line of coach copy explaining today's adjustment.
- **Today's session card** (hero): tappable → opens session-detail sheet. Shows title, subtitle, 3 stat columns (duration/pace/zone), adjustment chip if the plan bumped difficulty, and a full-width "▶ DÉMARRER" primary button that starts a run directly (stops event propagation so it doesn't also open the detail sheet).
- **Rings card** (promoted to full width per client request): 72px 3-ring concentric SVG (rose=move/kcal, lime=active/min, cyan=run/km) + eyebrow "Tes anneaux · N/3 bouclés" + 3 mini stat columns (current/goal for each ring). Tapping opens the Rings detail screen.
- **Plan/objective card** (also full width): eyebrow "Objectif · {goal} · J-{days}", title "Semaine {n} · Bloc VMA", a 3-segment phase progress bar (Base/Spécifique/Affûtage), footer text "9 semaines · voir le plan complet". Tapping opens the full Plan screen. In free-run mode this card is replaced by a muted one-line note instead (no fixed plan to show).
- A floating "RUN EN COURS · {time}" pill appears above the tab bar any time a run is active but the user has navigated away from the Live screen — tapping it returns to Live.

### 4. Plan complet (full 9-week plan)
- Back chevron `‹` + eyebrow "Ton programme · {goal}" + title "Le plan complet".
- 3-segment phase bar (Base 3/3, Spécifique 1/4, Affûtage 0/2) with week counts under each.
- Vertical list of 9 week rows. The **current week** expands inline to show its 7 daily sessions (day letter, colored dot, session name, duration/zone, "aujourd'hui" chip on today, checkmark on completed days). Other weeks collapse to a single row (week number badge, phase name, weekly distance, status glyph: ✓ done / 🏁 race week / ▽ taper / › upcoming).

### 5. Anneaux (Rings detail)
- Back chevron + eyebrow "Aujourd'hui · {date}" + title "Ta journée".
- Large (210px) 3-ring SVG centered, with "{n}/3 bouclés" in the middle.
- 3 rows below, one per ring (Bouger/Actif/Courir), each: colored dot, name, current/goal readout, thin progress bar.
- If rings incomplete: coach nudge card (gradient bg, coach avatar mark, copy telling exactly how much is left on the "Courir" ring). If all 3 closed: full celebratory card ("JOURNÉE BOUCLÉE" + XP earned) — no confetti/fireworks emoji (explicitly requested against by client — keep this celebratory state understated/typographic, not gamey).

### 6. Live Run
- Full-bleed "map" area (top ~56% of screen): grid-pattern background + a stylized SVG route path (rose line, thick low-opacity route + thin bright traveled segment), a pulsing dot marking current position.
- Top overlay row: back chevron (frosted circle, top-left) + "EN DIRECT"/"EN PAUSE" status pill (pulsing dot) + "Interv. N/6" pill (top-right).
- **GPS-loss error state**: ~40s into a run, an amber banner appears below the top row for ~5s: "Signal GPS instable — position estimée" (warning triangle icon, `#FFB03D` text on `rgba(255,176,61,.16)` bg) — demonstrates graceful degradation, then auto-clears.
- **Coach voice bubble**: appears at scripted timestamps (6s/120s/360s/720s/1080s) with contextual cues ("Échauffement…", "Premier 800: vise 4:10…", etc.) — frosted card, coach avatar, auto-dismiss-on-replace (only one shows at a time).
- Bottom metrics panel (44% height, rounded top corners): huge (64px) elapsed-time readout + distance, then 3 stat columns (pace/HR-with-zone/kcal), then transport controls: STOP (translucent circle, left), pause/resume (large white circle, center), a locked padlock icon (right, decorative — represents "lock screen to prevent accidental taps," a real running-app pattern worth implementing for real).

### 7. Recap + Debrief ("Ressenti")
- Hero header (190px): route SVG on a dark gradient, back chevron top-left (frosted circle — same treatment as Live), "✓ Séance terminée" + session title bottom-left.
- 2 rows × 3 stat cards: (distance, time, avg pace) then (avg HR, kcal, elevation gain).
- Splits-per-km list: row per km, index, a filled bar (visually communicates relative pace, longer = faster in this design though feel free to reconsider that direction), split time (last split highlighted rose).
- Primary CTA "DONNER MON RESSENTI" opens a bottom sheet:
  - Coach's one-line take on the session.
  - 4-option RPE (rate of perceived exertion) selector: 😮‍💨 Trop dur / 😤 Dur / 🙂 Juste bien / 😎 Facile (chip-style single-select).
  - "Impact sur ton programme" card: 2 lines showing concretely how the next sessions change based on this input (e.g. next interval session gets harder, next day becomes active recovery).
  - "VALIDER & METTRE À JOUR" — this is the **core adaptive-plan mechanic**: submitting updates the user's rings, streak, XP, marks today done in the week strip, and rewrites tomorrow's/next key session in the plan. Show a toast ("Programme mis à jour · +120 XP") and return to the Rings screen.

### 8. Coach (AI chat)
- Header: coach avatar mark + "Ton coach" + online/offline status line (lime dot "en ligne · connaît ton historique" normally; amber dot "hors ligne — nouvelle tentative en cours" in the error state).
- Message list: coach bubbles left-aligned (subtle card bg, small corner-radius asymmetry mimicking a tail), user bubbles right-aligned (solid rose). A typing indicator (3 bouncing dots) shows while awaiting a response.
- **Error bubble** (distinct from normal coach messages): full-width amber-tinted card with a warning icon, the error copy, and an inline "Réessayer" button — shown when the AI call fails or when coach-offline mode is simulated.
- 4 suggestion chips above the input (quick prompts: "Adapte ma semaine", "Je suis fatiguée", "Conseils nutrition", "Analyse ma dernière sortie") — tapping sends that text directly.
- Text input: pill-shaped, frosted, with a circular rose send button.
- **This is a real generative AI integration, not scripted responses.** See "AI Coach System Prompt" below — port this logic, not just the UI.

### 9. Stats
- Header with a "Historique ›" pill button (top-right) linking to the full run history list.
- VO2max card: big number + a trend chip (▲ +2.1) + percentile copy + a small area-chart sparkline (SVG, gradient fill under the line).
- Race-prediction card (gradient dark-rose bg): 3 columns (5K/10K/Semi predicted times), the column matching the user's actual goal distance is highlighted; footer line compares to their actual goal using **live store data** (not hardcoded).
- Training-load card: 11-week bar chart (recent 2 bars highlighted rose), a "Zone optimale" status chip, footnote showing load ratio.

### 10. Historique (run history)
- Back chevron + eyebrow "{n} sorties" + title "Historique".
- Flat list of cards, one per run: date, avg-HR readout top-right, title, 3 stat columns (distance/time/avg pace). New runs completed in-session are prepended automatically ahead of the seeded historical runs.

### 11. Club (social)
- Header "Le Club" / "Runners du 11e" + member-count chip.
- Level/XP card (violet-rose gradient): level badge, level name, XP progress bar.
- Monthly challenge card: title, progress bar (rose), km-completed vs. days-remaining.
- Segmented control: **Classement** (leaderboard) / **Fil d'activité** (activity feed).
  - Leaderboard: ranked rows (medal emoji for top 3), the current user's row highlighted (rose tint).
  - Feed: friend activity cards (avatar-initial, action text, timestamp, tappable kudos/👏 counter that increments on tap).
- Badges row: 4 badge tiles (streak, VMA, early-bird, elevation), earned ones full-opacity+bg, locked ones dimmed.

### 12. Objectif (race goal detail)
- Back chevron + eyebrow "Ton objectif" + **dynamic** title showing the actual distance/description the user chose in onboarding (not a hardcoded race name).
- Date/time line — computed from the real `raceDate` chosen in onboarding, falls back to a placeholder date if the user didn't set one (non-race goals).
- 3 stat tiles (days remaining / objective / target pace), days-remaining tile highlighted.
- Preparation progress bar + phase labels (Base ✓ / Spécifique ● / Affûtage).
- Pacing-strategy list: per-segment target pace for race day (e.g. controlled start → target rhythm → surge → final sprint), last row highlighted.

### 13. Profil & Réglages (Profile & Settings)
- Back chevron + title. Avatar + name + current goal summary.
- **Premium banner** (see Paywall below): shows "Passer à Premium" (violet/rose gradient tint) when not subscribed, or "Runner Premium" (lime tint, star icon) once active. Tapping the non-premium state opens the paywall.
- Data-sources card: 3 rows (Apple Santé/Strava/Garmin) each with a toggle switch.
- Preferences card: distance unit segmented control (km/mi), coach-notifications toggle.
- Program card: "Voir mon objectif" → Objectif screen, "Modifier jours & objectif" → edit sheet, "Refaire l'onboarding" → replays onboarding from scratch.
- Two **demo-only** affordances (dashed border, tertiary text) — do **not** ship these to production, they exist purely so a designer/PM can trigger end states without waiting: "Terminer le programme (démo)" and "Simuler coach hors ligne (démo)".

### 14. Program-end flow (Recovery → Choice → New goal / Free-run)
This is the "what happens after 9 weeks" arc — a real product mechanic worth implementing fully:
- **Recovery**: shown immediately after the program ends. Copy explains why recovery matters, shows a day-by-day tracker (pill grid, filled-lime = done) for a goal-dependent recovery length (race=6 days, weight-loss=3, progress=4, restart=5, health=3), a light-activity suggestion card, and a "JOUR SUIVANT →" button that advances one day at a time (label becomes "JE SUIS PRÊTE" on the last day).
- **Choice**: after recovery completes — a program recap (total km / weeks / streak) plus two full-width option cards: "Se fixer un nouvel objectif" (🎯) or "Mode course libre" (🏃, no fixed plan).
- **New-goal mini-wizard**: a condensed 3-step flow reusing the goal cards, then (if race) distance+target-time, then running days, then a short "building" animation — writes a fresh program and resets to week 1.
- **Free-run mode**: no fixed plan; the home screen swaps its plan card for a note, and the daily session rotates through a small set of maintenance/light-progression templates (easy footing, light intervals, "discover a new route").

### 15. Paywall (Premium)
- Full-screen overlay (violet-tinted radial background, distinct from the rose-tinted onboarding background — signals "different, special" moment).
- Top-right "Plus tard" skip (always available — respect the free tier, don't force a purchase to escape).
- Logo mark (64px) + "PASSE EN PREMIUM" headline + one-line positioning.
- 4 feature rows, each with a small violet checkmark badge: unlimited AI coach, continuously-adapting plan, advanced stats (VO2max/predictions/12-week load), unlimited device integrations.
- 2 plan cards (Annuel default-selected, "-30%" badge, price + effective monthly; Mensuel, no-commitment framing) — selecting one visually re-highlights it (violet border/tint).
- A free-trial toggle checkbox ("Commencer par 7 jours d'essai gratuit") that changes the primary CTA's label and the fine-print below it.
- Primary CTA: violet→rose gradient, shows a loading-dots state (~1.4s) then confirms via toast and dismisses.

## Interactions & Behavior Summary
- **Adaptive plan mechanic** (the core loop, don't lose this in translation): Session → Live Run → Recap → Ressenti/RPE submission → plan recalculates next session's difficulty, rings/streak/XP update, week strip marks today done. This should feel like real cause-and-effect, not cosmetic.
- **Session detail** is a bottom sheet (not a full screen) reachable by tapping the home hero card; offers "Déplacer à demain" (reschedule) or "Démarrer" (start now).
- **Program settings edit** (days + goal text) is also a bottom sheet, reachable from Profile.
- **Notifications** are a bottom sheet triggered by the bell icon; opening it marks all as read.
- All bottom sheets: dark backdrop (`rgba(0,0,0,.5)`, blur), sheet slides up from bottom (`cubic-bezier(.2,.8,.2,1)`, ~320ms), drag-handle affordance at top, tap-backdrop-to-dismiss.
- Toasts: small pill, white bg/dark text, bottom-center just above the tab bar, ~2.2s auto-dismiss.

## State Management
Key state a native implementation needs to track (see `app.jsx` for the reference shape):
- **User/profile**: name, birthdate/age, goal type + goal-specific fields (target race distance/time/date, or weight-loss numbers, or progress focus, or restart/injury info, or weekly-time/preferred-time), experience level, connected data sources.
- **Program**: current week number, program phase (`active` / `recovery` / `choice` / `freerun`), recovery-days-remaining, running days, today's session (title/duration/pace/zone/adjustment-flag), 7-day week-strip status.
- **Rings**: move/active/run — each `{value, goal}` — plus a derived "rings completed" count.
- **Gamification**: streak count, XP.
- **Live run session** (ephemeral): elapsed time, distance, kcal, current pace, HR, interval index, paused flag, whether a GPS-issue is currently active, the current coach-cue text.
- **History**: array of completed runs (title, distance, time, avg pace, avg HR) — newest first, user-generated runs prepended ahead of seed data.
- **Coach chat**: message array (role: `user` | `coach` | `error`), a "typing" boolean, a "coach offline" simulation flag.
- **Notifications**: array with read/unread flags.
- **Premium**: boolean subscribed flag.

## AI Coach System Prompt
This is the actual logic worth porting (from `app.jsx`, `sendCoach`): the coach is presented as a **real personal coach, never as an AI/model** — this is a hard rule, not just tone. The system prompt is dynamically assembled from live user state every message: name, goal + race date + days-remaining, current program week, a block of goal-specific context (weight numbers, focus area + best recent performance, injury flags, weekly-time/preferred-time), age, today's readiness score + today's session details, an approximate VO2max, and the current streak. Style rules baked into the prompt: French, informal "tu" address, warm, motivating, concrete, 2-4 sentences max, at most one occasional emoji. On a network/API failure, do not silently retry forever — surface a visible error state (see Coach screen error bubble) with a manual retry action.

## Assets
- **Logo mark / "AppMark"**: a custom SVG glyph (not a photo/emoji) — a circular progress-ring arc (rose stroke, ~270° sweep, round linecap) with a small filled dot at the arc's leading edge, centered on a rounded-square tile filled with the brand gradient. This deliberately echoes the Rings feature (the app's own visual signature) rather than a generic running-shoe/figure icon — keep this connection when redrawing at higher fidelity for App Store icon/marketing assets. See `ui.jsx`, function `AppMark`, for the exact SVG path/geometry.
- Fonts: Bebas Neue, DM Sans, DM Mono — all Google Fonts, freely usable; source real font files/licenses for the native build rather than webfont-linking.
- No other custom image assets are used — everything is drawn in CSS/SVG. A native build will need to source real map tiles for the Live Run screen (this design uses a stylized illustrative SVG route, not a real map — decide whether to keep the stylized look or switch to MapKit).

## Screenshots
Full-fidelity screenshots of every screen and state described below are in `screenshots/` (numbered in flow order): welcome pitch, onboarding (goal step shown, same visual system throughout), home, plan, rings, live run (normal + GPS-loss error state), recap + debrief sheet, coach chat, stats, history, club (both tabs), race/objective, paywall, profile, session-detail sheet, notifications sheet, and the recovery/choice program-end screens. Use these as the pixel reference alongside the written specs — they're the fastest way to check color/spacing/type against your implementation.

## Files
- `prototype/index.html` — shell, fonts, global CSS (design tokens live here as CSS custom properties), script loading order.
- `prototype/app.jsx` — root app state, navigation, live-run simulation timer, AI coach integration, all business logic (adaptive plan, program-end flow, paywall wiring).
- `prototype/ui.jsx` — shared primitives: status bar, ring/rings SVG components, tab bar, header, the `AppMark` logo component.
- `prototype/onboarding.jsx` — pre-onboarding welcome + full multi-step onboarding wizard.
- `prototype/screensA.jsx` — Home, Plan, Rings, Live Run, Recap+Debrief.
- `prototype/screensB.jsx` — Coach chat, Stats, Club, Objectif (race goal detail).
- `prototype/screensC.jsx` — Session-detail sheet, Profile & Settings, History, Notifications sheet, Program-settings-edit sheet.
- `prototype/screensD.jsx` — Program-end flow: Recovery, Choice, New-goal wizard, free-run templates.
- `prototype/screensE.jsx` — Premium paywall.

Open `prototype/index.html` in a browser to click through the whole app before starting implementation — it's the fastest way to understand timing/motion/copy that's hard to fully capture in writing above.
