package main

import (
    "fmt"
    "log"
    "net/http"
)

func healthHandler(w http.ResponseWriter, r *http.Request) {
    fmt.Fprintln(w,"OK")
}

func allocateHandler(w http.ResponseWriter, r *http.Request) {
    data := make([][]byte, 1000)

    for i := range data {
        data[i] = make([]byte, 1024)
        data[i][0] = byte(i)
    }

    fmt.Fprintf(w, "Allocated %d buffers\n", len(data))
}

func computeHandler(w http.ResponseWriter, r *http.Request) {
    var result uint64

    for i := uint64(0); i < 100_000_000; i++ {
        result += i * i
    }

    fmt.Fprintf(w, "Result: %d\n", result)
}

func main() {
    http.HandleFunc("/health", healthHandler)
    http.HandleFunc("/compute", computeHandler) 
    http.HandleFunc("/allocate", allocateHandler)

    log.Println("Starting server on :8080")
    log.Fatal(http.ListenAndServe(":8080", nil))
}
