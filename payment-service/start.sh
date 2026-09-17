#!/bin/sh
set -e

/usr/local/bin/payment-service &
exec envoy -c /etc/envoy/envoy.yaml --log-level info
