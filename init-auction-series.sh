#!/usr/bin/env bash

set -ex
set -o pipefail

if [ -z "$AUCTION_ROOT" ]
then
    echo '$AUCTION_ROOT has not been set.'
    echo 'Hint: run `export AUCTION_ROOT="$HOME/last-auction"`'
    false
fi

echo "Initializing auction application using parameters at $AUCTION_ROOT/parameters.json."

APP_ID=$("$AUCTION_ROOT/creator/scripts/create-auction-series.sh" $(cat "$AUCTION_ROOT/seller/addr") | tail -n 1 | cut -d ' ' -f 6)

echo "Creation script returned app ID ${APP_ID}."

echo "${APP_ID}" > "$AUCTION_ROOT/refs/app"
