// Ce qui vaut pour toute image qu'on accepte de stocker, et qu'on servira ensuite à des gens.
//
// La même fonction existait DEUX FOIS, sous deux noms — `isValidJpeg` dans api/account et
// `isValidJpegBuffer` dans api/activities — et la photo de couverture d'un club allait en écrire
// une troisième. Trois copies d'un contrôle de sécurité sont trois occasions qu'une seule soit
// corrigée le jour où il faut la corriger.

// Les octets magiques d'un JPEG, et non le préfixe « data:image/... » que le client déclare.
// C'est cette distinction qui arrête un client trafiqué : le préfixe est du texte qu'il écrit
// lui-même, les trois premiers octets sont ce que le fichier EST. Sans ce contrôle, un SVG
// portant un <script> entrerait en base et serait servi à tout un club.
function estUnJpeg(buffer) {
  return buffer.length > 3 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff;
}

// La borne d'une image envoyée en data URI, AVANT décodage. Vérifiée sur la chaîne reçue plutôt
// que sur le tampon décodé : décoder d'abord reviendrait à allouer ce qu'on s'apprête à refuser.
const MAX_DATA_URI = 200000;

const PREFIXE_JPEG = 'data:image/jpeg;base64,';

// Rend le tampon d'un data URI JPEG, ou `null` — longueur, préfixe, base64 et octets magiques.
// Un seul chemin pour les trois points d'entrée qui acceptent une image.
function tamponDepuisDataURI(valeur, maxLongueur = MAX_DATA_URI) {
  if (typeof valeur !== 'string' || valeur.length > maxLongueur || !valeur.startsWith(PREFIXE_JPEG)) {
    return null;
  }
  let decode;
  try {
    decode = Buffer.from(valeur.slice(PREFIXE_JPEG.length), 'base64');
  } catch {
    return null;
  }
  return estUnJpeg(decode) ? decode : null;
}

module.exports = { estUnJpeg, tamponDepuisDataURI, MAX_DATA_URI, PREFIXE_JPEG };
