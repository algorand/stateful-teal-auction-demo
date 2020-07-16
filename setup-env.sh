#!/usr/bin/env bash

set -exm
set -o pipefail

mkdir tmp || true

# start up the node and the indexer
goal node start
nohup algorand-indexer daemon --algod-net $(cat ~/demo-node/algod.net) --algod-token $(cat ~/demo-node/algod.token) --genesis ~/demo-node/genesis.json --postgres "user=ubuntu password=password" >> ~/demo-indexer.log 2>&1 &

# initialize application code
#
# here we use tealcut so that the application can initialize
# the escrow at creation time.  tealcut works by partitioning
# the escrow TEAL program into a prefix and a suffix, leaving
# eight bytes to specify the application ID.

# a sentinel value is required for the program to compile correctly
SENTINEL=0x0000000000001040
sed s/TMPL_APPID/${SENTINEL}/g < src/sovauc_escrow_tmpl.teal > tmp/sovauc_escrow_tmpl.teal
goal clerk compile tmp/sovauc_escrow_tmpl.teal -o tmp/sovauc_escrow_tmpl.tealc

# tell tealcut to cleave around the sentinel value
EPREFIX=$(tealcut tmp/sovauc_escrow_tmpl.tealc ${SENTINEL} | grep sub0 | cut -f 2 -d ' ')
ESUFFIX=$(tealcut tmp/sovauc_escrow_tmpl.tealc ${SENTINEL} b64 | grep sub1 | cut -f 2 -d ' ')
ESUFFIXH=$(tealcut tmp/sovauc_escrow_tmpl.tealc ${SENTINEL} | grep hash1 | cut -f 2 -d ' ')

# we now have the prefix and the suffix hash, which must be
# written into the application code
#
# the suffix will be used later as an argument to the application
# creation transaction
mkdir build || true
sed s/TMPL_EPREFIX/${EPREFIX}/g < src/sovauc_approve.teal | sed s/TMPL_ESUFFIXH/${ESUFFIXH}/g > build/sovauc_approve.teal
sed s/TMPL_EPREFIX/${EPREFIX}/g < src/sovauc_clear.teal | sed s/TMPL_ESUFFIXH/${ESUFFIXH}/g > build/sovauc_clear.teal
cp src/sovauc_escrow_tmpl.teal build/sovauc_escrow_tmpl.teal
echo ${ESUFFIX} > build/escrow_suffix

# initialize Algo balances

SEED=$(goal account list | grep -v Unnamed | grep -v creator | head -n 1 | cut -f 2)

CREATOR=$(goal account new|cut -d ' ' -f 6)
SELLER=$(goal account new|cut -d ' ' -f 6)
RESERVE=$(goal account new|cut -d ' ' -f 6)
ALICE=$(goal account new|cut -d ' ' -f 6)
BOB=$(goal account new|cut -d ' ' -f 6)
CAROL=$(goal account new|cut -d ' ' -f 6)
DAVE=$(goal account new|cut -d ' ' -f 6)

goal clerk send -a 100000000000 -f ${SEED} -t ${CREATOR}

(
    goal clerk send -a 100000000 -f ${CREATOR} -t ${ALICE} || kill 0 &
    goal clerk send -a 100000000 -f ${CREATOR} -t ${BOB} || kill 0 &
    goal clerk send -a 100000000 -f ${CREATOR} -t ${CAROL} || kill 0 &
    goal clerk send -a 100000000 -f ${CREATOR} -t ${DAVE} || kill 0 &
    goal clerk send -a 100000000 -f ${CREATOR} -t ${SELLER} || kill 0 &
    goal clerk send -a 100000000 -f ${CREATOR} -t ${RESERVE} || kill 0 &
    wait
)

# create reference assets

goal asset create --creator ${SELLER} --name sov --unitname sov --total $(echo "2^64 - 1" | bc)
goal asset create --creator ${RESERVE} --name usdc --unitname usdc --total $(echo "2^64 - 1" | bc)

# SOV_ID is the asset that is being sold at auction
# USDC_ID is the asset that is used to bid
SOV_ID=$(goal asset info --creator ${SELLER} --asset sov|grep 'Asset ID'|awk '{ print $3 }')
USDC_ID=$(goal asset info --creator ${RESERVE} --asset usdc|grep 'Asset ID'|awk '{ print $3 }')

goal asset send --from ${SELLER} --to ${SELLER} -a 0 --assetid ${USDC_ID}

# fund bidder accounts with assets

(
    goal asset send -a 0 --assetid ${USDC_ID} --from ${ALICE} --to ${ALICE} || kill 0 &
    goal asset send -a 0 --assetid ${USDC_ID} --from ${BOB} --to ${BOB} || kill 0 &
    goal asset send -a 0 --assetid ${USDC_ID} --from ${CAROL} --to ${CAROL} || kill 0 &
    goal asset send -a 0 --assetid ${USDC_ID} --from ${DAVE} --to ${DAVE} || kill 0 &
    wait
)

(
    goal asset send --amount 18000000000000000 --assetid ${USDC_ID} --from ${RESERVE} --to ${ALICE} || kill 0 &
    goal asset send --amount 18000000000000000 --assetid ${USDC_ID} --from ${RESERVE} --to ${BOB} || kill 0 &
    goal asset send --amount 18000000000000000 --assetid ${USDC_ID} --from ${RESERVE} --to ${CAROL} || kill 0 &
    goal asset send --amount 18000000000000000 --assetid ${USDC_ID} --from ${RESERVE} --to ${DAVE} || kill 0 &
    wait
)

# populate filesystem with parameters

TEMPDIR=$(mktemp -d)
rm "$HOME/last-auction" || true
ln -s ${TEMPDIR} "$HOME/last-auction"

mkdir "${TEMPDIR}/chan"

mkdir "${TEMPDIR}/refs"

echo "${SOV_ID}" > "${TEMPDIR}/refs/sov"
echo "${USDC_ID}" > "${TEMPDIR}/refs/usdc"

mkdir "${TEMPDIR}/creator"
mkdir "${TEMPDIR}/seller"
mkdir "${TEMPDIR}/reserve"
mkdir "${TEMPDIR}/alice"
mkdir "${TEMPDIR}/bob"
mkdir "${TEMPDIR}/carol"
mkdir "${TEMPDIR}/dave"

cp -R scripts/common "${TEMPDIR}/refs/scripts"
cp -R scripts/creator "${TEMPDIR}/creator/scripts"
cp -R scripts/seller "${TEMPDIR}/seller/scripts"

ln -s "${TEMPDIR}/refs" "${TEMPDIR}/creator/refs"
ln -s "${TEMPDIR}/refs" "${TEMPDIR}/seller/refs"
ln -s "${TEMPDIR}/refs" "${TEMPDIR}/reserve/refs"
ln -s "${TEMPDIR}/refs" "${TEMPDIR}/alice/refs"
ln -s "${TEMPDIR}/refs" "${TEMPDIR}/bob/refs"
ln -s "${TEMPDIR}/refs" "${TEMPDIR}/carol/refs"
ln -s "${TEMPDIR}/refs" "${TEMPDIR}/dave/refs"

ln -s "${TEMPDIR}/refs/scripts" "${TEMPDIR}/creator/scripts"
ln -s "${TEMPDIR}/refs/scripts" "${TEMPDIR}/seller/scripts"
ln -s "${TEMPDIR}/refs/scripts" "${TEMPDIR}/reserve/scripts"
ln -s "${TEMPDIR}/refs/scripts" "${TEMPDIR}/alice/scripts"
ln -s "${TEMPDIR}/refs/scripts" "${TEMPDIR}/bob/scripts"
ln -s "${TEMPDIR}/refs/scripts" "${TEMPDIR}/carol/scripts"
ln -s "${TEMPDIR}/refs/scripts" "${TEMPDIR}/dave/scripts"

echo "${CREATOR}" > "${TEMPDIR}/creator/addr"
echo "${SELLER}" > "${TEMPDIR}/seller/addr"
echo "${RESERVE}" > "${TEMPDIR}/reserve/addr"
echo "${ALICE}" > "${TEMPDIR}/alice/addr"
echo "${BOB}" > "${TEMPDIR}/bob/addr"
echo "${CAROL}" > "${TEMPDIR}/carol/addr"
echo "${DAVE}" > "${TEMPDIR}/dave/addr"

mkdir "${TEMPDIR}/refs/src"
cp build/*.teal "${TEMPDIR}/refs/src"

cp default-parameters.json "${TEMPDIR}/creator/parameters.json"

mkdir "${TEMPDIR}/creator/src"
cp build/*.teal "${TEMPDIR}/creator/src"
cp build/escrow_suffix "${TEMPDIR}/creator/src"
cp src/sovauc_escrow_tmpl.teal "${TEMPDIR}/creator/src"

echo "Auction environment initialized at ${TEMPDIR} (linked from $HOME/last-auction)"
