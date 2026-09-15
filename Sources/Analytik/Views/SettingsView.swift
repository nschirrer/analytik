import SwiftUI
import AnalytikCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var keyDraft = ""
    @State private var status: String?
    @State private var isTesting = false

    var body: some View {
        Form {
            Section("Clé API Anthropic") {
                SecureField("Clé API (sk-ant-…)", text: $keyDraft)
                HStack {
                    Button("Enregistrer") {
                        save()
                    }
                    .disabled(keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Supprimer", role: .destructive) {
                        delete()
                    }
                    .disabled(!model.hasAPIKey)
                    Button("Tester la connexion") {
                        test()
                    }
                    .disabled(!model.hasAPIKey || isTesting)
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                if let status = status {
                    Text(status)
                        .font(.caption)
                }
                Text("Créez une clé sur console.anthropic.com. Elle est stockée dans le trousseau macOS et l'usage est facturé à votre compte Anthropic.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Modèle") {
                Picker("Modèle", selection: modelBinding) {
                    ForEach(ClaudeConfig.availableModels, id: \.self) { identifier in
                        Text(identifier).tag(identifier)
                    }
                }
                Text("claude-opus-5 est recommandé. Les demandes refusées par les filtres de sécurité sont automatiquement réessayées sur un modèle de repli.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Confidentialité") {
                Text("Les données des rapports cochés sont envoyées à l'API Anthropic uniquement lorsque vous posez une question. Vérifiez que cet usage est conforme à la politique de votre organisation.")
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .frame(width: 540)
        .padding()
        .onAppear {
            keyDraft = model.apiKey
        }
    }

    private var modelBinding: Binding<String> {
        Binding(get: { model.claudeModel }, set: { model.setClaudeModel($0) })
    }

    private func save() {
        do {
            try model.saveAPIKey(keyDraft)
            status = "Clé enregistrée dans le trousseau."
        } catch {
            status = error.localizedDescription
        }
    }

    private func delete() {
        do {
            try model.deleteAPIKey()
            keyDraft = ""
            status = "Clé supprimée."
        } catch {
            status = error.localizedDescription
        }
    }

    private func test() {
        isTesting = true
        status = nil
        Task {
            do {
                let identifier = try await model.testConnection()
                status = "Connexion réussie (modèle disponible : \(identifier))."
            } catch {
                status = error.localizedDescription
            }
            isTesting = false
        }
    }
}
