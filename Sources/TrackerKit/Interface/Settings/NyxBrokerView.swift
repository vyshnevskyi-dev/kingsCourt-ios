// NyxBrokerView.swift
// In-app settings sheet (#1, opt-in via security.privacy_in_settings).
//
// A small, conventional settings surface: a "Privacy Policy" row that
// opens ``NyxDispatcherConfig.privacyURL`` in ``NyxBuilderView``, plus an app
// version row. Presented from the gear affordance the NyxFlow overlay
// layer renders over native content (see ``NyxStreamModifier``).

import SwiftUI

struct NyxBrokerView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let url = NyxDispatcherConfig.privacyURL {
                        NavigationLink {
                            NyxBuilderView(url: url)
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
