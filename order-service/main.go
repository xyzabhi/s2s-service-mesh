package main

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"
)

type Order struct {
	ID           string       `json:"id"`
	Status       string       `json:"status"`
	Payment      Payment      `json:"payment"`
	Notification Notification `json:"notification"`
}

type Payment struct {
	ID     string `json:"id"`
	Status string `json:"status"`
	Amount int    `json:"amount"`
}

type Notification struct {
	ID      string `json:"id"`
	Status  string `json:"status"`
	Channel string `json:"channel"`
}

func orderHandler(w http.ResponseWriter, r *http.Request) {

	id := strings.TrimPrefix(r.URL.Path, "/orders/")

	resp, err := http.Get("http://payment-service:4000/payments/" + id)

	if err != nil {
		http.Error(w, "Payment service unavailable", http.StatusBadGateway)
		return
	}

	defer resp.Body.Close()

	var payment Payment

	err = json.NewDecoder(resp.Body).Decode(&payment)

	if err != nil {
		http.Error(w, "Failed to decode payment response", http.StatusInternalServerError)
		return
	}

	notifyResp, err := http.Post("http://notification-service:5000/notifications/"+id, "application/json", nil)

	if err != nil {
		http.Error(w, "Notification service unavailable", http.StatusBadGateway)
		return
	}

	defer notifyResp.Body.Close()

	var notification Notification

	err = json.NewDecoder(notifyResp.Body).Decode(&notification)

	if err != nil {
		http.Error(w, "Failed to decode notification response", http.StatusInternalServerError)
		return
	}

	order := Order{
		ID:           id,
		Status:       "created",
		Payment:      payment,
		Notification: notification,
	}

	w.Header().Set("Content-Type", "application/json")

	json.NewEncoder(w).Encode(order)
}

func main() {

	http.HandleFunc("/orders/", orderHandler)

	log.Println("Order Service running on :3000")

	err := http.ListenAndServe(":3000", nil)

	if err != nil {
		log.Fatal(err)
	}
}
