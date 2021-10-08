package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
)

var port int

func init() {
	flag.IntVar(&port, "port", 8080, "port for this server")
	flag.Parse()
}

func handler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "Hello to %q from port %d\n", r.RemoteAddr, port)
}

func main() {
	http.HandleFunc("/", handler)
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%d", port), nil))
}
