//go:build !windows

package main

import (
	"os"
	"time"
)

func getAccessTime(info os.FileInfo) time.Time {
	// On non-Windows, fall back to modification time
	return info.ModTime()
}
