import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "terminal")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)

                    Text("Hermit")
                        .font(.largeTitle.bold())

                    Text("A focused SSH client for developers who live in tmux and Claude Code.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Divider()
                        .padding(.horizontal, 32)

                    VStack(alignment: .leading, spacing: 16) {
                        Label {
                            Text("Hermit is open source so you can review exactly what runs on your device and how your credentials are handled.")
                        } icon: {
                            Image(systemName: "lock.shield")
                                .foregroundStyle(.green)
                        }

                        Label {
                            Text("Licensed for personal use. This software may not be sold or redistributed commercially.")
                        } icon: {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.orange)
                        }

                        Label {
                            Text("View source, report issues, or contribute on GitHub.")
                        } icon: {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .foregroundStyle(.blue)
                        }

                        Label {
                            Text("If you find Hermit useful, consider donating to one of the open-source projects listed in the GitHub README.")
                        } icon: {
                            Image(systemName: "heart")
                                .foregroundStyle(.pink)
                        }
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 32)

                    Link(destination: URL(string: "https://github.com/placeholder/hermit")!) {
                        HStack {
                            Image(systemName: "arrow.up.right.square")
                            Text("View on GitHub")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal, 32)

                    Text("v1.0")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 40)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    static var hasSeenAbout: Bool {
        get { UserDefaults.standard.bool(forKey: "hasSeenAbout") }
        set { UserDefaults.standard.set(newValue, forKey: "hasSeenAbout") }
    }
}
