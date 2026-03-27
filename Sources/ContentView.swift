import SwiftUI
import AppKit

// MARK: - Main Content View

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        } detail: {
            VStack(spacing: 0) {
                if appState.isScanning {
                    ScanProgressView()
                } else if appState.scannedFiles.isEmpty {
                    WelcomeView()
                } else {
                    FileListView()
                }

                BottomBarView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 600)
        .alert("אישור מחיקה", isPresented: $appState.showDeleteConfirmation) {
            Button("ביטול", role: .cancel) {}
            Button(appState.deleteIsPermanent ? "מחק לצמיתות" : "העבר לפח", role: .destructive) {
                if appState.deleteIsPermanent {
                    appState.deleteSelectedPermanently()
                } else {
                    appState.moveSelectedToTrash()
                }
            }
        } message: {
            let count = appState.selectedCount
            let size = ByteCountFormatter.string(fromByteCount: appState.totalSelectedSize, countStyle: .file)
            if appState.deleteIsPermanent {
                Text("האם למחוק \(count) קבצים (\(size)) לצמיתות? פעולה זו בלתי הפיכה.")
            } else {
                Text("האם להעביר \(count) קבצים (\(size)) לפח?")
            }
        }
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundStyle(.blue.gradient)

            Text("המנקה")
                .font(.system(size: 36, weight: .bold, design: .rounded))

            Text("מנקה קבצים חכם למק")
                .font(.title3)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "magnifyingglass", text: "סורק תיקיות ומוצא קבצים ישנים")
                FeatureRow(icon: "chart.bar.fill", text: "מציג גודל וקטגוריה לכל קובץ")
                FeatureRow(icon: "trash.fill", text: "מאפשר מחיקה בטוחה לפח")
            }
            .padding(.top, 10)

            Button(action: { appState.startScan() }) {
                Label("התחל סריקה", systemImage: "magnifyingglass")
                    .font(.title3)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Scan Progress View

struct ScanProgressView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            ProgressView(value: appState.scanProgress)
                .progressViewStyle(.linear)
                .frame(width: 300)

            Text(appState.scanStatusText)
                .font(.headline)
                .foregroundColor(.secondary)

            if !appState.scannedFiles.isEmpty {
                Text("נמצאו \(appState.scannedFiles.count) קבצים עד כה...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // App Header
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue.gradient)
                Text("המנקה")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .padding(.vertical, 16)

            Divider()

            // Scan Button
            Button(action: { appState.startScan() }) {
                Label(appState.isScanning ? "סורק..." : "סרוק עכשיו", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(appState.isScanning)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)

            // Months Threshold
            VStack(alignment: .leading, spacing: 4) {
                Text("קבצים ישנים מ-\(appState.monthsThreshold) חודשים")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Stepper(value: $appState.monthsThreshold, in: 1...24) {
                    Text("\(appState.monthsThreshold) חודשים")
                        .font(.caption.bold())
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            // Categories
            List(selection: $appState.selectedCategory) {
                Section("קטגוריות") {
                    CategoryRow(category: .all, count: appState.scannedFiles.count,
                               size: appState.totalScannedSize)
                        .tag(FileCategory.all)

                    ForEach(appState.categoryStats, id: \.category) { stat in
                        CategoryRow(category: stat.category, count: stat.count, size: stat.size)
                            .tag(stat.category)
                    }
                }

                Section("תיקיות לסריקה") {
                    ForEach($appState.scanLocations) { $location in
                        Toggle(isOn: $location.isEnabled) {
                            Label(location.name, systemImage: location.icon)
                                .font(.callout)
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Disk Space Summary
            if !appState.scannedFiles.isEmpty {
                VStack(spacing: 4) {
                    Text("ניתן לפנות:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: appState.totalScannedSize, countStyle: .file))
                        .font(.title2.bold())
                        .foregroundColor(.orange)
                }
                .padding(.vertical, 12)
            }
        }
    }
}

struct CategoryRow: View {
    let category: FileCategory
    let count: Int
    let size: Int64

    var body: some View {
        HStack {
            Label(category.rawValue, systemImage: category.icon)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(count)")
                    .font(.caption.bold())
                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - File List View

struct FileListView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("חיפוש קבצים...", text: $appState.searchText)
                        .textFieldStyle(.plain)
                    if !appState.searchText.isEmpty {
                        Button(action: { appState.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .frame(maxWidth: 300)

                Spacer()

                // Sort
                Menu {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Button(action: { appState.sortOrder = order }) {
                            HStack {
                                Text(order.rawValue)
                                if appState.sortOrder == order {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label("מיון", systemImage: "arrow.up.arrow.down")
                }

                // Select all / deselect
                Button(action: { appState.selectAllVisible() }) {
                    Label("בחר הכל", systemImage: "checkmark.circle")
                }
                Button(action: { appState.deselectAll() }) {
                    Label("נקה בחירה", systemImage: "xmark.circle")
                }
                .disabled(appState.selectedFileIDs.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Table Header
            HStack(spacing: 0) {
                Toggle("", isOn: Binding(
                    get: { !appState.selectedFileIDs.isEmpty && appState.selectedFileIDs.count == appState.filteredFiles.count },
                    set: { isOn in
                        if isOn { appState.selectAllVisible() } else { appState.deselectAll() }
                    }
                ))
                .toggleStyle(.checkbox)
                .frame(width: 40)

                Text("שם קובץ")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("קטגוריה")
                    .frame(width: 90, alignment: .center)
                Text("גודל")
                    .frame(width: 90, alignment: .trailing)
                Text("לא נגעו")
                    .frame(width: 100, alignment: .trailing)
                Spacer().frame(width: 40)
            }
            .font(.caption.bold())
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            Divider()

            // File List
            if appState.filteredFiles.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("לא נמצאו קבצים בקטגוריה זו")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(appState.filteredFiles) { file in
                            FileRowView(file: file)
                            Divider().padding(.leading, 56)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - File Row View

struct FileRowView: View {
    @EnvironmentObject var appState: AppState
    let file: ScannedFile

    var isSelected: Bool {
        appState.selectedFileIDs.contains(file.id)
    }

    var body: some View {
        HStack(spacing: 0) {
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { _ in appState.toggleSelection(file.id) }
            ))
            .toggleStyle(.checkbox)
            .frame(width: 40)

            // File icon + name
            HStack(spacing: 10) {
                Image(systemName: file.category.icon)
                    .foregroundColor(iconColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(file.parentFolder)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(file.category.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(categoryColor.opacity(0.15))
                .cornerRadius(4)
                .frame(width: 90, alignment: .center)

            Text(file.formattedSize)
                .font(.callout.monospacedDigit())
                .foregroundColor(sizeColor)
                .frame(width: 90, alignment: .trailing)

            Text(file.daysSinceAccessText)
                .font(.callout)
                .foregroundColor(.orange)
                .frame(width: 100, alignment: .trailing)

            // Reveal in Finder button
            Button(action: { appState.revealInFinder(file) }) {
                Image(systemName: "folder")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 40)
            .help("הצג ב-Finder")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            appState.toggleSelection(file.id)
        }
    }

    var iconColor: Color {
        switch file.category {
        case .images: return .pink
        case .videos: return .purple
        case .documents: return .blue
        case .archives: return .orange
        case .audio: return .green
        case .code: return .cyan
        default: return .gray
        }
    }

    var categoryColor: Color { iconColor }

    var sizeColor: Color {
        if file.size > 500_000_000 { return .red }
        if file.size > 100_000_000 { return .orange }
        if file.size > 10_000_000 { return .yellow }
        return .primary
    }
}

// MARK: - Bottom Bar View

struct BottomBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 16) {
            // Status
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
            Text(appState.scanStatusText)
                .font(.callout)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Spacer()

            if appState.selectedCount > 0 {
                // Selection Info
                Text("נבחרו \(appState.selectedCount) קבצים (\(ByteCountFormatter.string(fromByteCount: appState.totalSelectedSize, countStyle: .file)))")
                    .font(.callout.bold())
                    .foregroundColor(.blue)

                // Trash Button
                Button(action: {
                    appState.deleteIsPermanent = false
                    appState.showDeleteConfirmation = true
                }) {
                    Label("העבר לפח", systemImage: "trash")
                }
                .buttonStyle(.bordered)

                // Permanent Delete Button
                Button(action: {
                    appState.deleteIsPermanent = true
                    appState.showDeleteConfirmation = true
                }) {
                    Label("מחק לצמיתות", systemImage: "trash.slash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) { Divider() }
    }
}
