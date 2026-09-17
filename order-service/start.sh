#!/bin/sh
set -e

envoy -c /etc/envoy/envoy.yaml --log-level info &
exec /usr/local/bin/order-service
