import Foundation

struct FileScanner {

    static func scan(
        locations: [ScanLocation],
        monthsThreshold: Int,
        minimumSize: Int64,
        progress: @escaping (Double, String) -> Void
    ) -> [ScannedFile] {
        let enabledLocations = locations.filter { $0.isEnabled }
        guard !enabledLocations.isEmpty else {
            progress(1.0, "אין תיקיות לסריקה")
            return []
        }

        let cutoffDate = Calendar.current.date(byAdding: .month, value: -monthsThreshold, to: Date()) ?? Date()
        let fm = FileManager.default
        var allFiles: [ScannedFile] = []

        let resourceKeys: Set<URLResourceKey> = [
            .fileSizeKey,
            .contentAccessDateKey,
            .contentModificationDateKey,
            .isRegularFileKey,
            .isDirectoryKey
        ]

        for (index, location) in enabledLocations.enumerated() {
            let baseProgress = Double(index) / Double(enabledLocations.count)
            let stepSize = 1.0 / Double(enabledLocations.count)
            progress(baseProgress, "סורק: \(location.name)...")

            guard fm.fileExists(atPath: location.path.path) else {
                progress(baseProgress + stepSize, "התיקייה \(location.name) לא נמצאה, מדלג...")
                continue
            }

            guard let enumerator = fm.enumerator(
                at: location.path,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }

            var locationFileCount = 0

            while let url = enumerator.nextObject() as? URL {
                do {
                    let resourceValues = try url.resourceValues(forKeys: resourceKeys)

                    guard resourceValues.isRegularFile == true else { continue }

                    let size = Int64(resourceValues.fileSize ?? 0)
                    guard size >= minimumSize else { continue }

                    let accessDate = resourceValues.contentAccessDate ?? Date.distantPast
                    let modDate = resourceValues.contentModificationDate ?? Date.distantPast
                    let latestActivity = max(accessDate, modDate)

                    guard latestActivity < cutoffDate else { continue }

                    let ext = url.pathExtension
                    let category = FileCategory.categorize(fileExtension: ext)

                    let parentDir = url.deletingLastPathComponent().lastPathComponent

                    let file = ScannedFile(
                        url: url,
                        name: url.lastPathComponent,
                        size: size,
                        lastAccessed: accessDate,
                        lastModified: modDate,
                        category: category,
                        parentFolder: parentDir
                    )
                    allFiles.append(file)
                    locationFileCount += 1

                    if locationFileCount % 100 == 0 {
                        progress(baseProgress + stepSize * 0.5, "סורק: \(location.name)... (\(locationFileCount) קבצים)")
                    }
                } catch {
                    continue
                }
            }

            progress(baseProgress + stepSize, "\(location.name): \(locationFileCount) קבצים ישנים")
        }

        allFiles.sort { $0.size > $1.size }
        progress(1.0, "הסריקה הושלמה - נמצאו \(allFiles.count) קבצים")
        return allFiles
    }
}
