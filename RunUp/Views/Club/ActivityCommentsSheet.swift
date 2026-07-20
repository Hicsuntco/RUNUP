import SwiftUI

/// Real comments on one club-mate's activity (see `ClubService.fetchComments`/`postComment`) —
/// opened from the comment button next to kudos in `ClubView`'s feed. Report/block on a comment
/// author are owned by `ClubView` (its confirmationDialog/alert are already wired there), this
/// only calls back into it, same split as `ClubManagementView`.
struct ActivityCommentsSheet: View {
    @Environment(\.dismiss) private var dismiss
    var activity: FeedItem
    var currentUserId: String?
    var clubService: ClubService
    /// Called once a comment is successfully posted, so `ClubView` can bump the feed's local
    /// `commentsCount` without a full refetch.
    var onCommentPosted: () -> Void
    var onReport: (CommentItem) -> Void
    var onBlock: (CommentItem) -> Void

    @State private var comments: [CommentItem] = []
    @State private var isLoading = true
    @State private var newText = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView().tint(RUColor.rose).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if comments.isEmpty {
                                Text("Aucun commentaire pour l'instant — sois le premier !")
                                    .font(RUFont.sans(12)).foregroundColor(RUColor.text3)
                                    .frame(maxWidth: .infinity).padding(.vertical, 30)
                            }
                            ForEach(comments) { comment in
                                commentRow(comment)
                            }
                        }
                        .padding(16)
                    }
                }

                if let errorMessage {
                    Text(errorMessage).font(RUFont.sans(11)).foregroundColor(RUColor.rose)
                        .padding(.horizontal, 16).padding(.top, 4)
                }

                composer
            }
            .background(RUColor.bg)
            .navigationTitle("Commentaires")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
        }
        .preferredColorScheme(RUColor.colorScheme)
        .task { await load() }
    }

    private func commentRow(_ comment: CommentItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(RUColor.rose).frame(width: 28, height: 28)
                .overlay(Text(String(comment.name.prefix(1))).displayStyle(11).foregroundColor(.white))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(comment.name).font(RUFont.sans(12, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                    Text(comment.createdAt.relativeDescription).font(RUFont.sans(9.5)).foregroundColor(RUColor.text3)
                }
                Text(comment.text).font(RUFont.sans(12.5)).foregroundColor(RUColor.text2).lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .contextMenu {
            if comment.userId != currentUserId {
                Button("Signaler ce commentaire") { onReport(comment) }
                Button("Bloquer \(comment.name)", role: .destructive) { onBlock(comment) }
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Écris un commentaire…", text: $newText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(RUFont.sans(13))
                .foregroundColor(RUColor.textPrimary)
                .lineLimit(1...4)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RUColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))

            Button(action: { Task { await send() } }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? RUColor.text3 : RUColor.rose)
            }
            .buttonStyle(PressableStyle())
            .disabled(newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            comments = try await clubService.fetchComments(activityId: activity.id)
        } catch {
            errorMessage = "Impossible de charger les commentaires."
        }
        isLoading = false
    }

    private func send() async {
        let text = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSending = true
        errorMessage = nil
        do {
            let comment = try await clubService.postComment(activityId: activity.id, text: text)
            comments.append(comment)
            newText = ""
            onCommentPosted()
        } catch ClubServiceError.badResponse(422, _) {
            errorMessage = "Ce message n'est pas autorisé — reformule-le."
        } catch {
            errorMessage = "Impossible d'envoyer, réessaie."
        }
        isSending = false
    }
}
