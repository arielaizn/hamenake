import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var scannedFiles: [ScannedFile] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var scanStatusText: String = "לחץ על 'סרוק' כדי להתחיל"
    @Published var selectedCategory: FileCategory = .all
    @Published var sortOrder: SortOrder = .sizeDesc
    @Published var searchText: String = ""
    @Published var monthsThreshold: Int = 3
    @Published var minimumFileSizeMB: Double = 0
    @Published var scanLocations: [ScanLocation] = ScanLocation.defaults
    @Published var selectedFileIDs: Set<UUID> = []
    @Published var showDeleteConfirmation = false
    @Published var deleteIsPermanent = false

    // MARK: - Computed Properties

    var filteredFiles: [ScannedFile] {
        var files = scannedFiles

        if selectedCategory != .all {
            files = files.filter { $0.category == selectedCategory }
        }

        if !searchText.isEmpty {
            files = files.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        switch sortOrder {
        case .sizeDesc:
            files.sort { $0.size > $1.size }
        case .sizeAsc:
            files.sort { $0.size < $1.size }
        case .oldestFirst:
            files.sort { $0.lastAccessed < $1.lastAccessed }
        case .newestFirst:
            files.sort { $0.lastAccessed > $1.lastAccessed }
        case .nameAsc:
            files.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        }

        return files
    }

    var totalSelectedSize: Int64 {
        scannedFiles.filter { selectedFileIDs.contains($0.id) }.reduce(0) { $0 + $1.size }
    }

    var totalScannedSize: Int64 {
        scannedFiles.reduce(0) { $0 + $1.size }
    }

    var selectedCount: Int {
        selectedFileIDs.count
    }

    var categoryStats: [(category: FileCategory, count: Int, size: Int64)] {
        var stats: [FileCategory: (count: Int, size: Int64)] = [:]
        for file in scannedFiles {
            let current = stats[file.category] ?? (0, 0)
            stats[file.category] = (current.0 + 1, current.1 + file.size)
        }
        return FileCategory.allCases.compactMap { cat in
            guard cat != .all, let stat = stats[cat] else { return nil }
            return (cat, stat.count, stat.size)
        }.sorted { $0.size > $1.size }
    }

    // MARK: - Actions

    func toggleSelection(_ fileId: UUID) {
        if selectedFileIDs.contains(fileId) {
            selectedFileIDs.remove(fileId)
        } else {
            selectedFileIDs.insert(fileId)
        }
    }

    func selectAllVisible() {
        selectedFileIDs = Set(filteredFiles.map { $0.id })
    }

    func deselectAll() {
        selectedFileIDs.removeAll()
    }

    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        scannedFiles = []
        selectedFileIDs = []
        scanProgress = 0
        scanStatusText = "מתחיל סריקה..."

        let locations = scanLocations
        let months = monthsThreshold
        let minSize = Int64(minimumFileSizeMB * 1_000_000)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let files = FileScanner.scan(
                locations: locations,
                monthsThreshold: months,
                minimumSize: minSize
            ) { progress, status in
                DispatchQueue.main.async {
                    self?.scanProgress = progress
                    self?.scanStatusText = status
                }
            }

            DispatchQueue.main.async {
                self?.scannedFiles = files
                self?.isScanning = false
                let totalSize = ByteCountFormatter.string(fromByteCount: files.reduce(0) { $0 + $1.size }, countStyle: .file)
                self?.scanStatusText = "נמצאו \(files.count) קבצים (\(totalSize))"
            }
        }
    }

    func moveSelectedToTrash() {
        let filesToDelete = scannedFiles.filter { selectedFileIDs.contains($0.id) }
        var deletedCount = 0
        var freedSpace: Int64 = 0

        for file in filesToDelete {
            do {
                try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                deletedCount += 1
                freedSpace += file.size
            } catch {
                print("Failed to trash \(file.name): \(error)")
            }
        }

        scannedFiles.removeAll { selectedFileIDs.contains($0.id) }
        selectedFileIDs.removeAll()
        scanStatusText = "הועברו \(deletedCount) קבצים לפח (\(ByteCountFormatter.string(fromByteCount: freedSpace, countStyle: .file)))"
    }

    func deleteSelectedPermanently() {
        let filesToDelete = scannedFiles.filter { selectedFileIDs.contains($0.id) }
        var deletedCount = 0
        var freedSpace: Int64 = 0

        for file in filesToDelete {
            do {
                try FileManager.default.removeItem(at: file.url)
                deletedCount += 1
                freedSpace += file.size
            } catch {
                print("Failed to delete \(file.name): \(error)")
            }
        }

        scannedFiles.removeAll { selectedFileIDs.contains($0.id) }
        selectedFileIDs.removeAll()
        scanStatusText = "נמחקו \(deletedCount) קבצים לצמיתות (\(ByteCountFormatter.string(fromByteCount: freedSpace, countStyle: .file)))"
    }

    func revealInFinder(_ file: ScannedFile) {
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }
}
