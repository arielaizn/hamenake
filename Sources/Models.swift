import Foundation

// MARK: - File Category

enum FileCategory: String, CaseIterable, Identifiable {
    case all = "הכל"
    case images = "תמונות"
    case videos = "סרטונים"
    case documents = "מסמכים"
    case archives = "ארכיונים"
    case audio = "מוזיקה"
    case code = "קוד"
    case other = "אחר"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "folder.fill"
        case .images: return "photo.fill"
        case .videos: return "film.fill"
        case .documents: return "doc.fill"
        case .archives: return "archivebox.fill"
        case .audio: return "music.note"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .other: return "questionmark.folder.fill"
        }
    }

    static func categorize(fileExtension ext: String) -> FileCategory {
        switch ext.lowercased() {
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "svg", "webp",
             "heic", "heif", "raw", "cr2", "nef", "ico", "psd", "ai":
            return .images
        case "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v",
             "mpg", "mpeg", "3gp":
            return .videos
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt",
             "rtf", "pages", "numbers", "key", "csv", "odt", "ods", "odp":
            return .documents
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "iso",
             "pkg", "deb", "sit":
            return .archives
        case "mp3", "wav", "aac", "flac", "ogg", "wma", "m4a", "aiff", "opus":
            return .audio
        case "swift", "py", "js", "ts", "jsx", "tsx", "java", "c", "cpp",
             "h", "hpp", "cs", "rb", "go", "rs", "php", "html", "css",
             "json", "xml", "yaml", "yml", "md", "sh", "sql":
            return .code
        default:
            return .other
        }
    }
}

// MARK: - Scanned File

struct ScannedFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let lastAccessed: Date
    let lastModified: Date
    let category: FileCategory
    let parentFolder: String

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var daysSinceAccess: Int {
        Calendar.current.dateComponents([.day], from: lastAccessed, to: Date()).day ?? 0
    }

    var daysSinceAccessText: String {
        let days = daysSinceAccess
        if days < 30 {
            return "\(days) ימים"
        } else if days < 365 {
            let months = days / 30
            return "\(months) חודשים"
        } else {
            let years = days / 365
            return "\(years) שנים"
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ScannedFile, rhs: ScannedFile) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Scan Location

struct ScanLocation: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: URL
    var isEnabled: Bool

    var icon: String {
        switch name {
        case "הורדות": return "arrow.down.circle.fill"
        case "שולחן עבודה": return "desktopcomputer"
        case "מסמכים": return "doc.text.fill"
        case "תמונות": return "photo.on.rectangle.fill"
        case "סרטונים": return "film.fill"
        case "מוזיקה": return "music.note.list"
        default: return "folder.fill"
        }
    }

    static var defaults: [ScanLocation] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            ScanLocation(name: "הורדות", path: home.appendingPathComponent("Downloads"), isEnabled: true),
            ScanLocation(name: "שולחן עבודה", path: home.appendingPathComponent("Desktop"), isEnabled: true),
            ScanLocation(name: "מסמכים", path: home.appendingPathComponent("Documents"), isEnabled: true),
            ScanLocation(name: "תמונות", path: home.appendingPathComponent("Pictures"), isEnabled: false),
            ScanLocation(name: "סרטונים", path: home.appendingPathComponent("Movies"), isEnabled: false),
            ScanLocation(name: "מוזיקה", path: home.appendingPathComponent("Music"), isEnabled: false),
        ]
    }
}

// MARK: - Sort Order

enum SortOrder: String, CaseIterable {
    case sizeDesc = "גודל (גדול לקטן)"
    case sizeAsc = "גודל (קטן לגדול)"
    case oldestFirst = "הכי ישן קודם"
    case newestFirst = "הכי חדש קודם"
    case nameAsc = "שם (א-ת)"
}
