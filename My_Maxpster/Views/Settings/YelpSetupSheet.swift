//
//  YelpSetupSheet.swift
//  My_Maxpster
//
//  Lets the user paste a Yelp Fusion API key, verifies it, and stores it in Keychain.
//

import SwiftUI

struct YelpSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var key: String = ""
    @State private var revealKey: Bool = false
    @State private var status: Status = .idle
    @State private var hasExistingKey: Bool = false

    enum Status: Equatable {
        case idle
        case verifying
        case verified
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    instructions
                } header: {
                    Text("Get a Yelp API key")
                } footer: {
                    Text("The free tier allows 500 API calls per day, which is more than enough to enrich places one at a time. Yelp's coverage is strongest in the US/Canada.")
                }

                Section {
                    if revealKey {
                        TextField("Yelp API key", text: $key)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .disableAutocorrection(true)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField("Yelp API key", text: $key)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                    }
                    Toggle("Show key", isOn: $revealKey)
                        .font(.caption)

                    Button {
                        verify()
                    } label: {
                        switch status {
                        case .verifying:
                            HStack {
                                ProgressView().controlSize(.small)
                                Text("Verifying with Yelp…")
                            }
                        default:
                            Label("Verify & Save", systemImage: "checkmark.shield")
                        }
                    }
                    .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || status == .verifying)

                    if hasExistingKey {
                        Button(role: .destructive) {
                            YelpService.deleteAPIKey()
                            key = ""
                            hasExistingKey = false
                            status = .idle
                        } label: {
                            Label("Remove stored key", systemImage: "trash")
                        }
                    }
                } header: {
                    Text("API Key")
                } footer: {
                    statusFooter
                }

                Section("Privacy") {
                    Label("Stored in iOS Keychain on this device only.", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("Never sent anywhere except api.yelp.com over HTTPS.", systemImage: "network")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Yelp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.bold()
                }
            }
            .onAppear {
                hasExistingKey = YelpService.hasAPIKey
            }
        }
    }

    @ViewBuilder
    private var instructions: some View {
        VStack(alignment: .leading, spacing: 10) {
            step(1, "Go to developer.yelp.com and sign in with a free Yelp account.")
            step(2, "Open “Manage App” (top right) and click “Create New App”.")
            step(3, "Fill the form (any app name + your email + “Personal” industry are fine).")
            step(4, "After creation, copy the “API Key” shown on the next page (a long string starting with letters/digits).")
            step(5, "Paste it below and tap “Verify & Save”.")

            Button {
                if let url = URL(string: "https://www.yelp.com/developers/v3/manage_app") {
                    openURL(url)
                }
            } label: {
                Label("Open developer.yelp.com", systemImage: "safari")
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var statusFooter: some View {
        switch status {
        case .idle:
            if hasExistingKey {
                Label("A key is already saved on this device.", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                EmptyView()
            }
        case .verifying:
            EmptyView()
        case .verified:
            Label("Key verified and saved.", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failed(let msg):
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private func verify() {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Save first so YelpService can read it, then verify with a real call.
        _ = YelpService.saveAPIKey(trimmed)
        status = .verifying

        Task {
            let result = await YelpService.verifyCurrentKey()
            switch result {
            case .success:
                status = .verified
                hasExistingKey = true
            case .failure(let error):
                YelpService.deleteAPIKey()
                hasExistingKey = false
                status = .failed(error.localizedDescription)
            }
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.appAccent)
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
