// Photographie la page publique d'un club, avec une réponse d'API posée à la main.
//
// # POURQUOI CE SCRIPT EXISTE
//
// `public/club.html` est la seule surface de RUNUP qu'un inconnu voit AVANT d'avoir l'app :
// c'est le lien qu'un crew met dans sa bio. Elle n'avait jamais été regardée. En l'ouvrant pour
// la première fois, le 7 novembre 2026, trois défauts se voyaient d'un coup d'œil : le bouton
// « Rejoindre sur RUNUP » pointait sur la page elle-même, l'état d'erreur était une phrase grise
// sans marque ni issue, et tout était en français alors que l'app est livrée en trois langues.
//
// Aucun test ne pouvait les trouver : il n'y a rien à compiler, rien à exécuter, et le serveur
// répond parfaitement. Il fallait voir la page. C'est donc ce que fait ce script — et il la
// photographie dans les trois langues et dans les deux états, parce qu'un seul cas regardé une
// seule fois est exactement ce qui a produit ces trois défauts.
//
// # CE QU'IL REFUSE
//
//   · une erreur JavaScript, quelle qu'elle soit ;
//   · une page sans bouton — l'état d'erreur en a un lui aussi, et c'est le correctif du jour ;
//   · un échappement qui laisse une valeur sortir de son attribut : le cas « méchant » pose un
//     guillemet droit dans l'URL de couverture et vérifie qu'aucun `onerror` n'a pu s'exécuter.
//
// Les images, elles, ne se jugent pas toutes seules : elles partent dans l'artefact, et
// quelqu'un les ouvre. C'est la leçon de la journée — un vert dit que le fichier a été écrit,
// pas ce qu'il y a dessus.
const { chromium } = require('playwright');
const path = require('path');

const BASE = process.env.CLUB_BASE || 'http://localhost:8731';
const SORTIE = process.argv[2] || '.';

const CLUB = {
  name: "Les Chiens de Faïence",
  city: "Paris 11e",
  memberCount: 34,
  description: "On se retrouve au Père-Lachaise trois fois par semaine. Allures de 4'00 à 6'30, personne ne rentre seul.",
  coverUrl: null,
  sessions: [
    { startsAt: new Date(Date.now() + 86400000).toISOString(), title: "Fractionné 8 × 400 m", location: "Stade Léo-Lagrange", going: 12, repeatsWeekly: true },
    { startsAt: new Date(Date.now() + 3 * 86400000).toISOString(), title: "Sortie longue 18 km", location: "Bois de Vincennes, entrée Daumesnil", going: 1, repeatsWeekly: false },
    { startsAt: new Date(Date.now() + 5 * 86400000).toISOString(), title: "Footing de récupération", location: "", going: 0, repeatsWeekly: false },
  ],
};

const CAS = [
  { nom: "fr-normal", langue: "fr-FR", club: CLUB, etat: 200 },
  { nom: "en-normal", langue: "en-GB", club: CLUB, etat: 200 },
  { nom: "es-normal", langue: "es-ES", club: CLUB, etat: 200 },
  { nom: "fr-absent", langue: "fr-FR", club: null, etat: 404 },
  { nom: "es-absent", langue: "es-ES", club: null, etat: 404 },
  // Un club d'une personne, sans ville, sans description, sans séance : le minimum qu'on puisse
  // publier, et l'écran qui en dit le moins.
  { nom: "fr-solo", langue: "fr-FR", etat: 200,
    club: { ...CLUB, memberCount: 1, city: null, description: null, sessions: [] } },
  // Une couverture dont l'URL ne répond pas : elle laissait un cadre cassé de 240 points qui
  // poussait le nom du club hors de l'écran.
  { nom: "fr-couverture-morte", langue: "fr-FR", etat: 200,
    club: { ...CLUB, coverUrl: 'https://exemple.invalide/absente.png' } },
  // La couverture porte un guillemet droit. Si l'échappement est bon, l'attribut ne se referme
  // pas et aucun `onerror` ne s'exécute.
  { nom: "fr-mechant", langue: "fr-FR", etat: 200, club: {
      ...CLUB, name: 'Club <script>alert(1)</script>',
      coverUrl: 'https://exemple.invalide/x.png" onerror="document.title=\'VOLE\'',
    } },
];

(async () => {
  const navigateur = await chromium.launch();
  const defauts = [];
  for (const cas of CAS) {
    const contexte = await navigateur.newContext({
      viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, locale: cas.langue,
    });
    const page = await contexte.newPage();
    const erreurs = [];
    page.on("pageerror", (e) => erreurs.push(String(e)));
    await page.route("**/api/clubs/public*", (route) => {
      if (cas.etat !== 200) return route.fulfill({ status: cas.etat, body: "{}" });
      route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(cas.club) });
    });
    await page.goto(BASE + "/club.html?id=00000000-0000-0000-0000-000000000000");
    await page.waitForTimeout(400);
    await page.screenshot({ path: path.join(SORTIE, `club-${cas.nom}.png`), fullPage: true });

    const titre = await page.title();
    const lang = await page.evaluate(() => document.documentElement.lang);
    const cta = await page.evaluate(() => {
      const a = document.querySelector('a.cta');
      return a ? a.getAttribute('href') : null;
    });
    const attributsDeLimage = await page.evaluate(() => {
      const i = document.querySelector('img.cover');
      return i ? [...i.attributes].map((a) => a.name).join(',') : '';
    });

    if (erreurs.length) defauts.push(`${cas.nom} : ${erreurs.join(' | ')}`);
    if (!cta) defauts.push(`${cas.nom} : aucun bouton — même l'état d'erreur doit en avoir un`);
    if (cta && !/^https:\/\/apps\.apple\.com\//.test(cta)) {
      defauts.push(`${cas.nom} : le bouton mène à « ${cta} » et non à l'App Store`);
    }
    if (cas.nom === 'fr-couverture-morte' && attributsDeLimage) {
      defauts.push("fr-couverture-morte : le cadre cassé est resté dans la page");
    }
    if (cas.nom === 'fr-mechant') {
      if (titre === 'VOLE') defauts.push("fr-mechant : la valeur est sortie de son attribut");
      if (/onerror/.test(attributsDeLimage)) {
        defauts.push(`fr-mechant : l'image a gagné un attribut (${attributsDeLimage})`);
      }
    }
    console.log(`  ${cas.nom.padEnd(11)} lang=${lang} bouton=${cta || 'AUCUN'} `
      + `erreurs=${erreurs.length || 'aucune'}`);
    await contexte.close();
  }
  await navigateur.close();

  if (defauts.length) {
    console.error(`\n${defauts.length} défaut(s) :`);
    defauts.forEach((d) => console.error(`  · ${d}`));
    process.exit(1);
  }
  console.log(`\nLes ${CAS.length} cas de la page publique passent ✓ — les images sont dans l'artefact.`);
})();
