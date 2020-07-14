#!/usr/bin/env bash

set -ex
set -o pipefail

if [ -z "$AUCTION_ROOT" ]
then
    echo '$AUCTION_ROOT has not been set.'
    echo 'Hint: run `export AUCTION_ROOT="$HOME/last-auction"`'
    false
fi

# TODO close previous auction if not done yet

# prepare and sign group transactions as administrator
"${AUCTION_ROOT}/creator/refs/scripts/wait-for-auction-close.sh"
