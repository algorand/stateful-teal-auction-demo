#!/usr/bin/env bash

set -exm
set -o pipefail

if [ -z "$AUCTION_ROOT" ]
then
    echo '$AUCTION_ROOT has not been set.'
    echo 'Hint: run `export AUCTION_ROOT="$HOME/last-auction"`'
    false
fi

# 10 000.000 000 = $10K

(
    "${AUCTION_ROOT}/alice/scripts/enter-bid.sh" 10000000000 &
    "${AUCTION_ROOT}/bob/scripts/enter-bid.sh" 20000000000 &
    "${AUCTION_ROOT}/carol/scripts/enter-bid.sh" 30000000000 &
    "${AUCTION_ROOT}/dave/scripts/enter-bid.sh" 15000000000 &
    wait
)
