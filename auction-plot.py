#!/usr/bin/env python3

import argparse
import json

import numpy as np
import matplotlib.pyplot as plt

parser = argparse.ArgumentParser(description='plot results of an auction')

parser.add_argument('bidfile', help='JSON file containing bid token txns in escrow')
parser.add_argument('salesfile', help='JSON file containing sale token txns in escrow')
parser.add_argument('outfile', help='Output image file')

args = parser.parse_args()

with open(args.bidfile) as f:
    bidtxns = json.load(f)

with open(args.salesfile) as f:
    salestxns = json.load(f)

bidtxns = bidtxns['transactions']
salestxns = salestxns['transactions']

escrow = ''
for k in bidtxns:
    if k['sender'] == k['asset-transfer-transaction']['receiver']:
        escrow = k['sender']

if escrow == '':
    raise Exception("can't find escrow in bidfile")

class Bid:
    def __init__(self, bidder, round_time, amount):
        self.bidder = bidder
        self.round_time = round_time
        self.amount = amount

    def __str__(self):
        return "{}:{}@{}".format(self.bidder, self.amount, self.round_time)

class Sale:
    def __init__(self, bidder, round_time, amount):
        self.bidder = bidder
        self.round_time = round_time
        self.amount = amount

    def __str__(self):
        return "{}:{}@{}".format(self.bidder, self.amount, self.round_time)

bids = []
for k in bidtxns:
    bidder = k['sender']
    round_time = k['round-time']
    amount = k['asset-transfer-transaction']['amount']
    bids.append(Bid(bidder, round_time, amount))

sales = []
for k in salestxns:
    bidder = k['asset-transfer-transaction']['receiver']
    round_time = k['round-time']
    amount = k['asset-transfer-transaction']['amount']
    sales.append(Sale(bidder, round_time, amount))
    

print(len(bidtxns))

BID_DIV = 1e6
SALE_DIV = 1e4


xs0 = []
ys0 = []
xs1 = []
ys1 = []
for b in bids:
    if b.amount == 0:
        continue
    xs, ys = xs0, ys0
    if b.bidder == escrow:
        xs, ys = xs1, ys1
    xs.append(b.round_time)
    ys.append(b.amount / BID_DIV)

    print(str(b))

plt.plot(xs0, ys0, 'x', label='Bid (USDC)')

X = sorted(zip(xs0, ys0), key=lambda a: a[0])
integrated = {}
total = 0
for x in X:
    total += x[1]
    integrated[x[0]] = total

Y = []
for k in integrated:
    Y.append((k, integrated[k] / 10))

Y = sorted(Y, key=lambda a: a[0])
xs2, ys2 = zip(*Y)

plt.plot(xs2, ys2, '-', label='Auction revenue (USDC/10)')

print(len(salestxns))

xs0 = []
ys0 = []
xs1 = []
ys1 = []
for s in sales:
    if s.amount == 0:
        continue
    xs, ys = xs0, ys0
    if s.bidder == escrow:
        xs, ys = xs1, ys1
    xs.append(s.round_time)
    ys.append(s.amount / SALE_DIV)
    print(str(s))

plt.plot(xs0, ys0, '+', label='Sale (Token)')
plt.plot(xs1, ys1, 'o', label='Tranche size (Token)')

plt.xlabel('UNIX time')
plt.ylabel('Units')
plt.legend()
plt.savefig(args.outfile)
