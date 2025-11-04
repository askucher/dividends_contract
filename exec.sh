#!/bin/bash

build() {
    cd contracts && forge build && cd ..
}

test() {
    cd contracts && forge test -vvv && cd ..
}

deploy() {
    cd contracts && forge script script/FeemakerHolders.s.sol:CounterScript --rpc-url "$1" --broadcast --private-key "$2 && cd ..
}

"$1" "$2"