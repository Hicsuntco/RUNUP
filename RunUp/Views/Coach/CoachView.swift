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
                            coachBubble("Salut \(profile.name) 👋 Ta forme est au top aujourd'hui (\(profile.readiness)/100). J'ai relevé ta séance à \(profile.todaySession.title). Une question avant de te lancer ?")
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

    private var header: some View {
        HStack(spacing: 12) {
            AppMarkView(size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Ton coach").displayStyle(19).foregroundColor(.white)
                HStack(spacing: 5) {
                    Circle().fill(RUColor.lime).frame(width: 5, height: 5)
                    Text("en ligne · connaît ton historique")
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
                Text(message.text).font(RUFont.sans(12.5)).foregroundColor(Color(hex: 0xFFD79A)).lineSpacing(2)
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
                .foregroundColor(.white)
                .lineSpacing(3)
                .padding(12)
                .background(Color.white.opacity(0.06), in: BubbleShape(tailCorner: .topLeft))
                .overlay(BubbleShape(tailCorner: .topLeft).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
            Spacer(minLength: 40)
        }
    }

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { _ in Circle().fill(RUColor.text2).frame(width: 6, height: 6) }
            }
            .padding(13)
            .background(Color.white.opacity(0.06), in: BubbleShape(tailCorner: .topLeft))
            Spacer()
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("", text: Binding(get: { vm?.draft ?? "" }, set: { vm?.draft = $0 }), prompt: Text("Écris à ton coach…").foregroundColor(RUColor.text3))
                .foregroundColor(.white)
                .font(RUFont.sans(13))
            Button(action: { send(vm?.draft ?? "") }) {
                Image(systemName: "arrow.up").foregroundColor(.white).font(.system(size: 14, weight: .bold))
            }
            .frame(width: 34, height: 34)
            .background(RUColor.rose, in: Circle())
            .buttonStyle(PressableStyle())
        }
        .padding(.leading, 16).padding(.trailing, 8).padding(.vertical, 8)
        .background(Color.white.opacity(0.06), in: Capsule())
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
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(RUColor.card, in: Capsule())
                        .overlay(Capsule().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}
