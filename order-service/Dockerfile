FROM golang:1.25-alpine AS builder

WORKDIR /app

COPY go.mod ./
COPY order-service/main.go ./order-service/

RUN CGO_ENABLED=0 go build -o /order-service ./order-service

FROM envoyproxy/envoy:v1.32.3

USER root

COPY order-service/envoy.yaml /etc/envoy/envoy.yaml
COPY --from=builder /order-service /usr/local/bin/order-service
COPY order-service/start.sh /start.sh

RUN chmod +x /start.sh

ENTRYPOINT ["/start.sh"]
