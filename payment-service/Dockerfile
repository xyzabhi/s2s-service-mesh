FROM golang:1.25-alpine AS builder

WORKDIR /app

COPY go.mod ./
COPY payment-service/main.go ./payment-service/

RUN CGO_ENABLED=0 go build -o /payment-service ./payment-service

FROM alpine:3.20

RUN apk add --no-cache ca-certificates

COPY --from=builder /payment-service /usr/local/bin/payment-service

ENTRYPOINT ["/usr/local/bin/payment-service"]
