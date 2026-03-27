//go:build windows

package main

import (
	"os"
	"syscall"
	"time"
)

func getAccessTime(info os.FileInfo) time.Time {
	if sys := info.Sys(); sys != nil {
		if stat, ok := sys.(*syscall.Win32FileAttributeData); ok {
			return time.Unix(0, stat.LastAccessTime.Nanoseconds())
		}
	}
	return info.ModTime()
}
