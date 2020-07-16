#!/usr/bin/env bash

# Functionality used by anyone.

set -e
set -o pipefail

if [ "$1" == "" ]; then
    echo "No application ID amount specified."
    echo "Usage: $1 app-id"
    false
fi
APP_ID=$1

echo "Auction application ID: ${APP_ID}"

ROUND=$(goal node status | head -n 1 | cut -d ' ' -f 4)
LAST_TSTAMP=$(goal ledger block --strict ${ROUND} | jq .block.ts)
TCOUNT=$(goal ledger block --strict ${ROUND} | jq .block.tc)

NEXIST_STR="application does not exist"
EXISTS=$(goal app read --global --app-id ${APP_ID} 2>&1 || true)

if [[ "$EXISTS" == *$NEXIST_STR* ]]; then
    if [ $TCOUNT -gt $APP_ID ]; then
	echo "State: TERMINATED"
	exit 0
    elif [ $TCOUNT -lt $APP_ID ]; then
	echo "State: INVALID"
	exit 0
    else
	# pass
	:
    fi
fi

DEADLINE=$(goal app read --global --app-id ${APP_ID} | jq '.ad.ui + 0')

BID_ID=$(goal app read --global --app-id ${APP_ID} | jq '.["b$"].ui')
SALE_ID=$(goal app read --global --app-id ${APP_ID} | jq '.["s$"].ui')

TRANCHE_RAISED=$(goal app read --global --app-id ${APP_ID} | jq '.ar.ui + 0')
TRANCHE_SUPPLY=$(goal app read --global --app-id ${APP_ID} | jq .as.ui)
AUCTION_DEADLINE=$(goal app read --global --app-id ${APP_ID} | jq '.ad.ui + 0')
RECEIPTS_LEFT=$(goal app read --global --app-id ${APP_ID} | jq '.rc.ui + 0')

echo "Bid asset: ${BID_ID}"
echo "Sale asset: ${SALE_ID}"

if [ $DEADLINE -eq 0 ]; then
    echo "State: READY"
elif [ $DEADLINE -le $LAST_TSTAMP ]; then
    echo "State: CLOSED"
    echo "Amount raised this tranche: ${TRANCHE_RAISED}"
    echo "Current tranche size: ${TRANCHE_SUPPLY}"
    echo "Latest block timestamp: ${LAST_TSTAMP}"
    echo "Current tranche deadline: ${AUCTION_DEADLINE}"
    echo "Receipts left to pay out: ${RECEIPTS_LEFT}"
else
    echo "State: OPEN"
    echo "Amount raised this tranche: ${TRANCHE_RAISED}"
    echo "Current tranche size: ${TRANCHE_SUPPLY}"
    echo "Latest block timestamp: ${LAST_TSTAMP}"
    echo "Current tranche deadline: ${AUCTION_DEADLINE}"
fi

TRANCHE_INDEX=$(goal app read --app-id ${APP_ID} --global --guess-format | jq '.ti.ui + 0')
NUM_TRANCHES=$(goal app read --app-id ${APP_ID} --global --guess-format | jq .nt.ui)
echo "Current tranche: ${TRANCHE_INDEX} / ${NUM_TRANCHES}"
