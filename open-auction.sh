#!/usr/bin/env bash

set -ex
set -o pipefail

if [ -z "$AUCTION_ROOT" ]
then
    echo '$AUCTION_ROOT has not been set.'
    echo 'Hint: run `export AUCTION_ROOT="$HOME/last-auction"`'
    false
fi

# prepare and sign group transactions as administrator
# place intermediate transaction (to be signed by seller)
# in /chan
"${AUCTION_ROOT}/creator/scripts/open-auction-txn.sh" "${AUCTION_ROOT}/chan/open-auction-seller.tx"

# sign transactions as seller
# place signed transaction in /chan
"${AUCTION_ROOT}/seller/scripts/open-auction-sign.sh" "${AUCTION_ROOT}/chan/open-auction-seller.tx" "${AUCTION_ROOT}/chan/open-auction-seller.stx"

# broadcast transactions
"${AUCTION_ROOT}/creator/scripts/open-auction-bcast.sh" "${AUCTION_ROOT}/chan/open-auction-seller.stx"
