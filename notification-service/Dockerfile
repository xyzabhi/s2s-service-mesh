FROM golang:1.25-alpine AS builder

WORKDIR /app

COPY go.mod ./
COPY notification-service/main.go ./notification-service/

RUN CGO_ENABLED=0 go build -o /notification-service ./notification-service

FROM alpine:3.20

RUN apk add --no-cache ca-certificates

COPY --from=builder /notification-service /usr/local/bin/notification-service

ENTRYPOINT ["/usr/local/bin/notification-service"]
