// Les comptes de la maison.
//
// ─── POURQUOI LA LISTE N'EST PAS DANS CE FICHIER ───────────────────────────────────────────────
//
// CE DÉPÔT EST PUBLIC. Y écrire une adresse personnelle la publie — pour de bon, et dans
// l'historique git même si on la retire ensuite. Une adresse publiée se retrouve dans les
// moissonneuses à spam, et sert d'amorce à qui voudrait tenter une réinitialisation de mot de
// passe quelque part.
//
// La liste vient donc de l'environnement, et de nulle part ailleurs :
//
//     Vercel → le projet → Settings → Environment Variables → Add
//     Name   : RUNUP_ADMIN_EMAILS
//     Value  : adresse@exemple.com,autre@exemple.com
//
// Non définie, PERSONNE n'est admin. Pas de valeur par défaut, pas de repli : un droit qui
// s'accorde tout seul quand une configuration manque est la plus mauvaise des portes.
//
// ─── POURQUOI UNE LISTE ET PAS UNE ADRESSE ─────────────────────────────────────────────────────
//
// Hukaia a appris ça à ses dépens, et c'est écrit dans son code : « Elle a DEUX comptes, et un
// seul était reconnu : celui de son Gmail, codé en dur ici. Sur son iPhone elle se connecte avec
// Apple, ce qui a créé un second compte sous son adresse Hotmail. » Le péage s'est refermé sur la
// personne qui a écrit l'app.
//
// RUNUP a exactement la même porte — « Se connecter avec Apple » — et une de plus : Apple propose
// de MASQUER l'adresse, auquel cas le compte est créé sous un `…@privaterelay.appleid.com` que
// personne ne connaît d'avance. C'est pour ça que la fiche admin de l'app affiche l'adresse que
// le serveur voit : c'est celle-là qu'il faut mettre dans la variable, et aucune autre.
//
// ─── POURQUOI C'EST LE SERVEUR QUI DÉCIDE ──────────────────────────────────────────────────────
//
// Parce que l'app ne connaît pas l'adresse du compte — elle ne la revoit jamais après
// l'inscription — et parce qu'un droit décidé par le client est un droit qu'on s'accorde. Hukaia
// l'a vécu aussi : l'exemption s'y lisait dans `localStorage`, et une ligne dans la console
// suffisait à composer sans limite, à vie. Ici l'adresse est lue en base, à partir de
// l'identifiant que le jeton de session porte — un jeton signé, daté, et qu'on ne se fabrique
// pas.

function listeAdmin() {
  return String(process.env.RUNUP_ADMIN_EMAILS || '')
    .split(',')
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
}

/// `email` tel que la base le porte. La comparaison se fait en minuscules des deux côtés : la
/// base a un index unique sur `lower(email)` (voir db/schema.sql), donc deux casses différentes
/// sont déjà le même compte — les traiter autrement ici ferait qu'une majuscule à l'inscription
/// retirerait le droit.
function estAdmin(email) {
  if (!email) return false;
  return listeAdmin().includes(String(email).trim().toLowerCase());
}

/// Y a-t-il seulement une liste ? La fiche admin de l'app l'affiche, pour distinguer « tu n'es
/// pas dans la liste » de « il n'y a pas de liste » — deux pannes qui se ressemblent à l'écran
/// et qui se corrigent à deux endroits différents.
function listeConfiguree() {
  return listeAdmin().length > 0;
}

module.exports = { estAdmin, listeConfiguree };
