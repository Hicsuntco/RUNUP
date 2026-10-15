import SwiftUI
import SwiftData
import UIKit

/// AI coach chat — real generative AI, not scripted responses. Mirrors `CoachScreen` in
/// screensB.jsx.
struct CoachView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SubscriptionService.self) private var subscriptions
    @Query(sort: \ChatMessage.timestamp) private var messages: [ChatMessage]
    /// La dernière course, et elle seule. `fetchLimit = 1` plutôt qu'une requête ouverte qu'on
    /// trierait ensuite : cet écran n'a besoin que d'une ligne, et une requête sans plafond grossit
    /// avec l'historique jusqu'à coûter cher sur un onglet qu'on ouvre tous les jours.
    @Query private var dernieresCourses: [RunRecord]

    init() {
        var d = FetchDescriptor<RunRecord>(sortBy: [SortDescriptor(\RunRecord.date, order: .reverse)])
        d.fetchLimit = 1
        _dernieresCourses = Query(d)
    }
    @State private var vm: CoachViewModel?
    @State private var typingBounce = false
    @State private var showClearConfirm = false

    /// `FlowChips` rend chaque puce par un `Text(String)` nu, et la puce tapée part telle quelle au
    /// coach comme message : elle doit donc être dans la langue de l'utilisatrice, pas juste
    /// affichée traduite.
    private let chips = [
        String(localized: "Adapte ma semaine"),
        Accord.selon(f: String(localized: "Je suis fatiguée"), m: String(localized: "Je suis fatigué")),
        String(localized: "Conseils nutrition"),
        String(localized: "Analyse ma dernière sortie")
    ]

    private var profile: UserProfile { appState.profile }

    /// Le coach est la fonctionnalité qui se vend le mieux d'elle-même : il suffit de le laisser
    /// dire bonjour. L'écran garde donc son en-tête, son message d'accueil et l'historique s'il y
    /// en a un — ce qui disparaît, c'est la possibilité de répondre. On voit exactement ce qu'on
    /// n'a pas, ce qui vaut mieux que n'importe quel argumentaire à sa place.
    private var coachLocked: Bool { !subscriptions.unlocks(.coach) }

    /// Ce qu'une personne sans abonnement vient d'écrire. VOLONTAIREMENT NON ENREGISTRÉ.
    ///
    /// Rien de cet échange ne part au serveur et rien n'entre dans `ChatMessage` : il n'y a pas de
    /// réponse à produire, donc pas d'appel à payer, et le jour où elle s'abonne son fil démarre
    /// vierge au lieu de s'ouvrir sur une publicité qu'elle a déjà lue.
    @State private var demandeVerrouillee: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            ceQuIlRegarde
            ScrollViewReader { scrollProxy in
                // `GeometryReader` uniquement pour connaître la hauteur visible du fil, qui sert de
                // hauteur MINIMALE au contenu juste en dessous. C'est ce qui colle la conversation
                // en bas de l'écran tant qu'elle est courte — un seul message d'accueil restait
                // sinon accroché en haut, avec six cents points de vide sous lui. Au-delà de cette
                // hauteur le minimum ne s'applique plus, donc un fil long se comporte exactement
                // comme avant.
                GeometryReader { geo in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            if messages.isEmpty {
                                daySeparator(.now)
                                coachBubble(welcomeMessage)
                            }

                            // Day separators between message groups ("AUJOURD'HUI" / "HIER" / date) —
                            // the whole persisted history lives in one thread, and without them a
                            // reply from last Tuesday read as part of today's conversation.
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                if index == 0 || !Calendar.current.isDate(message.timestamp, inSameDayAs: messages[index - 1].timestamp) {
                                    daySeparator(message.timestamp)
                                }
                                bubble(for: message)
                                    .id(message.id)
                            }

                            if vm?.isTyping == true {
                                typingIndicator
                            }

                            // L'échange verrouillé : sa question, puis la réponse qui explique
                            // ce qu'il manque pour y répondre.
                            if let demande = demandeVerrouillee {
                                lockedAskBubble(demande)
                                lockedReplyBubble
                            }

                            // Les suggestions restent, verrouillées ou non. Elles sont le chemin
                            // le plus court vers la question — donc, sans abonnement, vers la
                            // réponse qui dit ce que l'abonnement apporte.
                            FlowChips(chips: chips) { send($0) }
                                .padding(.vertical, 4)
                        }
                        .padding(.horizontal, 18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: geo.size.height, alignment: .bottom)
                    }
                    .onChange(of: messages.count) {
                        if let last = messages.last { withAnimation { scrollProxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                    // Land on the latest message when (re)opening the tab — `onChange` alone only
                    // fires on NEW messages, so a thread with history opened at the oldest bubble.
                    .onAppear {
                        if let last = messages.last { scrollProxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            // PLUS DE BANDEAU À LA PLACE DE LA SAISIE. Il la REMPLAÇAIT : on voyait l'écran du
            // coach sans jamais pouvoir lui parler, et l'argumentaire occupait le tiers bas d'un
            // écran déjà vide aux quatre cinquièmes.
            //
            // La saisie reste ouverte à tout le monde, et c'est LA RÉPONSE qui dit ce qui manque.
            // On ne lit plus une promesse À CÔTÉ d'une conversation : on fait le geste, et on voit
            // exactement où il s'arrête.
            inputBar
        }
        .background(RUColor.pageBackground)
        .onAppear {
            if vm == nil { vm = CoachViewModel(modelContext: modelContext, profile: profile) }
        }
    }

    /// The zero-message welcome bubble used to always claim "Ta forme est au top" regardless of
    /// the real `readiness` score (even a low one) and regardless of whether any real data backed
    /// it at all — gated on `hasReadinessData` so it's honest instead.
    private var welcomeMessage: String {
        // « J'ai relevé ta séance à Repos. » — la phrase ne veut rien dire en français, et c'est
        // la deuxième du premier message que lit quelqu'un qui découvre le coach.
        let sessionPart = String(localized: "Aujourd'hui, c'est \(profile.todaySession.displayTitle).")
        guard profile.hasReadinessData else {
            return String(localized: "Salut \(profile.name) 👋 \(sessionPart) Une question avant de te lancer ?")
        }
        let formPart: String
        switch profile.readiness {
        case 85...: formPart = String(localized: "Ta forme est au top aujourd'hui (\(profile.readiness)/100).")
        case 65..<85: formPart = String(localized: "Ta forme est correcte aujourd'hui (\(profile.readiness)/100).")
        case 50..<65: formPart = String(localized: "Un peu de fatigue aujourd'hui (\(profile.readiness)/100).")
        default: formPart = String(localized: "Fatigue accumulée aujourd'hui (\(profile.readiness)/100).")
        }
        return String(localized: "Salut \(profile.name) 👋 \(formPart) \(sessionPart) Une question avant de te lancer ?")
    }

    /// CE QU'IL A LU — la preuve, pas un décor.
    ///
    /// Cet écran était vide aux quatre cinquièmes sous un seul message, et le vide était délibéré :
    /// le fil est collé en bas pour qu'une conversation courte ne reste pas accrochée en haut. On
    /// avait donc déplacé le trou, pas l'avoir bouché.
    ///
    /// Ce qui le remplit n'est pas de l'habillage. Le coach se vend sur « il a lu tes dernières
    /// séances » — une promesse invérifiable tant qu'on ne montre pas CE QU'IL A LU. Quatre
    /// chiffres qui viennent tous du profil et de l'historique, et la phrase devient un fait.
    ///
    /// Chaque tuile disparaît quand sa donnée n'existe pas : une forme sans un seul ressenti
    /// derrière serait un nombre inventé, et « — » n'apprend rien à personne.
    private var ceQuIlRegarde: some View {
        let derniere = dernieresCourses.first
        return VStack(alignment: .leading, spacing: 8) {
            Text("Ce qu'il regarde")
                .font(RUFont.sans(.label, weight: .medium))
                .foregroundColor(RUColor.text3)
                .textCase(.uppercase)
                .tracking(1.4)
            HStack(spacing: 8) {
                if profile.hasReadinessData {
                    tuileLue(nom: "Forme", valeur: "\(profile.readiness)/100", accent: true)
                }
                tuileLue(nom: "Aujourd'hui", valeur: profile.todaySession.displayTitle, accent: false)
                if let derniere, derniere.distanceKm > 0 {
                    tuileLue(nom: "Dernière sortie",
                             valeur: String(format: "%.1f km", derniere.distanceKm)
                                 + " · " + PaceModel.paceText(Double(derniere.durationSeconds) / derniere.distanceKm),
                             accent: false)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 4)
    }

    private func tuileLue(nom: String, valeur: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(LocalizedStringKey(nom))
                .font(RUFont.sans(.small, weight: .medium))
                .foregroundColor(RUColor.text3)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(valeur)
                .font(RUFont.sans(.label, weight: .semibold))
                .foregroundColor(accent ? RUColor.rose : RUColor.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10).padding(.horizontal, 12)
        .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous)
            .stroke(RUColor.line, lineWidth: RUSpacing.hairline))
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        HStack(spacing: 12) {
            AppMarkView(size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Ton coach").displayStyle(19).foregroundColor(RUColor.textPrimary)
                // Honest subtitle — the old green "en ligne" dot measured nothing (it was
                // hardcoded, lit even in airplane mode).
                Text("Connaît ton programme")
                    .font(RUFont.sans(.small))
                    .foregroundColor(RUColor.text2)
            }
            Spacer()
            if !messages.isEmpty {
                Button(action: { showClearConfirm = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(RUColor.text3)
                        .frame(width: 44, height: 44)
                        .background(RUColor.card, in: Circle())
                        .overlay(Circle().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Effacer la conversation")
                .confirmationDialog("Effacer toute la conversation ?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                    Button("Effacer", role: .destructive) {
                        for message in messages { modelContext.delete(message) }
                    }
                    Button("Annuler", role: .cancel) {}
                } message: {
                    Text("Le coach garde ton programme et ta forme en tête — seul l'historique des messages est effacé.")
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    private static let separatorFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "EEEE d MMMM"
        return f
    }()

    private func daySeparator(_ date: Date) -> some View {
        let label: String
        if Calendar.current.isDateInToday(date) { label = String(localized: "Aujourd'hui") }
        else if Calendar.current.isDateInYesterday(date) { label = String(localized: "Hier") }
        else { label = Self.separatorFormatter.string(from: date) }
        return Text(label.uppercased())
            .font(RUFont.sans(.micro, weight: .bold)).tracking(1.2)
            .foregroundColor(RUColor.text3)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
    }

    @ViewBuilder
    private func bubble(for message: ChatMessage) -> some View {
        switch message.role {
        case .error:
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(RUColor.amber).font(.system(size: 15))
                Text(message.text).font(RUFont.sans(.label)).foregroundColor(RUColor.amberText).lineSpacing(2)
                Spacer(minLength: 0)
                Button("Réessayer") { retryLast() }
                    .font(RUFont.sans(.small, weight: .bold))
                    .foregroundColor(RUColor.amber)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(PressableStyle())
            }
            .padding(12)
            // Surface neutre : l'accent reste au texte et à l'icône. Un amber
            // dilué donne sa version sale, et le contour de la même couleur la redisait.
            .background(RUColor.card2, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
        case .system:
            appliedChangeRow(message)
        case .coach:
            coachBubble(message.text)
        case .user:
            HStack {
                Spacer(minLength: 40)
                Text(message.text)
                    .font(RUFont.sans(.label))
                    .foregroundColor(RUColor.onRose)
                    .lineSpacing(2)
                    .padding(12)
                    .background(RUColor.rose, in: BubbleShape(tailCorner: .topRight))
            }
        }
    }

    /// Ce que le coach vient de changer au programme.
    ///
    /// Volontairement PAS une bulle : ce n'est pas quelqu'un qui parle, c'est l'app qui rend
    /// compte. Une bulle de plus dans le fil se lirait comme une phrase du coach, et la coureuse
    /// n'aurait aucun moyen de distinguer ce qu'il a dit de ce qu'il a fait.
    ///
    /// `Text(message.text)` et pas `Text(LocalizedStringKey(...))` : la phrase arrive déjà
    /// traduite d'`applyCoachAction`. La repasser par une clé la traduirait deux fois — invisible
    /// en français, où la clé est sa propre traduction, cassé partout ailleurs.
    private func appliedChangeRow(_ message: ChatMessage) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(RUColor.lime)
            Text(message.text)
                .font(RUFont.sans(.small, weight: .semibold))
                .foregroundColor(RUColor.text2)
                .lineSpacing(2)
            Spacer(minLength: 0)
            if vm?.canUndo(message) == true {
                Button("Annuler") { vm?.undoLastAction() }
                    .font(RUFont.sans(.small, weight: .bold))
                    .foregroundColor(RUColor.text3)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(PressableStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        // Un lime à 10 % sur un fond sombre ne donne pas un vert clair, il donne un OLIVE terne —
        // et le liseré à 25 % l'entourait d'un cadre de la même teinte. Le fond devient neutre et
        // le vert reste où il se voit : sur la coche. C'est la même correction que les pastilles,
        // les tuiles d'icône et les cartes de Communauté — ne jamais diluer un accent.
        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// Sa question à elle, dans l'échange verrouillé. Même dessin que les bulles persistées —
    /// `bubble(for:)` attend un `ChatMessage`, et celui-ci n'existe volontairement pas.
    private func lockedAskBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 40)
            Text(text)
                .font(RUFont.sans(.label))
                .foregroundColor(RUColor.onRose)
                .lineSpacing(3)
                .padding(12)
                .background(RUColor.rose, in: BubbleShape(tailCorner: .topRight))
        }
    }

    /// La réponse du coach à qui n'a pas souscrit : la même bulle que les autres, et un bouton.
    ///
    /// Une bulle plutôt qu'une carte d'offre, parce que c'est le coach qui parle — il dit ce qui
    /// lui manque pour répondre, dans sa voix et à sa place dans le fil. Une carte d'offre posée
    /// sous la conversation aurait été quelqu'un d'autre qui parle par-dessus lui.
    private var lockedReplyBubble: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Je peux te répondre vraiment, mais il me faut RUNUP Plus. Le coach lit ton programme, ta forme et tes dernières sorties avant de te répondre — c'est ce qui fait la différence avec une réponse générique.")
                    .font(RUFont.sans(.label))
                    .foregroundColor(RUColor.textPrimary)
                    .lineSpacing(3)
                Button("Découvrir RUNUP Plus") { appState.plusPrompt = .coach }
                    .buttonStyle(AnyButtonStyleBox(SecondaryButtonStyle()))
            }
            .padding(12)
            .background(RUColor.card, in: BubbleShape(tailCorner: .topLeft))
            .overlay(BubbleShape(tailCorner: .topLeft).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
            Spacer(minLength: 24)
        }
    }

    private func coachBubble(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(RUFont.sans(.label))
                .foregroundColor(RUColor.textPrimary)
                .lineSpacing(3)
                .padding(12)
                .background(RUColor.card, in: BubbleShape(tailCorner: .topLeft))
                .overlay(BubbleShape(tailCorner: .topLeft).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
            Spacer(minLength: 40)
        }
    }

    /// Was 3 static dots with no animation at all — every chat app's typing indicator pulses in
    /// sequence, and this is the loading state for the AI reply, shown on every single message.
    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(RUColor.text2).frame(width: 6, height: 6)
                        .offset(y: typingBounce && !reduceMotion ? -3 : 0)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(Double(i) * 0.15), value: typingBounce)
                }
            }
            .padding(13)
            .background(RUColor.card, in: BubbleShape(tailCorner: .topLeft))
            Spacer()
        }
        .onAppear { typingBounce = true }
        // Otherwise silence while waiting for a reply — the bouncing dots carry no VoiceOver
        // content at all.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Le coach écrit…")
    }

    /// Y a-t-il quelque chose à envoyer. Lu par la couleur du bouton ET par son état actif, qui
    /// se contredisaient tant que chacun recalculait la condition de son côté.
    private var canSend: Bool {
        !(vm?.draft ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("", text: Binding(get: { vm?.draft ?? "" }, set: { vm?.draft = $0 }), prompt: Text("Écris à ton coach…").foregroundColor(RUColor.text3))
                .foregroundColor(RUColor.textPrimary)
                .font(RUFont.sans(.label))
                // The keyboard return key used to just dismiss without sending — in a chat, return
                // means send, same as every messaging app.
                .submitLabel(.send)
                .onSubmit { send(vm?.draft ?? "") }
            // Un bouton vide n'est pas un bouton rose PÂLE, c'est un bouton gris.
            //
            // L'opacité à 40 % s'appliquait au disque rose entier : sur un fond sombre, ça donnait
            // un disque bordeaux — la même couleur sale que les pastilles et la case du jour, et
            // pour la même raison. Un état désactivé se dit avec une surface neutre, pas avec un
            // accent délavé.
            Button(action: { send(vm?.draft ?? "") }) {
                Image(systemName: "arrow.up")
                    .foregroundColor(canSend ? RUColor.onRose : RUColor.text3)
                    .font(.system(size: 14, weight: .bold))
            }
            .frame(width: 44, height: 44)
            .background(canSend ? AnyShapeStyle(RUColor.rose) : AnyShapeStyle(RUColor.card2), in: Circle())
            .buttonStyle(PressableStyle())
            .disabled(!canSend)
            .accessibilityLabel("Envoyer")
        }
        .padding(.leading, 16).padding(.trailing, 8).padding(.vertical, 8)
        .background(RUColor.card, in: Capsule())
        .overlay(Capsule().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
        .padding(.horizontal, 16)
        // Les mêmes 96 points qu'avant, mais écrits à partir des mesures de la barre plutôt qu'en
        // dur : c'est ce nombre nu, isolé de tout, qui a laissé la branche verrouillée ci-dessus
        // repartir de zéro.
        .padding(.bottom, RUSpacing.tabBarBottomInset + RUSpacing.tabBarHeight + 28)
        .padding(.top, 8)
    }

    private func send(_ text: String) {
        // Sans abonnement, rien ne part : pas d'appel au modèle, pas d'enregistrement. La bulle
        // d'en face est écrite ici.
        guard !coachLocked else {
            let propre = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !propre.isEmpty else { return }
            vm?.draft = ""
            withAnimation { demandeVerrouillee = propre }
            Analytics.shared.track(.coachMessageSent, ["thread_length": .int(0)])
            return
        }
        // Only the fact that a message was sent, and how deep into the conversation it was — never
        // the message itself. The coach is the one place in this app where what she types is
        // genuinely private (PRIVACY_POLICY.md promises those messages are never stored on our
        // server, only relayed), and an event's `props` bag is a stored Postgres column.
        Analytics.shared.track(.coachMessageSent, ["thread_length": .int(messages.count)])
        vm?.send(text, history: messages)
    }

    private func retryLast() {
        // The error bubble sits after her message in `messages` — the VM re-sends from the
        // existing history without inserting a duplicate user bubble.
        vm?.retry(history: messages.filter { $0.role != .error })
    }
}

/// Chat-bubble tail shape: rounded rect with one sharp corner. Mirrors the CSS
/// `border-radius: 4px 16px 16px 16px` (coach) / `16px 4px 16px 16px` (user) trick.
struct BubbleShape: Shape {
    enum TailCorner { case topLeft, topRight }
    var tailCorner: TailCorner

    func path(in rect: CGRect) -> Path {
        let corners: UIRectCorner = tailCorner == .topLeft
            ? [.topRight, .bottomLeft, .bottomRight]
            : [.topLeft, .bottomLeft, .bottomRight]
        return Path(UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: 16, height: 16)).cgPath)
    }
}

/// Wrapping row of suggestion chips.
struct FlowChips: View {
    var chips: [String]
    var onTap: (String) -> Void

    var body: some View {
        ChipFlowLayout {
            ForEach(chips, id: \.self) { chip in
                Button(action: { onTap(chip) }) {
                    Text(chip)
                        .font(RUFont.sans(.small, weight: .semibold))
                        .foregroundColor(RUColor.text2)
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .frame(minHeight: 44)
                        .background(RUColor.card, in: Capsule())
                        .overlay(Capsule().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}
