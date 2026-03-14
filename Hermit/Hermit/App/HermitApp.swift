import SwiftUI

@main
struct HermitApp: App {
    @State private var dataStore = DataStore()
    @State private var voiceCoordinator = VoiceInputCoordinator()
    @State private var showingAbout = !AboutView.hasSeenAbout

    var body: some Scene {
        WindowGroup {
            SessionListView()
                .environment(dataStore)
                .environment(voiceCoordinator)
                .onOpenURL { url in
                    voiceCoordinator.handleCallbackURL(url)
                }
                .sheet(isPresented: $showingAbout) {
                    AboutView.hasSeenAbout = true
                } content: {
                    AboutView()
                }
        }
    }
}
