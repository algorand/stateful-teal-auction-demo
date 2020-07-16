These scripts assume that
- `goal` is in your $PATH
- $ALGORAND_DATA is set correctly
- $INDEXER_URL is set correctly ("localhost:8980" is the Indexer's default)

# Non-interactive demo

Run

```
$ ./demo.sh
```

This will create a 16-tranche auction with a lookback of 4.
(These parameters and others are specified in default-parameters.json.)
This will launch the auction and have four bidders continually bid
until the auction terminates.

# Interactive Demo

To set everything up,

```
$ ./setup-env.sh
$ export AUCTION_DATA=~/last-auction
```


Set parameters in $AUCTION_DATA/creator/parameters.json as desired.
When you would like to initialize the series of auctions,

```
$ ./init-auction-series.sh
```


To start an auction for a particular tranche,

```
$ ./open-auction.sh
```


To input a round of bids from various bidders,

```
$ ./enter-various-bids.sh
```


To wait for an auction to close,

```
$ ./wait-for-auction-close.sh
```


To payout an auction,

```
$ ./close-auction.sh
```


Once all auctions have completed, clean up auction state with

```
$ ./shutdown-auction-series.sh
```


# Communication requirements

There are several assumptions about the environment:

1. Setting up the tokens which will be sold and bid with.
2. Making the application source code hashes available to bidders.
3. Having the seller opt into the bid token.
4. Funding the bidders with the bid token.
5. The auction administrator needs access to an indexer service.

setup-env.sh initializes these in the demo.

After create-auction-series.sh is executed, an application ID is returned.
This application ID must be given to all bidders so that they know where to bid.

open-auction-txn.sh and open-auction-bcast.sh rely on the seller
to sign a transaction which funds the auction.

discharge-bid.sh relies on access to the escrow script.
After the auction series has started, and the application ID is known,
anyone can derive this script similarly to setup-env.sh.
