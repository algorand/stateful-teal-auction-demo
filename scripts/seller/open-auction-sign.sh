#!/usr/bin/env bash

# Functionality intended to be covered by the seller.
#
# Note that this may be replaced in practice with a
# hardware wallet or some other key management solution.

set -ex
set -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/.."

if [ "$1" == "" ]; then
    echo "No input transaction filename specified."
    echo "Usage: $0 input-filename output-filename"
    false
fi
INPUT=$1

if [ "$2" == "" ]; then
    echo "No output transaction filename specified."
    echo "Usage: $0 input-filename output-filename"
    false
fi
OUTPUT=$2

goal clerk sign -i "${INPUT}" -o "${OUTPUT}"
