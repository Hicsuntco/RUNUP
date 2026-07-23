import SwiftUI
import SwiftData
import UIKit

/// AI coach chat — real generative AI, not scripted responses. Mirrors `CoachScreen` in
/// screensB.jsx.
struct CoachView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatMessage.timestamp) private var messages: [ChatMessage]
    @State private var vm: CoachViewModel?
    @State private var typingBounce = false

    private let chips = ["Adapte ma semaine", "Je suis fatiguée", "Conseils nutrition", "Analyse ma dernière sortie"]

    private var profile: UserProfile { appState.profile }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("AUJOURD'HUI")
                            .font(RUFont.sans(10)).foregroundColor(RUColor.text3)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)

                        if messages.isEmpty {
                            coachBubble(welcomeMessage)
                        }

                        ForEach(messages) { message in
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
            }
            inputBar
        }
        .background(RUColor.bg)
        .onAppear {
            if vm == nil { vm = CoachViewModel(modelContext: modelContext, profile: profile) }
        }
    }

    /// The zero-message welcome bubble used to always claim "Ta forme est au top" regardless of
    /// the real `readiness` score (even a low one) and regardless of whether any real data backed
    /// it at all — mirrors the honest, `hasReadinessData`-gated copy `HomeView.readinessMessage`
    /// already uses.
    private var welcomeMessage: String {
        let sessionPart = "J'ai relevé ta séance à \(profile.todaySession.title)."
        guard profile.hasReadinessData else {
            return "Salut \(profile.name) 👋 \(sessionPart) Une question avant de te lancer ?"
        }
        let formPart: String
        switch profile.readiness {
        case 85...: formPart = "Ta forme est au top aujourd'hui (\(profile.readiness)/100)."
        case 65..<85: formPart = "Ta forme est correcte aujourd'hui (\(profile.readiness)/100)."
        case 50..<65: formPart = "Un peu de fatigue aujourd'hui (\(profile.readiness)/100)."
        default: formPart = "Fatigue accumulée aujourd'hui (\(profile.readiness)/100)."
        }
        return "Salut \(profile.name) 👋 \(formPart) \(sessionPart) Une question avant de te lancer ?"
    }

    private var header: some View {
        HStack(spacing: 12) {
            AppMarkView(size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Ton coach").displayStyle(19).foregroundColor(RUColor.textPrimary)
                HStack(spacing: 5) {
                    Circle().fill(RUColor.lime).frame(width: 5, height: 5)
                    Text("en ligne")
                        .font(RUFont.sans(10))
                        .foregroundColor(RUColor.lime)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func bubble(for message: ChatMessage) -> some View {
        switch message.role {
        case .error:
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(RUColor.amber).font(.system(size: 15))
                Text(message.text).font(RUFont.sans(12.5)).foregroundColor(RUColor.amberText).lineSpacing(2)
                Spacer(minLength: 0)
                Button("Réessayer") { retryLast() }
                    .font(RUFont.sans(11, weight: .bold))
                    .foregroundColor(RUColor.amber)
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
                    .font(RUFont.sans(13))
                    .foregroundColor(.white)
                    .lineSpacing(2)
                    .padding(12)
                    .background(RUColor.rose, in: BubbleShape(tailCorner: .topRight))
            }
        }
    }

    private func coachBubble(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(RUFont.sans(13))
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
                        .offset(y: typingBounce ? -3 : 0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(Double(i) * 0.15), value: typingBounce)
                }
            }
            .padding(13)
            .background(RUColor.card, in: BubbleShape(tailCorner: .topLeft))
            Spacer()
        }
        .onAppear { typingBounce = true }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("", text: Binding(get: { vm?.draft ?? "" }, set: { vm?.draft = $0 }), prompt: Text("Écris à ton coach…").foregroundColor(RUColor.text3))
                .foregroundColor(RUColor.textPrimary)
                .font(RUFont.sans(13))
                // The keyboard return key used to just dismiss without sending — in a chat, return
                // means send, same as every messaging app.
                .submitLabel(.send)
                .onSubmit { send(vm?.draft ?? "") }
            Button(action: { send(vm?.draft ?? "") }) {
                Image(systemName: "arrow.up").foregroundColor(.white).font(.system(size: 14, weight: .bold))
            }
            .frame(width: 34, height: 34)
            .background(RUColor.rose, in: Circle())
            .buttonStyle(PressableStyle())
        }
        .padding(.leading, 16).padding(.trailing, 8).padding(.vertical, 8)
        .background(RUColor.card, in: Capsule())
        .overlay(Capsule().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
        .padding(.horizontal, 16)
        .padding(.bottom, 96)
        .padding(.top, 8)
    }

    private func send(_ text: String) {
        vm?.send(text, history: messages)
    }

    private func retryLast() {
        guard let lastUser = messages.last(where: { $0.role == .user }) else { return }
        send(lastUser.text)
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
                        .font(RUFont.sans(11, weight: .semibold))
                        .foregroundColor(RUColor.text2)
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(RUColor.card, in: Capsule())
                        .overlay(Capsule().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}
