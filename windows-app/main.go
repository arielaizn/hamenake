package main

import (
	"context"
	"embed"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"runtime"
	"os/exec"
	"syscall"
	"time"
)

//go:embed ui/index.html
var indexHTML embed.FS

var appServer *http.Server

func main() {
	mux := http.NewServeMux()

	// Serve UI
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		data, _ := indexHTML.ReadFile("ui/index.html")
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Write(data)
	})

	// API endpoints
	mux.HandleFunc("/api/scan", handleScan)
	mux.HandleFunc("/api/trash", handleTrash)
	mux.HandleFunc("/api/delete", handleDelete)
	mux.HandleFunc("/api/reveal", handleReveal)
	mux.HandleFunc("/api/quit", handleQuit)

	// Find available port
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		log.Fatal("Failed to find available port:", err)
	}
	port := listener.Addr().(*net.TCPAddr).Port
	url := fmt.Sprintf("http://127.0.0.1:%d", port)

	appServer = &http.Server{Handler: mux}

	// Open browser
	go func() {
		time.Sleep(200 * time.Millisecond)
		openBrowser(url)
	}()

	fmt.Printf("המנקה running at %s\n", url)

	// Handle shutdown signals
	go func() {
		sigChan := make(chan os.Signal, 1)
		signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
		<-sigChan
		appServer.Shutdown(context.Background())
	}()

	if err := appServer.Serve(listener); err != http.ErrServerClosed {
		log.Fatal(err)
	}
}

func openBrowser(url string) {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "windows":
		cmd = exec.Command("rundll32", "url.dll,FileProtocolHandler", url)
	case "darwin":
		cmd = exec.Command("open", url)
	default:
		cmd = exec.Command("xdg-open", url)
	}
	cmd.Start()
}

// --- API Handlers ---

type ScanRequest struct {
	Months    int      `json:"months"`
	MinSizeMB float64  `json:"minSizeMB"`
	Locations []string `json:"locations"`
}

type ScanResponse struct {
	Files      []FileInfo `json:"files"`
	TotalSize  int64      `json:"totalSize"`
	TotalCount int        `json:"totalCount"`
}

func handleScan(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", 405)
		return
	}

	var req ScanRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), 400)
		return
	}

	if req.Months <= 0 {
		req.Months = 3
	}
	if len(req.Locations) == 0 {
		req.Locations = []string{"downloads", "desktop", "documents"}
	}

	files := scanFiles(req.Locations, req.Months, int64(req.MinSizeMB*1_000_000))

	var totalSize int64
	for _, f := range files {
		totalSize += f.Size
	}

	resp := ScanResponse{
		Files:      files,
		TotalSize:  totalSize,
		TotalCount: len(files),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

type ActionRequest struct {
	Paths []string `json:"paths"`
}

type ActionResponse struct {
	Deleted int   `json:"deleted"`
	Freed   int64 `json:"freed"`
	Errors  int   `json:"errors"`
}

func handleTrash(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", 405)
		return
	}

	var req ActionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), 400)
		return
	}

	var deleted int
	var freed int64
	var errors int

	for _, path := range req.Paths {
		info, err := os.Stat(path)
		if err != nil {
			errors++
			continue
		}
		size := info.Size()

		if err := moveToRecycleBin(path); err != nil {
			errors++
			continue
		}
		deleted++
		freed += size
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(ActionResponse{Deleted: deleted, Freed: freed, Errors: errors})
}

func handleDelete(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", 405)
		return
	}

	var req ActionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), 400)
		return
	}

	var deleted int
	var freed int64
	var errors int

	for _, path := range req.Paths {
		info, err := os.Stat(path)
		if err != nil {
			errors++
			continue
		}
		size := info.Size()

		if err := os.Remove(path); err != nil {
			errors++
			continue
		}
		deleted++
		freed += size
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(ActionResponse{Deleted: deleted, Freed: freed, Errors: errors})
}

type RevealRequest struct {
	Path string `json:"path"`
}

func handleReveal(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", 405)
		return
	}

	var req RevealRequest
	json.NewDecoder(r.Body).Decode(&req)

	switch runtime.GOOS {
	case "windows":
		exec.Command("explorer", "/select,"+req.Path).Start()
	case "darwin":
		exec.Command("open", "-R", req.Path).Start()
	default:
		exec.Command("xdg-open", req.Path).Start()
	}

	w.WriteHeader(200)
}

func handleQuit(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(200)
	go func() {
		time.Sleep(500 * time.Millisecond)
		appServer.Shutdown(context.Background())
	}()
}
