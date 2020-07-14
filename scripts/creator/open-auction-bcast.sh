#!/usr/bin/env bash

# Intended to be used directly by the auction creator.
#
# It expects to be run after a signature of the input file,
# which should happen after open-auction-txn is run.

set -ex
set -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/.."
TEMPDIR="${DIR}/tmp"

if [ "$1" == "" ]; then
    echo "No input transaction filename specified."
    echo "Usage: $0 input-filename"
    false
fi
INPUT=$1

HEAD_ROUND=$(goal node status | head -n 1 | cut -d ' ' -f 4)
echo "$HEAD_ROUND" > "${DIR}/head-round"

cp "${INPUT}" ${TEMPDIR}/opens4.stx

cat ${TEMPDIR}/opens*.stx > ${TEMPDIR}/open.stx
goal clerk rawsend -f ${TEMPDIR}/open.stx
