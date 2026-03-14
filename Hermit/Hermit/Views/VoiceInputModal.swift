import SwiftUI

struct VoiceInputModal: View {
    @Binding var text: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    let onSend: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $text)
                    .font(.body)
                    .focused($isFocused)
                    .padding()
            }
            .navigationTitle("Voice Input")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        onSend(text)
                        dismiss()
                    }
                    .disabled(text.isEmpty)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}
