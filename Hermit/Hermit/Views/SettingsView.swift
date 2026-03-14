import SwiftUI

struct SettingsView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss
    @State private var settings = AppSettings.load()
    @State private var showingAbout = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Voice Provider") {
                    Picker("Provider", selection: $settings.voiceProvider) {
                        Text("None").tag(VoiceProvider.none)
                        Text("Super Whisper").tag(VoiceProvider.superWhisper)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: settings.voiceProvider) { _, _ in
                        settings.save()
                    }
                }

                Section("iCloud Sync") {
                    HStack {
                        Label {
                            Text("iCloud Drive")
                        } icon: {
                            Image(systemName: dataStore.iCloudAvailable ? "checkmark.icloud" : "xmark.icloud")
                                .foregroundStyle(dataStore.iCloudAvailable ? .green : .secondary)
                        }
                        Spacer()
                        Text(dataStore.iCloudAvailable ? "Syncing" : "Unavailable")
                            .foregroundStyle(.secondary)
                    }

                    if dataStore.iCloudAvailable {
                        Text("Your sessions and hosts sync automatically across all devices signed into the same iCloud account.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Sign in to iCloud in Settings to sync data across devices. Data is stored locally until iCloud is available.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("About Hermit") {
                        showingAbout = true
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
        }
    }
}
