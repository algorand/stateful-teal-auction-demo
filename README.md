These scripts assume that
- `goal` is in your $PATH
- `algorand-indexer` is in your $PATH
- $ALGORAND_DATA is set correctly
- $INDEXER_URL is set correctly ("localhost:8980" is the Indexer's default)
- `~/demo-node` contains an Algorand node with a consensus version that
  supports stateful TEAL

# Non-interactive demo

Run

```
$ ./demo.sh
```

This will create a 16-tranche auction with a lookback of 4.
(These parameters and others are specified in default-parameters.json.)
This will launch the auction and have four bidders continually bid
until the auction terminates.

# Application Design

## Security model

The main accounts in the auction consist of the seller, which is
selling its tokens in the auction, the auction administrator, which
peforms administrative tasks on behalf of the auction, and bidder
accounts, which can be any other account in the system.

This auction utilizes an escrow account, which holds funds that
are committed to the auction (either the bid or sale tokens).

This application seeks to achieve the following properties:
1. Once an auction series is started, all tranches in the auction
   obey the tranche formula committed by the parameters established
   at initialization.
2. An auction is open if and only if the seller has committed
   enough tokens to fill a tranche.
3. Any bidder commits bid tokens to the auction exactly when the
   bid is entered.  All inputs to the tranche size calculation
   formula reflect successful bids.
4. Once a bid is committed, the bidder is guaranteed to be able
   to claim units of the sale token according to the pricing
   formula, once the deadline for the particular tranche has
   passed.
5. Once a bid is committed, the seller is guaranteed to be able
   to reclaim tokens exactly when it closes the tranche.
6. A tranche will not be closed unless either all bids have been
   paid out or destroyed.
7. A bid must be paid out if a bidder has opted into the sale token.
   A bid will only be destroyed if the bidder has not opted in.
   (Note that a bidder can temporarily delay an auction by
   wasting fees by opting in and out repeatedly).
8. The auction series may only be destroyed and deallocated from
   the blockchain once all tranches have concluded.

## States

The auction series, as corresponding to a particular application ID,
can be considered to reside in one of several logical states.

1. INVALID - The auction series has not been created yet.
2. READY - The auction series has been created, and an auction for
   the next tranche may be opened by the auction administrator.
3. OPEN - The auction is accepting bids for the current tranche.
4. CLOSED - The auction is no longer accepting bids for the latest
   tranche.  Bidders may now cash out their bids for the sale token.
5. TERMINATED - The auction series has concluded.

Initially, the application creation transaction from the
administrator creates an application ID and moves the state of that
instance to READY.

If an auction is READY, the auction administrator can, in a group
transaction with the seller, atomically change the state to OPEN
and fund the escrow, so long as tranches remain to be sold off.

Once the auction is OPEN, it will remain OPEN for all blocks with
a block header containing a timestamp lower than the auction
deadline.  After this deadline has passed (in the sequence of blocks),
the auction becomes CLOSED.

When an auction is CLOSED, bids may be cashed out for units of the
sale token.  Once all bids have been cashed out, the auction
administrator can send all bid tokens and residual sale tokens
present in the escrow account to the seller and atomically set the
auction state to be READY.

If an auction is READY but no tranches remain, the auction may
be deallocated and moved to TERMINATED by an application deletion
transaction.

# Interactive demo

## Environment setup and initialization

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

This script writes all parameters into stateful TEAL global storage
and returns the application ID which is needed to run the auction.
At this point, the application is ready to support the first auction
tranche.

## Running an auction

To start an auction for a particular tranche,

```
$ ./open-auction.sh
```

This changes the state of the auction to OPEN, atomically funding
the escrow with the sale token.

## Entering bids

To get the latest state of the auction, run

```
$ ./auction-status.sh
```

If the returned state is OPEN, you may enter a bid.
You may enter a bid on behalf of a particular user with

```
$ "${AUCTION_ROOT}/<user>/scripts/enter-bid.sh" <amount>
```

To input a round of bids from various bidders, distributed almost
uniformly at random from a few values, use

```
$ ./enter-various-bids.sh
```

## Closing an auction and paying out bids

To wait for an auction to close,

```
$ ./wait-for-auction-close.sh
```

After the state of the auction is CLOSED, you must pay out the bids
before auctioning off a new tranche.  To payout an auction,

```
$ ./close-auction.sh
```

## Cleanup

Once all auctions have completed, clean up auction state with

```
$ ./shutdown-auction-series.sh
```

# Visualization

To generate stats from the indexer, run

```
$ ./statfile.sh <escrow-addr> <data-file1> <data-file2>
```

Note that you'll need the address of the escrow account to do this.

You can plot these stats in a file `<out>.pdf` with

```
$ python auction-plot.py --bidfile <data-file1> --salesfile <data-file2> --outfile <out>.pdf
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
