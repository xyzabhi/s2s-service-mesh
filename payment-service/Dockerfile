FROM golang:1.25-alpine AS builder

WORKDIR /app

COPY go.mod ./
COPY payment-service/main.go ./payment-service/

RUN CGO_ENABLED=0 go build -o /payment-service ./payment-service

FROM envoyproxy/envoy:v1.32.3

USER root

COPY payment-service/envoy.yaml /etc/envoy/envoy.yaml
COPY --from=builder /payment-service /usr/local/bin/payment-service
COPY payment-service/start.sh /start.sh

RUN chmod +x /start.sh

ENTRYPOINT ["/start.sh"]
