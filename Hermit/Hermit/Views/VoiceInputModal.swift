import SwiftUI

struct VoiceInputModal: View {
    @Binding var text: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    let onSend: (String) -> Void

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack {
                    TextEditor(text: $text)
                        .font(.body)
                        .focused($isFocused)
                        .padding()
                }

                if SuperWhisperProvider.isAvailable {
                    Button {
                        SuperWhisperProvider.openForTranscription()
                    } label: {
                        Label("Super Whisper", systemImage: "waveform")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                }
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
