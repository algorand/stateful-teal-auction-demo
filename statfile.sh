#!/usr/bin/env bash

set -e
set -o pipefail

APP_ID=$(cat "$AUCTION_ROOT/refs/app")
USDC_ID=$(cat "$AUCTION_ROOT/refs/usdc")
SOV_ID=$(cat "$AUCTION_ROOT/refs/sov")

if [ "$1" == "" ]; then
    echo "No escrow account specified."
    echo "Usage: $0 escrow-addr bidfile sellfile"
    false
fi
ESCROW=$1

if [ "$2" == "" ]; then
    echo "No escrow account specified."
    echo "Usage: $0 escrow-addr bidfile sellfile"
    false
fi
BIDFILE=$2

if [ "$3" == "" ]; then
    echo "No escrow account specified."
    echo "Usage: $0 escrow-addr bidfile sellfile"
    false
fi
SELLFILE=$3

curl "localhost:8980/v2/transactions?address=${ESCROW}&asset-id=${USDC_ID}" > ${BIDFILE}
curl "localhost:8980/v2/transactions?address=${ESCROW}&asset-id=${SOV_ID}" > ${SELLFILE}

