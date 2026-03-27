import SwiftUI

@main
struct HaMenakeApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("סריקה") {
                Button("סרוק עכשיו") {
                    appState.startScan()
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(appState.isScanning)
            }

            CommandMenu("בחירה") {
                Button("בחר הכל") {
                    appState.selectAllVisible()
                }
                .keyboardShortcut("a", modifiers: .command)

                Button("נקה בחירה") {
                    appState.deselectAll()
                }
                .keyboardShortcut("d", modifiers: .command)

                Divider()

                Button("העבר לפח") {
                    appState.deleteIsPermanent = false
                    appState.showDeleteConfirmation = true
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(appState.selectedFileIDs.isEmpty)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("כללי", systemImage: "gear")
                }

            LocationsSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("תיקיות", systemImage: "folder")
                }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section {
                Stepper(value: $appState.monthsThreshold, in: 1...24) {
                    HStack {
                        Text("סף גיל קבצים:")
                        Spacer()
                        Text("\(appState.monthsThreshold) חודשים")
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    Text("גודל מינימלי:")
                    Spacer()
                    TextField("0", value: $appState.minimumFileSizeMB, format: .number)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                    Text("MB")
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct LocationsSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("תיקיות לסריקה") {
                ForEach($appState.scanLocations) { $location in
                    Toggle(isOn: $location.isEnabled) {
                        HStack {
                            Image(systemName: location.icon)
                                .frame(width: 24)
                            VStack(alignment: .leading) {
                                Text(location.name)
                                Text(location.path.path)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
