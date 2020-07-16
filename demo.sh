#!/usr/bin/env bash

set -exm
set -o pipefail

RES=$(./setup-env.sh | grep "Auction environment initialized at")

ROOT_DIR=$(echo "$RES" | cut -d ' ' -f 5)

echo $RES

echo $ROOT_DIR

export AUCTION_ROOT="$ROOT_DIR"

./init-auction-series.sh

APP_ID=$(cat $AUCTION_ROOT/refs/app)

# continually run auctions until we've run all tranches

TRANCHE_INDEX=$(goal app read --app-id ${APP_ID} --global --guess-format | jq '.ti.ui + 0')
NUM_TRANCHES=$(goal app read --app-id ${APP_ID} --global --guess-format | jq .nt.ui)

while [ $TRANCHE_INDEX -lt $NUM_TRANCHES ]; do
    ./open-auction.sh
    ./enter-various-bids.sh
    ./wait-for-auction-close.sh
    ./payout-auction.sh
    TRANCHE_INDEX=$(goal app read --app-id ${APP_ID} --global --guess-format | jq '.ti.ui + 0')
done

ESCROW=$(goal app read --app-id ${APP_ID} --global --guess-format | jq -r .es.tb)

mkdir $AUCTION_ROOT/results
./statfile.sh "${ESCROW}" "$AUCTION_ROOT/results/bids.json" "$AUCTION_ROOT/results/sales.json"

./shutdown-auction-series.sh
