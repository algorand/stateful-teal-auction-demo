#!/usr/bin/env bash

# Intended to be used directly by the auction creator.

set -ex
set -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/.."
TEMPDIR="${DIR}/tmp"

# TODO replace this with an indexer call once it is ready
$ACCOUNTS=$(goal account list | cut -d ' ' -f 3)
