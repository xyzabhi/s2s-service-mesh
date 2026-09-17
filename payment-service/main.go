package main

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"
)

type Payment struct {
	ID     string `json:"id"`
	Status string `json:"status"`
	Amount int    `json:"amount"`
}

func paymentHandler(w http.ResponseWriter, r *http.Request) {

	id := strings.TrimPrefix(r.URL.Path, "/payments/")

	payment := Payment{
		ID:     id,
		Status: "success",
		Amount: 100,
	}

	w.Header().Set("Content-Type", "application/json")

	json.NewEncoder(w).Encode(payment)
}

func main() {

	http.HandleFunc("/payments/", paymentHandler)

	log.Println("Payment Service running on :3002")

	err := http.ListenAndServe(":3002", nil)
	if err != nil {
		log.Fatal(err)
	}
}
