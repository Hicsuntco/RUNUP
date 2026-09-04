// Vercel serverless function — the only place RunUp's real Anthropic API key lives. The app
// calls this endpoint instead of api.anthropic.com directly, so no end user ever needs their own
// key. See IOS_SETUP.md § "Coach backend" for the deploy/config steps.
//
// Two env vars, set in the Vercel project (never committed): ANTHROPIC_API_KEY, RUNUP_APP_SECRET.

const crypto = require('crypto');
const { sql } = require('../lib/db');
const { requireAuth } = require('../lib/auth');
const { withErrorHandling } = require('../lib/http');

// Constant-time string comparison — `!==` leaks how many leading characters matched through
// response timing. Hash both sides first so lengths never have to match for the comparison.
function timingSafeEqualStrings(a, b) {
  const ha = crypto.createHash('sha256').update(String(a)).digest();
  const hb = crypto.createHash('sha256').update(String(b)).digest();
  return crypto.timingSafeEqual(ha, hb);
}

const ALLOWED_MODEL = 'claude-opus-5';

// Sur Opus 5, la réflexion est ACTIVE par défaut — c'est le changement de comportement à
// connaître en venant d'Opus 4.8, où ne rien écrire voulait dire ne pas réfléchir. Elle est
// écrite explicitement ici plutôt que laissée implicite, parce que la différence entre les deux
// modèles est invisible dans le code et coûteuse à redécouvrir.
//
// Et surtout : on ne la coupe PAS, alors que ce serait le réflexe pour économiser des jetons. Un
// Opus 5 sans réflexion écrit parfois son appel d'outil dans le texte visible au lieu de l'émettre
// comme appel — le tour réussit, l'outil ne part jamais, aucune erreur n'est levée, et le
// programme ne bouge pas pendant que le coach affirme le contraire. C'est exactement la panne que
// tout ce travail cherche à éviter. On baisse donc l'effort plutôt que la réflexion : une
// conversation de coaching n'est pas un problème difficile, et c'est le levier prévu pour ça.
const THINKING = { type: 'adaptive' };
const EFFORT = 'low';

// Relevé de 500 à 800 quand les outils sont arrivés — une réponse qui porte À LA FOIS du texte et
// un appel d'outil dépasse plus facilement le plafond, et un dépassement ne se voit pas : la
// réponse arrive coupée au milieu d'une phrase, ce qui ressemble à un bug d'affichage plutôt qu'à
// une limite atteinte. Relevé encore avec Opus 5, parce que les jetons de réflexion se comptent
// dans ce même plafond : à 800, la réflexion mangerait la réponse. 2000 laisse largement de quoi
// écrire quelques phrases là où 500 suffisaient, sans ouvrir en grand un budget que le plafond
// quotidien par utilisatrice traduit directement en euros.
const MAX_TOKENS_CAP = 2000;

// Ce que le coach a le droit de changer au programme.
//
// Défini ICI et nulle part ailleurs, pour la même raison que `ALLOWED_MODEL` et `MAX_TOKENS_CAP` :
// l'app peut demander à ne PAS avoir d'outils (voir `allow_actions` plus bas), elle ne peut pas en
// ajouter. Un client trafiqué ne peut donc pas s'inventer une action que le vrai programme
// n'implémente pas — et surtout, la liste des choses qu'une conversation peut modifier reste
// lisible d'un seul endroit.
//
// Pas de `strict: true`, volontairement : il obligerait à déclarer les champs facultatifs en
// unions nullables, et un schéma que l'API refuserait ne dégraderait pas le coach — il le
// couperait net, pour tout le monde, sur chaque message. La validation réelle est de toute façon
// côté app (`CoachAction.make` et `TrainingEase.sanitized`), qui doit se défier de ces valeurs
// même quand le schéma est respecté.
const COACH_TOOLS = [
  {
    name: 'ease_training_load',
    description:
      "Allège durablement le programme : plafonne la durée des séances et/ou remplace le travail de vitesse par de l'endurance souple, jusqu'à une date. À utiliser quand une gêne, une blessure légère, une fatigue ou une contrainte de temps doit se voir dans le programme des prochains jours — pas pour une seule séance (utilise move_todays_session) ni pour un conseil sans effet sur le plan. Remplace l'allègement en cours s'il y en a un.",
    input_schema: {
      type: 'object',
      properties: {
        max_minutes: {
          type: 'integer',
          description: "Durée maximale d'une séance, en minutes. Omettre s'il n'y a pas de plafond à poser.",
        },
        no_speed_work: {
          type: 'boolean',
          description: "true pour remplacer fractionnés et séances de seuil par de l'endurance souple.",
        },
        until: {
          type: 'string',
          description: "Dernier jour où l'allègement s'applique, inclus, au format AAAA-MM-JJ.",
        },
        reason: {
          type: 'string',
          description: 'Motif court affiché sur les séances concernées, ex. « Tendinite — endurance souple ». Moins de 80 caractères.',
        },
      },
      required: ['no_speed_work', 'until', 'reason'],
    },
  },
  {
    name: 'set_sensitive_area',
    description:
      "Signale une zone du corps sensible, ce qui allège durablement les séances à impact. Utiliser « none » pour lever un signalement devenu inutile.",
    input_schema: {
      type: 'object',
      properties: {
        area: {
          type: 'string',
          enum: ['knee', 'ankle', 'back', 'other', 'none'],
          description: 'Zone concernée, ou « none » pour lever le signalement.',
        },
      },
      required: ['area'],
    },
  },
  {
    name: 'set_running_days',
    description:
      "Change les jours de la semaine où elle court, et éventuellement le jour de la sortie longue. À utiliser quand ses contraintes ont changé pour de bon — pas pour décaler une seule séance.",
    input_schema: {
      type: 'object',
      properties: {
        days: {
          type: 'array',
          items: { type: 'integer' },
          description: 'Jours de course. 0 = lundi, 6 = dimanche. Au moins deux jours.',
        },
        long_run_day: {
          type: 'integer',
          description: 'Jour de la sortie longue, à choisir parmi days. Omettre pour le laisser tel quel.',
        },
      },
      required: ['days'],
    },
  },
  {
    name: 'move_todays_session',
    description:
      "Décale la séance du jour à demain, en l'échangeant avec ce qui y était prévu. Pour un imprévu ponctuel ; sans effet un jour de repos, ou si la séance est déjà faite.",
    input_schema: { type: 'object', properties: {} },
  },
  {
    name: 'resume_normal_training',
    description:
      "Lève tout : l'allègement en cours et le signalement de zone sensible. À utiliser quand elle va mieux et que le programme doit reprendre sa progression normale.",
    input_schema: { type: 'object', properties: {} },
  },
];
// Generous for a human actually chatting with her coach (a heavy day is a few dozen messages),
// tight for anyone trying to use this endpoint as a free LLM proxy billed to the owner's key.
const DAILY_REQUEST_CAP = 250;
const MAX_MESSAGES = 40;
const MAX_TOTAL_CHARS = 30000;
const MAX_SYSTEM_CHARS = 20000;

module.exports = withErrorHandling(async function handler(req, res) {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'method_not_allowed' });
    return;
  }

  // Accepts the current secret OR, when set, one previous secret. This exists purely to make
  // rotation possible without breaking the app already on the App Store: that build has its
  // secret compiled in, so the instant RUNUP_APP_SECRET changes, every existing install starts
  // getting 401s on the coach until its user updates — which can take weeks, or never.
  //
  // Rotation procedure:
  //   1. Set RUNUP_APP_SECRET_PREVIOUS to the OLD value, RUNUP_APP_SECRET to the NEW one, redeploy.
  //      Old and new builds both work from here on.
  //   2. Ship the app update carrying the new secret.
  //   3. Once adoption is high enough, DELETE RUNUP_APP_SECRET_PREVIOUS and redeploy.
  //
  // Step 3 is not optional: the old value was committed in git and must be considered public, so
  // leaving it accepted indefinitely keeps the endpoint open to anyone who reads the history.
  const secret = req.headers['x-runup-secret'];
  const accepted = [process.env.RUNUP_APP_SECRET, process.env.RUNUP_APP_SECRET_PREVIOUS].filter(Boolean);
  // `.some` over a fixed-size list of constant-time comparisons — every candidate is always
  // compared, so this leaks no more than the single comparison it replaces.
  if (!secret || accepted.length === 0 || !accepted.some((candidate) => timingSafeEqualStrings(secret, candidate))) {
    res.status(401).json({ error: 'unauthorized' });
    return;
  }

  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    res.status(500).json({ error: 'server_misconfigured' });
    return;
  }

  const { system, messages, allow_actions: allowActions } = req.body || {};
  if (typeof system !== 'string' || !system || !Array.isArray(messages)) {
    res.status(400).json({ error: 'bad_request' });
    return;
  }
  // Size caps — the app never comes close to these in real use (CoachService sends the last few
  // turns of one conversation); only a script replaying huge payloads through the shared secret
  // would, and each oversized call would bill the owner's key.
  if (system.length > MAX_SYSTEM_CHARS || messages.length > MAX_MESSAGES) {
    res.status(400).json({ error: 'payload_too_large' });
    return;
  }
  let totalChars = 0;
  for (const m of messages) {
    if (!m || typeof m.content !== 'string' || (m.role !== 'user' && m.role !== 'assistant')) {
      res.status(400).json({ error: 'bad_request' });
      return;
    }
    totalChars += m.content.length;
  }
  if (totalChars > MAX_TOTAL_CHARS) {
    res.status(400).json({ error: 'payload_too_large' });
    return;
  }

  // Per-key daily rate limit: the signed-in user's id when there is one, the caller's IP
  // otherwise (the coach deliberately works without an account, so IP is the only handle for
  // anonymous use). Fails open on a DB hiccup — a broken rate limiter should degrade to "coach
  // still works", not "coach is down".
  try {
    const userId = await requireAuth(req).catch(() => null);
    const ip = (req.headers['x-forwarded-for'] || '').split(',')[0].trim() || 'unknown';
    const key = userId ? `u:${userId}` : `ip:${ip}`;
    const { rows } = await sql`
      INSERT INTO coach_usage (key, day, count) VALUES (${key}, CURRENT_DATE, 1)
      ON CONFLICT (key, day) DO UPDATE SET count = coach_usage.count + 1
      RETURNING count
    `;
    if (rows[0].count > DAILY_REQUEST_CAP) {
      res.status(429).json({ error: 'rate_limited' });
      return;
    }
    // Opportunistic prune, not a cron job — coach_usage now backs four separate rate limiters
    // (coach/login/activity-create/avatar) with no retention, so it grows one row per key per day
    // forever. A ~0.5% chance per coach request (this endpoint's traffic is steady) keeps it
    // bounded without needing new scheduling infra.
    if (Math.random() < 0.005) {
      sql`DELETE FROM coach_usage WHERE day < CURRENT_DATE - interval '30 days'`.catch(() => {});
    }
  } catch (err) {
    console.error('coach rate limit unavailable:', err.message);
  }

  // Ignore whatever model/max_tokens the client sent — always force our own values, so a
  // tampered client can't route arbitrary paid requests through this key.
  const body = {
    model: ALLOWED_MODEL,
    max_tokens: MAX_TOKENS_CAP,
    thinking: THINKING,
    output_config: { effort: EFFORT },
    system,
    messages,
  };
  // Un booléen qui ne peut que retirer des capacités : l'app le met à faux pour les questions
  // posées à voix haute en pleine course, où la réponse est lue par synthèse vocale et où
  // personne ne peut voir ni annuler un changement de programme. Tout ce qu'un appelant peut
  // obtenir en mentant ici, c'est un coach qui ne modifie rien.
  if (allowActions === true) {
    body.tools = COACH_TOOLS;
  }

  try {
    const upstream = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    // Passed straight through, unlogged — this function never writes chat content to disk or
    // console, only relays it in real time (see PRIVACY_POLICY.md).
    const text = await upstream.text();
    res.status(upstream.status).setHeader('content-type', 'application/json').send(text);
  } catch {
    res.status(502).json({ error: 'upstream_unreachable' });
  }
});
