package main

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"
)

type Notification struct {
	ID      string `json:"id"`
	Status  string `json:"status"`
	Channel string `json:"channel"`
}

func notificationHandler(w http.ResponseWriter, r *http.Request) {

	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	id := strings.TrimPrefix(r.URL.Path, "/notifications/")

	notification := Notification{
		ID:      id,
		Status:  "sent",
		Channel: "email",
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusAccepted)

	json.NewEncoder(w).Encode(notification)
}

func main() {

	http.HandleFunc("/notifications/", notificationHandler)

	log.Println("Notification Service running on :5000")

	err := http.ListenAndServe(":5000", nil)
	if err != nil {
		log.Fatal(err)
	}
}
