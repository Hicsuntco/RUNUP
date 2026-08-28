import SwiftUI
import SwiftData
import UIKit

/// AI coach chat — real generative AI, not scripted responses. Mirrors `CoachScreen` in
/// screensB.jsx.
struct CoachView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \ChatMessage.timestamp) private var messages: [ChatMessage]
    @State private var vm: CoachViewModel?
    @State private var typingBounce = false
    @State private var showClearConfirm = false

    /// `FlowChips` rend chaque puce par un `Text(String)` nu, et la puce tapée part telle quelle au
    /// coach comme message : elle doit donc être dans la langue de l'utilisatrice, pas juste
    /// affichée traduite.
    private let chips = [
        String(localized: "Adapte ma semaine"),
        String(localized: "Je suis fatiguée"),
        String(localized: "Conseils nutrition"),
        String(localized: "Analyse ma dernière sortie")
    ]

    private var profile: UserProfile { appState.profile }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { scrollProxy in
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

                        FlowChips(chips: chips) { send($0) }
                            .padding(.vertical, 4)
                    }
                    .padding(.horizontal, 18)
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
        let sessionPart = String(localized: "J'ai relevé ta séance à \(profile.todaySession.displayTitle).")
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
            .background(RUColor.amber.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.amber.opacity(0.3), lineWidth: RUSpacing.hairline))
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

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("", text: Binding(get: { vm?.draft ?? "" }, set: { vm?.draft = $0 }), prompt: Text("Écris à ton coach…").foregroundColor(RUColor.text3))
                .foregroundColor(RUColor.textPrimary)
                .font(RUFont.sans(.label))
                // The keyboard return key used to just dismiss without sending — in a chat, return
                // means send, same as every messaging app.
                .submitLabel(.send)
                .onSubmit { send(vm?.draft ?? "") }
            Button(action: { send(vm?.draft ?? "") }) {
                Image(systemName: "arrow.up").foregroundColor(RUColor.onRose).font(.system(size: 14, weight: .bold))
            }
            .frame(width: 44, height: 44)
            .background(RUColor.rose, in: Circle())
            .buttonStyle(PressableStyle())
            .opacity((vm?.draft ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
            .disabled((vm?.draft ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Envoyer")
        }
        .padding(.leading, 16).padding(.trailing, 8).padding(.vertical, 8)
        .background(RUColor.card, in: Capsule())
        .overlay(Capsule().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
        .padding(.horizontal, 16)
        .padding(.bottom, 96)
        .padding(.top, 8)
    }

    private func send(_ text: String) {
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
