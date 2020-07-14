#!/usr/bin/env bash

# Functionality used by any bidder.

set -ex
set -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && cd .. >/dev/null 2>&1 && pwd )"
TEMPDIR="${DIR}/tmp"

rm -r ${TEMPDIR} || true
mkdir ${TEMPDIR} || true

if [ "$1" == "" ]; then
    echo "No bid amount specified."
    echo "Usage: $1 bid-amount"
    false
fi
AMOUNT=$1

FROM=$(cat "${DIR}/addr")
USDC_ID=$(cat "${DIR}/refs/usdc")
SOV_ID=$(cat "${DIR}/refs/sov")
APP_ID=$(cat "${DIR}/refs/app")

ESCROW=$(goal app read --app-id ${APP_ID} --global --guess-format | jq -r .es.tb)

# TODO verify auction parameters before entering bids
# TODO this only needs to be done once at the beginning of the auction

# opt into bid and sale tokens
# TODO this only needs to be done once at the beginning of the auction

goal app optin --app-id ${APP_ID} --from $FROM || true
goal asset send -a 0 --assetid ${SOV_ID} --from ${FROM} --to ${FROM}

# enter bid

goal asset send -o ${TEMPDIR}/bidr0.tx -a ${AMOUNT} --assetid ${USDC_ID} -t ${ESCROW} -f ${FROM}
goal app call -o ${TEMPDIR}/bidr1.tx --app-id ${APP_ID} --from ${FROM}
cat ${TEMPDIR}/bid*.tx > ${TEMPDIR}/bidc.tx
goal clerk group -i ${TEMPDIR}/bidc.tx -o ${TEMPDIR}/bidrg.tx
goal clerk split -i ${TEMPDIR}/bidrg.tx -o ${TEMPDIR}/bidg.tx
goal clerk sign -i ${TEMPDIR}/bidg-0.tx -o ${TEMPDIR}/bids0.stx
goal clerk sign -i ${TEMPDIR}/bidg-1.tx -o ${TEMPDIR}/bids1.stx
cat ${TEMPDIR}/bids*.stx > ${TEMPDIR}/bid.stx
goal clerk rawsend -f ${TEMPDIR}/bid.stx
