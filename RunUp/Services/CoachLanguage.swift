import Foundation

/// La langue dans laquelle le coach parle — une seule source de vérité pour les trois canaux qui
/// doivent impérativement s'accorder.
///
/// Ils étaient tous les trois figés en français, chacun de son côté : le prompt système imposait
/// « Style : français, tutoiement », la reconnaissance vocale utilisait un `SFSpeechRecognizer`
/// en `fr-FR`, et la synthèse vocale une voix `fr-FR`. Faire répondre le coach en anglais sans
/// toucher aux deux autres aurait produit le pire des résultats : une question anglaise
/// transcrite par un moteur français (donc du charabia envoyé au coach), et une réponse anglaise
/// lue à voix haute par une voix française (donc inintelligible, en pleine course, sans écran).
///
/// D'où ce type unique : ajouter une langue, c'est ajouter un cas ici, et les trois canaux
/// suivent ensemble.
enum CoachLanguage: String, CaseIterable {
    case french
    case english
    case spanish

    /// La langue de l'appareil, ramenée à ce que le coach sait parler. Toute autre langue retombe
    /// sur l'anglais plutôt que sur le français : quelqu'un dont le téléphone est en allemand
    /// comprendra presque toujours mieux l'anglais, et l'app ne prétend pas parler allemand.
    static var current: CoachLanguage {
        switch Locale.current.language.languageCode?.identifier {
        case "fr": return .french
        case "es": return .spanish
        default: return .english
        }
    }

    /// L'identifiant BCP-47 passé à `SFSpeechRecognizer` et à `AVSpeechSynthesisVoice`. Une région
    /// est nécessaire : ces deux API veulent une voix et un modèle acoustique concrets, pas un
    /// simple code de langue.
    var speechIdentifier: String {
        switch self {
        case .french: return "fr-FR"
        case .english: return "en-US"
        case .spanish: return "es-ES"
        }
    }

    /// La consigne de langue et de registre insérée dans le prompt système.
    ///
    /// Rédigée DANS la langue cible, et non en français : une instruction « réponds en espagnol »
    /// noyée dans un prompt français est une consigne parmi d'autres, tandis qu'un bloc écrit en
    /// espagnol donne au modèle la langue de sortie par l'exemple autant que par l'instruction.
    ///
    /// Le tutoiement est reporté partout où la langue le distingue — l'app tutoie de bout en bout,
    /// un coach qui vouvoie ne serait plus le même personnage.
    var styleDirective: String {
        switch self {
        case .french:
            return "Style : réponds TOUJOURS en français, tutoiement, chaleureux, motivant, TRÈS concret et bref (2-4 phrases max)."
        case .english:
            return "Style: ALWAYS reply in English, warm, motivating, very concrete and brief (2-4 sentences max)."
        case .spanish:
            return "Estilo: responde SIEMPRE en español, tuteando, cercano, motivador, muy concreto y breve (2-4 frases máximo)."
        }
    }

    /// Même consigne pour la voix, où la contrainte est plus dure : la réponse est lue à voix
    /// haute en pleine course, donc une seule phrase courte.
    var liveVoiceDirective: String {
        switch self {
        case .french:
            return "Réponds TOUJOURS en français, en UNE SEULE phrase courte (15 mots maximum), à l'oral, actionnable dans l'instant — elle ne peut pas lire, la réponse est lue à voix haute. Aucun emoji, aucune ponctuation exotique. Tutoiement, chaleureux, direct."
        case .english:
            return "ALWAYS reply in English, in ONE SHORT sentence (15 words maximum), spoken aloud, actionable right now — she cannot read, the reply is read out loud. No emoji, no unusual punctuation. Warm and direct."
        case .spanish:
            return "Responde SIEMPRE en español, en UNA SOLA frase corta (15 palabras máximo), hablada, accionable al instante — no puede leer, la respuesta se lee en voz alta. Sin emojis ni puntuación rara. Tuteando, cercano y directo."
        }
    }
}
