#!/usr/bin/env bash

# Functionality used by anyone.

set -ex
set -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && cd .. >/dev/null 2>&1 && pwd )"

APP_ID=$(cat "${DIR}/app")

DEADLINE=$(goal app read --app-id ${APP_ID} --global --guess-format | jq -r .ad.ui)

# TODO this assumes that blockchain timestamp is near realtime;
# use block header timestamp instead for better accuracy

while [ $(date '+%s') -le $DEADLINE ]; do
    goal node wait
done

goal node wait
