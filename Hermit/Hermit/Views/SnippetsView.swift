import SwiftUI

struct Snippet: Identifiable {
    let id = UUID()
    let label: String
    let command: String
    let description: String
    let autoExecute: Bool
}

struct SnippetsView: View {
    @Environment(\.dismiss) private var dismiss
    let onSend: (String) -> Void

    private let snippets = [
        Snippet(
            label: "List sessions",
            command: "tmux list-sessions",
            description: "Show all tmux sessions with window count and status",
            autoExecute: true
        ),
        Snippet(
            label: "New session",
            command: "tmux new-session -s ",
            description: "Create a named tmux session (append name)",
            autoExecute: false
        ),
        Snippet(
            label: "Attach session",
            command: "tmux attach -t ",
            description: "Attach to an existing session (append name)",
            autoExecute: false
        ),
        Snippet(
            label: "Kill session",
            command: "tmux kill-session -t ",
            description: "Kill a specific session (append name)",
            autoExecute: false
        ),
        Snippet(
            label: "Detach",
            command: "tmux detach",
            description: "Detach from the current tmux session",
            autoExecute: true
        ),
        Snippet(
            label: "List windows",
            command: "tmux list-windows",
            description: "Show windows in the current session",
            autoExecute: true
        ),
    ]

    var body: some View {
        NavigationStack {
            List(snippets) { snippet in
                Button {
                    onSend(snippet.autoExecute ? snippet.command + "\r" : snippet.command)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snippet.label)
                            .font(.body.weight(.medium))
                        Text(snippet.command)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.blue)
                        Text(snippet.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Snippets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
