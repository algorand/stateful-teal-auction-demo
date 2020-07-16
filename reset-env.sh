#!/usr/bin/env bash

set -ex
set -o pipefail

goal node stop

# clear out log files and cdv files
# reset participation keys

rm ~/demo-node/agreement* || true
rm ~/demo-node/*.log || true
rm ~/demo-node/sovnet-v1.0/*sql* || true
cp ~/go-algorand/gen/devnet/*key ~/demo-node/sovnet-v1.0/

# clear indexer state

killall algorand-indexer || true
dropdb ubuntu || true
createdb
