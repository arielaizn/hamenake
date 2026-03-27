//go:build windows

package main

import (
	"fmt"
	"syscall"
	"unsafe"
)

var (
	shell32              = syscall.NewLazyDLL("shell32.dll")
	procSHFileOperationW = shell32.NewProc("SHFileOperationW")
)

const (
	foDelete          = 0x0003
	fofAllowUndo      = 0x0040
	fofNoConfirmation = 0x0010
	fofSilent         = 0x0004
)

type shFileOpStruct struct {
	Hwnd                  uintptr
	Func                  uint32
	From                  *uint16
	To                    *uint16
	Flags                 uint16
	AnyOperationsAborted  int32
	NameMappings          uintptr
	ProgressTitle         *uint16
}

func moveToRecycleBin(path string) error {
	// SHFileOperation requires double null-terminated string
	pathUTF16, err := syscall.UTF16FromString(path)
	if err != nil {
		return err
	}
	// Add extra null terminator
	pathUTF16 = append(pathUTF16, 0)

	op := shFileOpStruct{
		Func:  foDelete,
		From:  &pathUTF16[0],
		Flags: fofAllowUndo | fofNoConfirmation | fofSilent,
	}

	ret, _, _ := procSHFileOperationW.Call(uintptr(unsafe.Pointer(&op)))
	if ret != 0 {
		return fmt.Errorf("SHFileOperation returned %d", ret)
	}
	return nil
}
