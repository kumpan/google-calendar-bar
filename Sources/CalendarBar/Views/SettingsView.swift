import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var updater: Updater
    @AppStorage(Guardian.enabledKey) private var guardianOn = true
    @AppStorage(Guardian.leadKey) private var leadMinutes = 1
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                IconButton(systemName: "chevron.left", help: "Back") { state.mode = .main }
                Text("Settings").font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 4)

            Form {
                Section {
                    LabeledContent("Version") {
                        HStack {
                            Text(updater.currentVersion).foregroundStyle(.secondary)
                            Button("Check for Updates") { Task { await updater.check() } }
                                .disabled(updater.isWorking)
                        }
                    }
                    if let release = updater.available {
                        LabeledContent("Version \(release.version) is available") {
                            Button("Install and Relaunch") { Task { await updater.install() } }
                                .buttonStyle(.borderedProminent)
                                .disabled(updater.isWorking)
                        }
                    }
                } header: {
                    Text("Updates")
                } footer: {
                    if let status = updater.status { Text(status).foregroundStyle(.secondary) }
                }

                Section {
                    Toggle("Alert before meetings", isOn: $guardianOn)
                    Picker("When", selection: $leadMinutes) {
                        Text("When it starts").tag(0)
                        ForEach([1, 2, 5], id: \.self) { Text("\($0) min before").tag($0) }
                    }
                    .disabled(!guardianOn)
                    LabeledContent("See what it looks like") {
                        Button("Preview") { Guardian.shared.preview() }
                    }
                } header: {
                    Text("Meeting Guardian")
                } footer: {
                    Text("For meetings with a video link or other guests.").foregroundStyle(.secondary)
                }

                Section {
                    ForEach(state.accounts, id: \.self) { account in
                        LabeledContent(account) {
                            Button("Remove", role: .destructive) { Task { await state.remove(account) } }
                        }
                    }
                    Button("Add Account…") { Task { await state.addAccount() } }
                } header: {
                    Text("Google accounts")
                } footer: {
                    Text("Shows the calendars ticked in each account's Google Calendar sidebar.").foregroundStyle(.secondary)
                }

                Section {
                    Toggle("Open at login", isOn: $openAtLogin)
                        .onChange(of: openAtLogin) { _, on in
                            try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                            openAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    Button("Quit CalendarBar", role: .destructive) { NSApp.terminate(nil) }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .frame(height: 480)
            ErrorBanner()
        }
    }
}
