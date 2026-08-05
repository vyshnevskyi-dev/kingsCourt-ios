import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("votingEnabled") private var votingEnabled = true
    @AppStorage("seenOnboarding") private var seenOnboarding = true
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Preferences")) {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Fight Reminders", systemImage: "bell.fill")
                    }
                    
                    Toggle(isOn: $votingEnabled) {
                        Label("Enable Voting", systemImage: "hand.raised.fill")
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Event", systemImage: "calendar")
                        Spacer()
                        Text(AppConstants.tournamentDate)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Venue", systemImage: "mappin.and.ellipse")
                        Spacer()
                        Text(AppConstants.venueName)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Legal")) {
                    Link(destination: URL(string: AppConstants.privacyPolicyURL)!) {
                        HStack {
                            Label("Privacy Policy", systemImage: "hand.raised")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button {
                        // Reset all app data
                        UserDefaults.standard.dictionaryRepresentation().keys.forEach { key in
                            UserDefaults.standard.removeObject(forKey: key)
                        }
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Reset App Data")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
