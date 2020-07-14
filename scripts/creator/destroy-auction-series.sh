#!/usr/bin/env bash

# Intended to be used directly by the auction creator.
#
# Note that the auction series can only be destroyed by the creator.

set -ex
set -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/.."

FROM=$(cat "${DIR}/addr")
APP_ID=$(cat "${DIR}/refs/app")

goal app delete --from ${FROM} --app-id ${APP_ID}
