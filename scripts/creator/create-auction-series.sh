#!/usr/bin/env bash

# Intended to be used directly by the auction creator.
#
# This is called at the very beginning to initialize all
# auction parameters.
#
# The resulting app ID must be given to bidders and constitutes
# the root of trust (along with auction source code).

set -ex
set -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/.."

APP_CREATED_STR='Created app with app index'

if [ "$1" == "" ]; then
    echo "No seller specified."
    echo "Usage: $0 seller-address"
    false
fi
echo $1 > "${DIR}/seller"

FROM=$(cat "${DIR}/addr")
SELLER=$(cat "${DIR}/seller")
USDC_ID=$(cat "${DIR}/refs/usdc")
SOV_ID=$(cat "${DIR}/refs/sov")
ESUFFIX=$(cat "${DIR}/src/escrow_suffix")

ESCROW_TMPL="${DIR}/src/sovauc_escrow_tmpl.teal"
ESCROW="${DIR}/src/sovauc_escrow.teal"
APPROVE="${DIR}/src/sovauc_approve.teal"
CLEAR="${DIR}/src/sovauc_clear.teal"

ANCHOR=$(jq -r '.anchor' < "${DIR}/parameters.json")
NUM_TRANCHES=$(jq -r '.num_tranches' < "${DIR}/parameters.json")
SUPPLY=$(jq -r '.supply' < "${DIR}/parameters.json")
SUPPLY_PCT_HTHS=$(jq -r '.supply_percent_hths' < "${DIR}/parameters.json")
INIT_TRANCHES_SIZE=$(jq -r '.init_tranches_size' < "${DIR}/parameters.json")
LOOKBACK=$(jq -r '.lookback' < "${DIR}/parameters.json")
MIN_TRANCHE_SIZE=$(jq -r '.min_tranche_size' < "${DIR}/parameters.json")
AUCTION_DURATION=$(jq -r '.auction_duration' < "${DIR}/parameters.json")

APP_ID=$(goal app create --creator ${FROM} --approval-prog ${APPROVE} --clear-prog ${CLEAR} --global-byteslices 3 --global-ints 50 --local-byteslices 0 --local-ints 1 --app-arg addr:${SELLER} --app-arg int:${USDC_ID} --app-arg int:${SOV_ID} --app-arg int:${ANCHOR} --app-arg int:${NUM_TRANCHES} --app-arg int:${SUPPLY} --app-arg int:${SUPPLY_PCT_HTHS} --app-arg int:${INIT_TRANCHES_SIZE} --app-arg int:${LOOKBACK} --app-arg int:${MIN_TRANCHE_SIZE} --app-arg int:${AUCTION_DURATION} --app-arg b64:${ESUFFIX} | grep "$APP_CREATED_STR" | cut -d ' ' -f 6)

APP_IDX=$(printf "0x%016x\n" ${APP_ID})
sed s/TMPL_APPID/${APP_IDX}/g < ${ESCROW_TMPL} > ${ESCROW}

echo "Created auction application with ID $APP_ID"
