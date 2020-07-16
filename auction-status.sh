#!/usr/bin/env bash

set -e
set -o pipefail

if [ -z "$AUCTION_ROOT" ]
then
    echo '$AUCTION_ROOT has not been set.'
    echo 'Hint: run `export AUCTION_ROOT="$HOME/last-auction"`'
    false
fi

NEXIST_STR="application does not exist"

APP_ID=$(cat "$AUCTION_ROOT/refs/app")

$AUCTION_ROOT/refs/scripts/display-status.sh "${APP_ID}"
