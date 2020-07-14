These scripts assume that `goal` is in your $PATH and that $ALGORAND_DATA is set correctly.

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
$ ./destroy-auction.sh
```


# Communication requirements

There are several assumptions about the environment:

1. Setting up the tokens which will be sold and bid with.
2. Making the application source code hashes available to bidders.
3. Having the seller opt into the bid token.
4. Funding the bidders with the bid token.
5. The auction administrator needs access to a node data directory
   (TODO or an indexer service).

setup-env.sh initializes these in the demo.

After create-auction-series.sh is executed, an application ID is returned.
This application ID must be given to all bidders so that they know where to bid.

open-auction-txn.sh and open-auction-bcast.sh rely on the seller
to sign a transaction which funds the auction.