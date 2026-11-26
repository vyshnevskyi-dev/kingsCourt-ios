







import SwiftUI

struct NyxBrokerView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let url = NyxDispatcherConfig.privacyURL {
                        NavigationLink {
                            NyxQuartzView(url: url)
                                .ignoresSafeArea(edges: .bottom)
                                .navigationTitle("Privacy Policy")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            Label("Privacy Policy", systemImage: "lock.shield")
                        }
                    }
                } header: {
                    Text("Legal")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(NyxCometHelper.shared.appVersion)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
