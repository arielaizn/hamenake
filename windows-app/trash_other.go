//go:build !windows

package main

import "fmt"

func moveToRecycleBin(path string) error {
	return fmt.Errorf("recycle bin is only supported on Windows, use permanent delete instead")
}
