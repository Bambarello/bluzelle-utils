#!/bin/bash

BIN_FILE="/usr/bin/blzcli"
CHAIN_ID="bluzelle"
SELF_ADDR=$($BIN_FILE keys list | jq -r .[0].address)
DENOM=$($BIN_FILE q staking delegations --chain-id $CHAIN_ID --node $RPC_LADDR  $SELF_ADDR | jq -r .[].balance.denom)
SELF_ADDR=$($BIN_FILE keys list | jq -r .[0].address)
OPERATOR=$($BIN_FILE q staking delegations --chain-id $CHAIN_ID --node $RPC_LADDR  $SELF_ADDR | jq -r .[].validator_address)

echo -e "Current address: $SELF_ADDR\nCurrent operator address: $OPERATOR"

BALANCE=$($BIN_FILE query account $SELF_ADDR --node $RPC_LADDR -o json | jq -r .value.coins[0].amount)
echo CURRENT BALANCE IS: $BALANCE
REWARD=$(( $BALANCE - 1008000000 ))

if (( $BALANCE >=  2008000000 )); then
    echo "Let's delegate $REWARD of REWARD tokens to $SELF_ADDR"
    # delegate balance
    $BIN_FILE tx staking delegate $OPERATOR "$REWARD"$DENOM --chain-id $CHAIN_ID --node $RPC_LADDR --gas-adjustment 1.5 --gas auto --gas-prices "10.0"$DENOM --from $MONIKER -y

else
    echo "Reward is $REWARD"
fi
echo "DONE"
