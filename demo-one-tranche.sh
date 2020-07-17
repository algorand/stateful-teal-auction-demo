#!/usr/bin/env bash

set -exm
set -o pipefail

./open-auction.sh
./enter-various-bids.sh
./wait-for-auction-close.sh
./payout-auction.sh
