//
//  ConfigView.swift
//  ContentAnalytics Demo
//
//  Configuration and settings for the demo app
//

import AEPCore
import AEPAssurance
import AEPEdgeIdentity
import AEPEdgeConsent
import SwiftUI

struct ConfigView: View {
    @AppStorage("currentEcid") private var currentEcid = ""
    @AppStorage("environmentFileId") private var environmentFileId = "staging/b42a0d18ad1d/20b6e71fd073/launch-d7aa2913937f-development"
    @State private var assuranceURL = ""
    @State private var showAssuranceSuccessDialog = false
    @State private var showAssuranceErrorDialog = false
    @State private var assuranceErrorMessage = ""
    @State private var consentStatus = "Unknown"
    
    var body: some View {
        NavigationView {
            Form {
                // Identity Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Experience Cloud ID")
                            .font(.headline)
                        
                        if currentEcid.isEmpty {
                            Text("Loading...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text(currentEcid)
                                .font(.caption)
                                .monospaced()
                                .foregroundColor(.blue)
                                .onTapGesture {
                                    UIPasteboard.general.string = currentEcid
                                }
                            Text("Tap to copy")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Identity")
                }
                
                // Launch Configuration
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Environment ID")
                            .font(.headline)
                        Text(environmentFileId)
                            .font(.caption)
                            .monospaced()
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    Button(action: {
                        // Reset to the new default Launch ID
                        environmentFileId = "staging/b42a0d18ad1d/20b6e71fd073/launch-d7aa2913937f-development"
                    }) {
                        Label("Reset to New Launch ID", systemImage: "arrow.clockwise")
                            .foregroundColor(.blue)
                    }
                } header: {
                    Text("Adobe Launch")
                } footer: {
                    Text("Tap 'Reset to New Launch ID' to update, then restart the app")
                }
                
                // Consent Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Status:")
                                .fontWeight(.medium)
                            Spacer()
                            Text(consentStatus)
                                .foregroundColor(consentStatus == "Opted In" ? .green : .red)
                        }
                        
                        HStack(spacing: 12) {
                            Button("Opt In") {
                                MobileSDK.shared.updateConsent(value: "y")
                                consentStatus = "Opted In"
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            
                            Button("Opt Out") {
                                MobileSDK.shared.updateConsent(value: "n")
                                consentStatus = "Opted Out"
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Privacy Consent")
                } footer: {
                    Text("Controls whether data is sent to Adobe Experience Platform")
                }
                
                // Assurance Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Assurance Session URL", text: $assuranceURL)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .textInputAutocapitalization(.never)
                        
                        Text("Get URL from: experience.adobe.com/#/assurance")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Button("Connect to Assurance") {
                            let trimmedURL = assuranceURL.trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            // Validate URL format - must contain BOTH griffon.adobe.com AND session ID
                            // OR start with aep://
                            if trimmedURL.isEmpty {
                                assuranceErrorMessage = "Please enter an Assurance session URL"
                                showAssuranceErrorDialog = true
                            } else if !(trimmedURL.contains("griffon.adobe.com") && trimmedURL.contains("adb_validation_sessionid")) &&
                                      !trimmedURL.hasPrefix("aep://") {
                                assuranceErrorMessage = "Invalid Assurance URL format.\n\nExpected format:\ngriffon.adobe.com?adb_validation_sessionid=abc-123-...\n\nOr:\naep://griffon.adobe.com?adb_validation_sessionid=...\n\nPlease copy the URL from the Assurance UI."
                                showAssuranceErrorDialog = true
                            } else if let url = URL(string: trimmedURL) {
                                Assurance.startSession(url: url)
                                showAssuranceSuccessDialog = true
                            } else {
                                assuranceErrorMessage = "Invalid URL format. Please check and try again."
                                showAssuranceErrorDialog = true
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(assuranceURL.isEmpty)
                        .alert("Assurance Session Started", isPresented: $showAssuranceSuccessDialog) {
                            Button("OK", role: .cancel) { }
                        } message: {
                            Text("Check the Assurance UI for:\n• Green \"Device Connected\" indicator\n• Events appearing in real-time\n\nTrigger events by clicking tracking buttons in the app.")
                        }
                        .alert("Connection Failed", isPresented: $showAssuranceErrorDialog) {
                            Button("OK", role: .cancel) { }
                        } message: {
                            Text(assuranceErrorMessage)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("AEP Assurance")
                } footer: {
                    Text("Connect to debug and validate events sent to Adobe Experience Platform")
                }
                
                // SDK Info
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Log Level:")
                            Spacer()
                            Text("Debug")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Extensions:")
                            Spacer()
                            Text("7 loaded")
                                .foregroundColor(.secondary)
                        }
                        
                        Button("Refresh Identities") {
                            MobileSDK.shared.getIdentities()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Refresh Consent") {
                            MobileSDK.shared.getConsents()
                        }
                        .buttonStyle(.bordered)
                    }
                } header: {
                    Text("SDK Info")
                }
            }
            .navigationTitle("Configuration")
            .navigationBarTitleDisplayMode(.automatic)
        }
        .onAppear {
            loadIdentity()
            loadConsent()
        }
    }
    
    private func loadIdentity() {
        MobileSDK.shared.getECID { ecid in
            if let ecid = ecid {
                currentEcid = ecid
            }
        }
    }
    
    private func loadConsent() {
        // Get current consent status
        Consent.getConsents { consents, _ in
            if let consents = consents,
               let collect = consents["consents"] as? [String: Any],
               let collectVal = collect["collect"] as? [String: Any],
               let val = collectVal["val"] as? String {
                consentStatus = val == "y" ? "Opted In" : "Opted Out"
            }
        }
    }
}

struct ConfigView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigView()
    }
}
