// Minimal content filter for the two free-text fields a user controls that other people see:
// their display name (signup) and a club's name (creation). Required by App Store guideline 1.2
// ("a method for filtering objectionable material") alongside the report/block mechanism in
// api/moderation/[action].js — this catches obvious cases at submission time, that catches
// everything else after the fact.
//
// Deliberately a blocklist, not an ML classifier: small surface area (two short free-text
// fields, no open-ended chat/posts), so a normalized substring match is proportionate — not
// meant to be exhaustive, just to stop the obvious cases before they're ever stored.
// Kept to unambiguous, longer terms only — short abbreviations are too prone to false-positive
// on innocuous names/phrases once spaces are stripped for matching (see `normalize`).
const BLOCKLIST = [
  'fuck', 'shit', 'bitch', 'asshole', 'cunt', 'nigger', 'nigga', 'faggot', 'retard',
  'pute', 'salope', 'connard', 'connasse', 'enculé', 'enculée', 'batard', 'bâtard',
  'negre', 'nègre', 'niquer',
];

function normalize(text) {
  return text
    .toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '') // strip accents
    .replace(/[0@]/g, 'o')
    .replace(/[1!]/g, 'i')
    .replace(/[3]/g, 'e')
    .replace(/[$5]/g, 's')
    .replace(/[^a-z0-9]/g, ''); // strip spaces/punctuation so "f u c k" still matches
}

function containsObjectionableContent(text) {
  if (!text) return false;
  const normalized = normalize(text);
  return BLOCKLIST.some((word) => normalized.includes(normalize(word)));
}

module.exports = { containsObjectionableContent };
