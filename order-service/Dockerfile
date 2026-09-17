FROM golang:1.25-alpine AS builder

WORKDIR /app

COPY go.mod ./
COPY order-service/main.go ./order-service/

RUN CGO_ENABLED=0 go build -o /order-service ./order-service

FROM alpine:3.20

RUN apk add --no-cache ca-certificates

COPY --from=builder /order-service /usr/local/bin/order-service

ENTRYPOINT ["/usr/local/bin/order-service"]
