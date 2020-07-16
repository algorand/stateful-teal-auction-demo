#!/usr/bin/env bash

# Usable by anyone.
#
# The auction creator usually calls this when an auction is over.
# If the auction creator goes down, users can call on their own
# account to cash out their bids.
#
# IMPORTANT: If a user does not opt into the sale asset, the 
# contract is unable to do this for him and must destroy his bid
# receipts instead to ensure auction progress. Users are
# responsible for ensuring that they are opted into the sale
# asset before the auction concludes.
#
# enter-bid.sh will opt into sale assets for users, so users
# which have called that script and nothing else do not need to
# worry about this.

set -ex
set -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && cd .. >/dev/null 2>&1 && pwd )"

USDC_ID=$(cat "${DIR}/usdc")
SOV_ID=$(cat "${DIR}/sov")
APP_ID=$(cat "${DIR}/app")

ERR_APP_OI_STR1='has not opted in to application'

if [ "$1" == "" ]; then
    echo "No sender specified."
    echo "Usage: $0 sender discharge-acct escrow-source"
    false
fi
FROM=$1

if [ "$2" == "" ]; then
    echo "No discharge account specified."
    echo "Usage: $0 sender discharge-acct escrow-source"
    false
fi
TARGET=$2

if [ "$3" == "" ]; then
    echo "No escrow source program specified."
    echo "Usage: $0 sender discharge-acct escrow-source"
    false
fi
ESCROW_SRC=$3

# used in case this is called concurrently with the same address
OFFSET=$(( (RANDOM) ))

TEMPDIR="${DIR}/tmp/${OFFSET}/${TARGET}"

rm -r ${TEMPDIR} || true
mkdir -p ${TEMPDIR} || true

RES=$(goal app read --app-id ${APP_ID} --local -f ${TARGET} --guess-format 2>&1 || true)
if [[ $RES == *"$ERR_APP_OI_STR1"* ]]; then
    # state changed in the meantime
    exit 0
fi
RECEIPTS=$(echo "$RES" | jq -r .br.ui)

ESCROW=$(goal app read --app-id ${APP_ID} --global --guess-format | jq -r .es.tb)
TRANCHE_SIZE=$(goal app read --app-id ${APP_ID} --global --guess-format | jq -r .as.ui) 
AUCTION_RAISED=$(goal app read --app-id ${APP_ID} --global --guess-format | jq -r .ar.ui)

# payout case
# TODO this check is probably unnecessary
if [ 0 -lt $AUCTION_RAISED ]; then
    PAY=$(echo "${TRANCHE_SIZE} * ${RECEIPTS} / ${AUCTION_RAISED}" | bc)
    MOD=$(echo "${TRANCHE_SIZE} * ${RECEIPTS} % ${AUCTION_RAISED}" | bc)

    goal clerk send -o ${TEMPDIR}/payr0.tx -a 1000 --from ${FROM} --to ${ESCROW}
    goal app call -o ${TEMPDIR}/payr1.tx --from ${FROM} --app-id ${APP_ID} --app-account ${TARGET} --app-arg int:${MOD}
    goal asset send -o ${TEMPDIR}/payr2.tx --assetid ${SOV_ID} -a ${PAY} --from ${ESCROW} --to ${TARGET}
    cat ${TEMPDIR}/payr*.tx > ${TEMPDIR}/payc.tx
    goal clerk group -i ${TEMPDIR}/payc.tx -o ${TEMPDIR}/payrg.tx
    goal clerk split -i ${TEMPDIR}/payrg.tx -o ${TEMPDIR}/payg.tx
    goal clerk sign -i ${TEMPDIR}/payg-0.tx -o ${TEMPDIR}/pays0.stx
    goal clerk sign -i ${TEMPDIR}/payg-1.tx -o ${TEMPDIR}/pays1.stx
    goal clerk sign -i ${TEMPDIR}/payg-2.tx -o ${TEMPDIR}/pays2.stx -p ${ESCROW_SRC}
    cat ${TEMPDIR}/pays*.stx > ${TEMPDIR}/pay.stx
    goal clerk rawsend -f ${TEMPDIR}/pay.stx || true
fi

# destroy case
goal app call --from ${FROM} --app-id ${APP_ID} --app-account ${TARGET} || true
