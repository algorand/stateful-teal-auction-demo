#!/usr/bin/env bash

# Intended to be used directly by the auction creator.
#
# This produces several files in temporary storage.
#
# It expects to be run before a signature of the output file,
# and then it expects open-auction-bcast to be run afterwards.

set -ex
set -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/.."
TEMPDIR="${DIR}/tmp"

if [ "$1" == "" ]; then
    echo "No output transaction filename specified."
    echo "Usage: $0 output-filename"
    false
fi
OUTPUT=$1

rm -r ${TEMPDIR} || true
mkdir ${TEMPDIR} || true

FROM=$(cat "${DIR}/addr")
SELLER=$(cat "${DIR}/seller")
USDC_ID=$(cat "${DIR}/refs/usdc")
SOV_ID=$(cat "${DIR}/refs/sov")
APP_ID=$(cat "${DIR}/refs/app")

ESCROW_SRC="${DIR}/src/sovauc_escrow.teal"

ANCHOR=$(jq -r '.anchor' < "${DIR}/parameters.json")
NUM_TRANCHES=$(jq -r '.num_tranches' < "${DIR}/parameters.json")
SUPPLY=$(jq -r '.supply' < "${DIR}/parameters.json")
SUPPLY_PCT_HTHS=$(jq -r '.supply_percent_hths' < "${DIR}/parameters.json")
INIT_TRANCHES_SIZE=$(jq -r '.init_tranches_size' < "${DIR}/parameters.json")
LOOKBACK=$(jq -r '.lookback' < "${DIR}/parameters.json")
MIN_TRANCHE_SIZE=$(jq -r '.min_tranche_size' < "${DIR}/parameters.json")
AUCTION_DURATION=$(jq -r '.auction_duration' < "${DIR}/parameters.json")

ESCROW=$(goal app read --app-id ${APP_ID} --global --guess-format | jq -r .es.tb)

RECEIPTS_LEFT=$(goal app read --app-id ${APP_ID} --global --guess-format | jq -r '.rc.ui + 0')
if [ 0 -lt $RECEIPTS_LEFT ]; then
    echo "Cannot start a new auction: the previous auction has not closed yet."
    exit 1
fi

# TODO switch correctly depending on tranche number

goal clerk send -o ${TEMPDIR}/openr0.tx -a 100000000 -f ${FROM} -t ${ESCROW}
goal app call   -o ${TEMPDIR}/openr1.tx --app-id ${APP_ID} --from ${FROM} --app-arg int:0
goal asset send -o ${TEMPDIR}/openr2.tx -a 0 --assetid ${USDC_ID} --from ${ESCROW} --to ${ESCROW}
goal asset send -o ${TEMPDIR}/openr3.tx -a 0 --assetid ${SOV_ID} --from ${ESCROW} --to ${ESCROW}
goal asset send -o ${TEMPDIR}/openr4.tx -a ${INIT_TRANCHES_SIZE} --assetid ${SOV_ID} --from ${SELLER} --to ${ESCROW}

cat ${TEMPDIR}/openr*.tx > ${TEMPDIR}/openrc.tx
goal clerk group -i ${TEMPDIR}/openrc.tx -o ${TEMPDIR}/openrg.tx
goal clerk split -i ${TEMPDIR}/openrg.tx -o ${TEMPDIR}/openg.tx

goal clerk sign -i ${TEMPDIR}/openg-0.tx -o ${TEMPDIR}/opens0.stx
goal clerk sign -i ${TEMPDIR}/openg-1.tx -o ${TEMPDIR}/opens1.stx
goal clerk sign -i ${TEMPDIR}/openg-2.tx -o ${TEMPDIR}/opens2.stx -p $ESCROW_SRC
goal clerk sign -i ${TEMPDIR}/openg-3.tx -o ${TEMPDIR}/opens3.stx -p $ESCROW_SRC

cp ${TEMPDIR}/openg-4.tx "${OUTPUT}"
