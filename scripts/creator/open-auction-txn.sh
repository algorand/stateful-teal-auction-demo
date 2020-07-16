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

# note that these parameters are somewhat duplicate with those stored in global state
ANCHOR=$(jq -r '.anchor' < "${DIR}/parameters.json")
NUM_TRANCHES=$(jq -r '.num_tranches' < "${DIR}/parameters.json")
# NUM_TRANCHES=$(goal app read --app-id ${APP_ID} --global --guess-format | jq -r .nt.ui)
SUPPLY=$(jq -r '.supply' < "${DIR}/parameters.json")
# SUPPLY=$(goal app read --app-id ${APP_ID} --global --guess-format | jq -r .sp.ui)
# SUPPLY_PCT_HTHS=$(jq -r '.supply_percent_hths' < "${DIR}/parameters.json")
INIT_TRANCHES_SIZE=$(jq -r '.init_tranches_size' < "${DIR}/parameters.json")
LOOKBACK=$(jq -r '.lookback' < "${DIR}/parameters.json")
MIN_TRANCHE_SIZE=$(jq -r '.min_tranche_size' < "${DIR}/parameters.json")
AUCTION_DURATION=$(jq -r '.auction_duration' < "${DIR}/parameters.json")

TRANCHE_INDEX=$(goal app read --app-id ${APP_ID} --global --guess-format | jq '.ti.ui + 0')
ESCROW=$(goal app read --app-id ${APP_ID} --global --guess-format | jq -r .es.tb)

DEADLINE=$(goal app read --app-id ${APP_ID} --global --guess-format | jq -r '.ad.ui + 0')
if [ $DEADLINE -ne 0 ]; then
    echo "Cannot start a new auction: the previous auction has not closed yet."
    exit 1
fi

# compute the tranche size according to the auction formula

TRANCHE_SIZE=$INIT_TRANCHES_SIZE
REM=0

if [ $LOOKBACK -le $TRANCHE_INDEX ]; then
    RAISED_SUM=$(goal app read --app-id ${APP_ID} --global --guess-format | jq -r '.u_.ui + 0')
    TRANCHE_SUM=$(goal app read --app-id ${APP_ID} --global --guess-format | jq -r '.t_.ui + 0')
    SUPPLY_SCALE=$(goal app read --app-id ${APP_ID} --global --guess-format | jq -r .rs.ui)

    LIM=$(echo "(${SUPPLY} * ${SUPPLY_SCALE})" | bc)
    if [ $LIM -le $TRANCHE_SUM ] || [ 0 -eq $RAISED_SUM ]; then
	TRANCHE_SIZE=$MIN_TRANCHE_SIZE
    else
	FACTOR1=$(echo "2 * ${RAISED_SUM}" | bc)
	FACTOR2=$(echo "(${SUPPLY} * ${SUPPLY_SCALE}) - ${TRANCHE_SUM}" | bc)
	DIVISOR=$(echo "(${LOOKBACK} * ${ANCHOR} * ${SUPPLY_SCALE}) + (${NUM_TRANCHES} * ${RAISED_SUM})" | bc)
	TRANCHE_SIZE=$(echo "(${FACTOR1} * ${FACTOR2}) / ${DIVISOR}" | bc)
	REM=$(echo "(${FACTOR1} * ${FACTOR2}) % ${DIVISOR}" | bc)
    fi
fi

# create all transactions other than the transaction
# where the seller funds the escrow
#
# the transactions (in group order) are:
# 1. administrator -> escrow, to pay fees
# 2. anyone (administrator here), to start the auction at $APP_ID
# 3. escrow -> escrow: 0 bid assets, to opt in
# 4. escrow -> escrow: 0 sale assets, to opt in
# 5. seller -> escrow: X sale assets, to fund the auction
#    (where X is determined by the auction formula)

goal clerk send -o ${TEMPDIR}/openr0.tx -a 100000000 -f ${FROM} -t ${ESCROW}
goal app call   -o ${TEMPDIR}/openr1.tx --app-id ${APP_ID} --from ${FROM} --app-arg int:${REM}
goal asset send -o ${TEMPDIR}/openr2.tx -a 0 --assetid ${USDC_ID} --from ${ESCROW} --to ${ESCROW}
goal asset send -o ${TEMPDIR}/openr3.tx -a 0 --assetid ${SOV_ID} --from ${ESCROW} --to ${ESCROW}
goal asset send -o ${TEMPDIR}/openr4.tx -a ${TRANCHE_SIZE} --assetid ${SOV_ID} --from ${SELLER} --to ${ESCROW}

cat ${TEMPDIR}/openr*.tx > ${TEMPDIR}/openrc.tx
goal clerk group -i ${TEMPDIR}/openrc.tx -o ${TEMPDIR}/openrg.tx
goal clerk split -i ${TEMPDIR}/openrg.tx -o ${TEMPDIR}/openg.tx

goal clerk sign -i ${TEMPDIR}/openg-0.tx -o ${TEMPDIR}/opens0.stx
goal clerk sign -i ${TEMPDIR}/openg-1.tx -o ${TEMPDIR}/opens1.stx
goal clerk sign -i ${TEMPDIR}/openg-2.tx -o ${TEMPDIR}/opens2.stx -p $ESCROW_SRC
goal clerk sign -i ${TEMPDIR}/openg-3.tx -o ${TEMPDIR}/opens3.stx -p $ESCROW_SRC

cp ${TEMPDIR}/openg-4.tx "${OUTPUT}"
