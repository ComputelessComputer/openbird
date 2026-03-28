import OpenbirdKit
import SwiftUI

struct ChatView: View {
    @ObservedObject var model: AppModel

    private let contentWidth: CGFloat = 860
    private let bottomAnchor = "chat-bottom-anchor"

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        if model.chatMessages.isEmpty {
                            EmptyChatState()
                                .frame(maxWidth: .infinity, minHeight: 320)
                        } else {
                            ForEach(model.chatMessages) { message in
                                ChatMessageRow(message: message)
                            }
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(bottomAnchor)
                    }
                    .frame(maxWidth: contentWidth, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 32)
                }
                .background(Color(nsColor: .windowBackgroundColor))
                .onAppear {
                    scrollToBottom(using: proxy, animated: false)
                }
                .onChange(of: model.chatMessages.last?.id) { _, _ in
                    scrollToBottom(using: proxy)
                }
            }

            ChatComposer(model: model)
                .frame(maxWidth: contentWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .background(.bar)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Chat")
    }

    private func scrollToBottom(using proxy: ScrollViewProxy, animated: Bool = true) {
        guard model.chatMessages.isEmpty == false else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(bottomAnchor, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(bottomAnchor, anchor: .bottom)
        }
    }
}

private struct ChatMessageRow: View {
    let message: ChatMessage

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack {
            if isUser == false {
                assistantMessage
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 72)
                userMessage
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var assistantMessage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Openbird")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(message.content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

            if message.citations.isEmpty == false {
                CitationStrip(citations: message.citations)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }

    private var userMessage: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("You")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(message.content)
                .textSelection(.enabled)
        }
        .frame(maxWidth: 560, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.accentColor.opacity(0.13), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct CitationStrip: View {
    let citations: [Citation]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(citations) { citation in
                    Text(citation.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
                }
            }
        }
    }
}

private struct ChatComposer: View {
    @ObservedObject var model: AppModel

    private var canSend: Bool {
        model.chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TextField("", text: $model.chatInput, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .lineLimit(1...6)
                .padding(.leading, 18)
                .padding(.trailing, 64)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08))
                )

            if model.chatInput.isEmpty {
                HStack {
                    Text("Ask what you did, where you were working, or what was open…")
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.leading, 18)
                .padding(.trailing, 64)
                .padding(.vertical, 16)
                .allowsHitTesting(false)
            }

            Button {
                model.sendChat()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .clipShape(Circle())
            .disabled(canSend == false)
            .padding(10)
        }
    }
}

private struct EmptyChatState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ask Openbird about your day")
                .font(.title2.weight(.semibold))
            Text("Questions about what you worked on, where you spent time, or what changed through the day will show up here as a focused conversation.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 560, alignment: .leading)
    }
}
