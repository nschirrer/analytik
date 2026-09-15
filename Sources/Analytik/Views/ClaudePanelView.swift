import SwiftUI
import AnalytikCore

struct ClaudePanelView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if model.hasAPIKey {
                conversation
            } else {
                missingKey
            }
            Divider()
            ChatComposerView()
        }
    }

    private var header: some View {
        HStack {
            Label("Analyse avec Claude", systemImage: "sparkles")
                .font(.headline)
            Spacer()
            if let servedBy = model.servedBy {
                Text(servedBy)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Button("Effacer") {
                model.clearChat()
            }
            .controlSize(.small)
            .disabled(model.chat.isEmpty)
        }
        .padding(12)
    }

    private var missingKey: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "key")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Aucune clé API Anthropic n'est configurée.")
                .font(.headline)
            Text("Ajoutez votre clé dans les réglages pour interroger Claude sur les rapports cochés.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            SettingsLink {
                Text("Ouvrir les réglages…")
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if model.chat.isEmpty {
                        SuggestedQuestionsView()
                    }
                    ForEach(model.chat) { message in
                        ChatBubbleView(message: message)
                    }
                    if let error = model.chatError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(12)
            }
            .onChange(of: model.chat) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}

struct SuggestedQuestionsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Posez une question sur les rapports cochés, par exemple :")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(AppModel.suggestedQuestions, id: \.self) { question in
                Button {
                    model.ask(question)
                } label: {
                    Text(question)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .disabled(model.selectedReports.isEmpty || model.isStreaming)
            }
        }
    }
}

struct ChatBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 6) {
                if message.text.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(attributedText)
                        .textSelection(.enabled)
                }
                if let note = message.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(background, in: RoundedRectangle(cornerRadius: 10))
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private var background: Color {
        message.role == .user ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor)
    }

    private var attributedText: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: message.text, options: options)) ?? AttributedString(message.text)
    }
}

struct ChatComposerView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Posez une question sur les données…", text: $model.draft, axis: .vertical)
                    .lineLimit(1...6)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        model.ask(model.draft)
                    }
                if model.isStreaming {
                    Button("Arrêter") {
                        model.cancelStreaming()
                    }
                } else {
                    Button("Envoyer") {
                        model.ask(model.draft)
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!model.hasAPIKey || model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            Text(footer)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    private var footer: String {
        let count = model.selectedReports.count
        var text = "Les données des \(count) rapport\(count > 1 ? "s" : "") coché\(count > 1 ? "s" : "") sont envoyées à Claude avec votre question."
        if model.lastCacheRead > 0 {
            text += " Cache : \(model.lastCacheRead) jetons relus."
        }
        return text
    }
}
