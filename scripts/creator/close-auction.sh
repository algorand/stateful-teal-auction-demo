#!/usr/bin/env bash

# Intended to be used directly by the auction creator.

set -ex
set -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/.."
TEMPDIR="${DIR}/tmp"

FROM=$(cat "${DIR}/addr")
SELLER=$(cat "${DIR}/seller")
USDC_ID=$(cat "${DIR}/refs/usdc")
SOV_ID=$(cat "${DIR}/refs/sov")
APP_ID=$(cat "${DIR}/refs/app")

ESCROW_SRC="${DIR}/src/sovauc_escrow.teal"

ZERO_ADDRESS=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAY5HFKQ

rm -r ${TEMPDIR} || true
mkdir ${TEMPDIR} || true

ROUND0=$(goal node status | head -n 1 | cut -d ' ' -f 4)
echo "$ROUND0" >> "${DIR}/tail-round"

HEAD_RND=$(head -n 1 "${DIR}/head-round")
TAIL_RND=$(head -n 1 "${DIR}/tail-round")

ERR_APP_OI_STR1='has not opted in to application'

ESCROW=$(goal app read --app-id ${APP_ID} --global --guess-format | jq -r .es.tb)

DEADLINE=$(goal app read --app-id ${APP_ID} --global --guess-format | jq -r '.ad.ui + 0')
if [ $DEADLINE -eq 0 ]; then
    echo "Auction has already been closed."
    exit 1
fi

# TODO parameterize out indexer URL
ACCOUNTS=($(curl "localhost:8980/v2/transactions?address=${ESCROW}&asset-id=${USDC_ID}&min-round=${HEAD_RND}&max-round=${TAIL_RND}" | jq .transactions | jq "map(.sender)" | jq -r 'join(" ")'))

RECEIPTS_LEFT=$(goal app read --app-id ${APP_ID} --global --guess-format | jq -r '.rc.ui + 0')
while [ 0 -lt $RECEIPTS_LEFT ]; do
    for acct in "${ACCOUNTS[@]}"; do
	echo $acct
	RES=$(goal app read --app-id ${APP_ID} --local -f ${acct} --guess-format 2>&1 || true)
	if [[ $RES != *"$ERR_APP_OI_STR1"* ]]; then
	    RECEIPTS=$(echo "$RES" | jq -r .br.ui || true)
	    "${DIR}/refs/scripts/discharge-bid.sh" ${FROM} $acct ${ESCROW_SRC} &
	fi
    done
    wait

    goal node wait
    RECEIPTS_LEFT=$(goal app read --app-id ${APP_ID} --global --guess-format | jq -r '.rc.ui + 0')
done

goal clerk send -o ${TEMPDIR}/closer0.tx -a 1 --from ${FROM} --to ${ESCROW}
goal app call   -o ${TEMPDIR}/closer1.tx --from ${FROM} --app-id ${APP_ID} --app-arg int:0 --app-arg int:0
goal asset send -o ${TEMPDIR}/closer2.tx --assetid ${USDC_ID} --from ${ESCROW} -c ${SELLER} -a 0 -t ${ZERO_ADDRESS}
goal asset send -o ${TEMPDIR}/closer3.tx --assetid ${SOV_ID} --from ${ESCROW} -c ${SELLER} -a 0 -t ${ZERO_ADDRESS}
goal clerk send -o ${TEMPDIR}/closer4.tx --from ${ESCROW} -c ${SELLER} -a 0 -t ${ZERO_ADDRESS}
cat ${TEMPDIR}/closer*.tx > ${TEMPDIR}/closec.tx

goal clerk group -i ${TEMPDIR}/closec.tx -o ${TEMPDIR}/closerg.tx
goal clerk split -i ${TEMPDIR}/closerg.tx -o ${TEMPDIR}/closeg.tx

goal clerk sign -i ${TEMPDIR}/closeg-0.tx -o ${TEMPDIR}/closes0.stx
goal clerk sign -i ${TEMPDIR}/closeg-1.tx -o ${TEMPDIR}/closes1.stx
goal clerk sign -i ${TEMPDIR}/closeg-2.tx -o ${TEMPDIR}/closes2.stx -p ${ESCROW_SRC}
goal clerk sign -i ${TEMPDIR}/closeg-3.tx -o ${TEMPDIR}/closes3.stx -p ${ESCROW_SRC}
goal clerk sign -i ${TEMPDIR}/closeg-4.tx -o ${TEMPDIR}/closes4.stx -p ${ESCROW_SRC}

cat ${TEMPDIR}/closes*.stx > ${TEMPDIR}/close.stx
goal clerk rawsend -f ${TEMPDIR}/close.stx

rm "${DIR}/head-round"
rm "${DIR}/tail-round"
