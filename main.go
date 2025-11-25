package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"
)

var healthFlag = flag.Bool("health", false, "Health check mode")

func main() {
	flag.Parse()

	// Health check mode (for container health checks)
	if *healthFlag {
		resp, err := http.Get("http://localhost:8080/health")
		if err != nil {
			os.Exit(1)
		}
		defer resp.Body.Close()
		if resp.StatusCode == 200 {
			os.Exit(0)
		}
		os.Exit(1)
	}

	// HTTP handlers
	http.HandleFunc("/", handleRoot)
	http.HandleFunc("/health", handleHealth)
	http.HandleFunc("/api/version", handleVersion)

	port := ":8080"
	log.Printf("🚀 Starting Hello World server on %s\n", port)
	log.Printf("📝 Endpoints: GET / | GET /health | GET /api/version\n")
	log.Fatal(http.ListenAndServe(port, nil))
}

func handleRoot(w http.ResponseWriter, r *http.Request) {
	hostname, _ := os.Hostname()
	timestamp := time.Now().Format(time.RFC3339)

	response := fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head>
    <title>Hello World - Tekton Demo</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
        .container { max-width: 600px; margin: 0 auto; background: rgba(0,0,0,0.3); padding: 40px; border-radius: 10px; }
        h1 { color: #ffd700; }
        .info { background: rgba(255,255,255,0.1); padding: 15px; border-radius: 5px; margin: 10px 0; }
        code { background: rgba(0,0,0,0.5); padding: 2px 6px; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>👋 Hello World!</h1>
        <p>Welcome to the Tekton Demo Application</p>
        
        <div class="info">
            <strong>🐳 Container Info:</strong><br>
            Hostname: <code>%s</code><br>
            Timestamp: <code>%s</code><br>
            Version: <code>1.0.0</code>
        </div>
        
        <div class="info">
            <strong>📚 Available Endpoints:</strong><br>
            GET <code>/</code> - This page<br>
            GET <code>/health</code> - Health check<br>
            GET <code>/api/version</code> - JSON version info
        </div>
        
        <p style="margin-top: 30px; font-size: 12px; opacity: 0.8;">
            Built with ❤️ for Tekton Pipeline experiments
        </p>
    </div>
</body>
</html>
`, hostname, timestamp)

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	fmt.Fprint(w, response)
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, `{"status":"healthy","timestamp":"%s"}`, time.Now().Format(time.RFC3339))
}

func handleVersion(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, `{"version":"1.0.0","app":"tekton-demo","timestamp":"%s"}`, time.Now().Format(time.RFC3339))
}
