package main

import (
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

type FileInfo struct {
	Path         string `json:"path"`
	Name         string `json:"name"`
	Size         int64  `json:"size"`
	LastAccessed string `json:"lastAccessed"`
	LastModified string `json:"lastModified"`
	DaysSince    int    `json:"daysSince"`
	Category     string `json:"category"`
	ParentFolder string `json:"parentFolder"`
}

func getLocationPath(name string) string {
	var home string
	if runtime.GOOS == "windows" {
		home = os.Getenv("USERPROFILE")
	} else {
		home, _ = os.UserHomeDir()
	}

	switch name {
	case "downloads":
		return filepath.Join(home, "Downloads")
	case "desktop":
		return filepath.Join(home, "Desktop")
	case "documents":
		return filepath.Join(home, "Documents")
	case "pictures":
		return filepath.Join(home, "Pictures")
	case "videos":
		return filepath.Join(home, "Videos")
	case "music":
		return filepath.Join(home, "Music")
	default:
		return ""
	}
}

func scanFiles(locations []string, monthsThreshold int, minSize int64) []FileInfo {
	cutoff := time.Now().AddDate(0, -monthsThreshold, 0)
	var results []FileInfo

	for _, loc := range locations {
		dirPath := getLocationPath(loc)
		if dirPath == "" {
			continue
		}

		if _, err := os.Stat(dirPath); os.IsNotExist(err) {
			continue
		}

		filepath.Walk(dirPath, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return nil
			}

			// Skip directories and hidden files
			if info.IsDir() {
				name := info.Name()
				if strings.HasPrefix(name, ".") || strings.HasPrefix(name, "$") {
					return filepath.SkipDir
				}
				return nil
			}

			if strings.HasPrefix(info.Name(), ".") {
				return nil
			}

			size := info.Size()
			if size < minSize {
				return nil
			}

			modTime := info.ModTime()
			accessTime := getAccessTime(info)
			latestActivity := modTime
			if accessTime.After(modTime) {
				latestActivity = accessTime
			}

			if latestActivity.After(cutoff) {
				return nil
			}

			daysSince := int(time.Since(latestActivity).Hours() / 24)
			ext := strings.TrimPrefix(filepath.Ext(info.Name()), ".")
			category := categorizeFile(ext)
			parentDir := filepath.Base(filepath.Dir(path))

			results = append(results, FileInfo{
				Path:         path,
				Name:         info.Name(),
				Size:         size,
				LastAccessed: accessTime.Format("2006-01-02"),
				LastModified: modTime.Format("2006-01-02"),
				DaysSince:    daysSince,
				Category:     category,
				ParentFolder: parentDir,
			})

			return nil
		})
	}

	return results
}

func categorizeFile(ext string) string {
	ext = strings.ToLower(ext)
	switch ext {
	case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "svg", "webp",
		"heic", "heif", "raw", "cr2", "nef", "ico", "psd", "ai":
		return "images"
	case "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v",
		"mpg", "mpeg", "3gp":
		return "videos"
	case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt",
		"rtf", "pages", "numbers", "key", "csv", "odt", "ods", "odp":
		return "documents"
	case "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "iso",
		"pkg", "msi", "exe":
		return "archives"
	case "mp3", "wav", "aac", "flac", "ogg", "wma", "m4a", "aiff", "opus":
		return "audio"
	case "swift", "py", "js", "ts", "jsx", "tsx", "java", "c", "cpp",
		"h", "hpp", "cs", "rb", "go", "rs", "php", "html", "css",
		"json", "xml", "yaml", "yml", "md", "sh", "sql", "bat", "ps1":
		return "code"
	default:
		return "other"
	}
}
