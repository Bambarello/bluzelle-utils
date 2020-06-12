#!/bin/sh
apt install -y curl jq htop nano
blzd init $MONIKER --chain-id bluzelle
blzcli config chain-id bluzelle
blzcli config output json
blzcli config indent true
blzcli config trust-node true
blzcli config keyring-backend test
curl=$(which curl)
EXTERNAL_IP=$(curl -s 2ip.ru)
RPC_LADDR=tcp://127.0.0.1:26657

sed -i -e 's/minimum-gas-prices = ""/minimum-gas-prices = "10.0ubnt"/g' \
    ~/.blzd/config/app.toml
sed -i -e 's/addr_book_strict = true/addr_book_strict = false/g' ~/.blzd/config/config.toml

if ! grep -Fxq "bluzelle_crud = true" ~/.blzd/config/app.toml; then
    echo "bluzelle_crud = true" >> ~/.blzd/config/app.toml
fi
    
wget https://raw.githubusercontent.com/c29r3/bluzelle-utils/master/genesis.json -O ~/.blzd/config/genesis.json
sed -i -e 's/allow_duplicate_ip = false/allow_duplicate_ip = true/g' ~/.blzd/config/config.toml

if [ "$MONIKER" != "sentry" ]; then
    echo $SEED | blzcli keys add --recover $MONIKER --keyring-backend test
    unset SEED
    sed -i -e 's/pex = false/pex = true/g' ~/.blzd/config/config.toml
    
    blzd start \
    --moniker $MONIKER \
    --pruning nothing \
    --p2p.laddr $P2P_LADDR \
    --rpc.laddr $RPC_LADDR \
    --p2p.persistent_peers $PERSISTENT_PEERS &

    sleep 60
    SYNC_STATUS=$(blzcli status --node $RPC_LADDR | jq .sync_info.catching_up)
    while [[ $SYNC_STATUS != "false" ]]; do
        SYNC_STATUS=$(blzcli status --node $RPC_LADDR | jq .sync_info.catching_up)
        sleep 10
    done
    echo -e "Creating stake for $MONIKER"
    $(which curl) -s https://raw.githubusercontent.com/c29r3/bluzelle-utils/master/create-stake.sh | /bin/bash
    
    while true; 
    do 
        OPERATOR=$(blzcli q staking delegations --node $RPC_LADDR  $(blzcli keys list | jq -r .[0].address) | jq -r .[].validator_address)
        STATUS=$(blzcli query staking validator $OPERATOR --node $RPC_LADDR --trust-node -o json | jq -r .status)
        if [[ $STATUS != "2" ]]; then
            echo "UNJAIL"
            $(which curl) -s https://raw.githubusercontent.com/c29r3/bluzelle-utils/master/unjail.sh | /bin/bash
        fi
        sleep 520
        $(which curl) -s https://raw.githubusercontent.com/c29r3/bluzelle-utils/master/redelegate.sh | bash &
    done

else
    echo $PERSISTENT_PEERS
    echo "Starting Sentry jobs"
    blzd start \
    --moniker $MONIKER \
    --p2p.laddr $P2P_LADDR \
    --rpc.laddr $RPC_LADDR \
    --p2p.persistent_peers "$(cat ~/nodes_addresses.txt | paste -sd ","),$PERSISTENT_PEERS" \
    --p2p.private_peer_ids $(cat ~/nodes_ids.txt | paste -sd ",")  &
   
    sleep 30
    SENTRY_ID=$(blzcli status --node $RPC_LADDR | jq -r .node_info.id)
    echo -e "Sentry ID: $SENTRY_ID"
    echo "$SENTRY_ID" > ~/sentry_address.txt
    blzcli rest-server --laddr $REST_ADDR
fi
