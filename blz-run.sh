 
#!/bin/sh

blzd init $MONIKER --chain-id bluzelle
blzcli config chain-id bluzelle
blzcli config output json
blzcli config indent true
blzcli config trust-node true
blzcli config keyring-backend test
EXTERNAL_IP=$(curl -s 2ip.ru)

sed -i -e 's/minimum-gas-prices = ""/minimum-gas-prices = "10.0ubnt"/g' \
    ~/.blzd/config/app.toml
sed -i -e 's/addr_book_strict = true/addr_book_strict = false/g' ~/.blzd/config/config.toml

if ! grep -Fxq "bluzelle_crud = true" ~/.blzd/config/app.toml; then
    echo "bluzelle_crud = true" >> ~/.blzd/config/app.toml
fi
    
wget https://raw.githubusercontent.com/c29r3/bluzelle-utils/master/genesis.json -O ~/.blzd/config/genesis.json
sed -i -e 's/allow_duplicate_ip = false/allow_duplicate_ip = true/g' ~/.blzd/config/config.toml

if [ "$MONIKER" != "sentry" ]; then
    echo -e "$SEED\n" | blzcli keys add --recover $MONIKER --keyring-backend test
    unset SEED
    sed -i -e 's/pex = false/pex = true/g' ~/.blzd/config/config.toml
    
    SENTRY_ADDR="$(cat ~/sentry_address.txt)@$EXTERNAL_IP:26686"
    echo "Sentry address $SENTRY_ADDR"
    
    blzd start \
    --moniker $MONIKER \
    --pruning nothing \
    --p2p.laddr $P2P_LADDR \
    --rpc.laddr $RPC_LADDR \
    --p2p.persistent_peers $SENTRY_ADDR,$PERSISTENT_PEERS \
    --p2p.seeds $PERSISTENT_PEERS
    
    sleep 30
    VALIDATOR_ID=$(blzcli status --node $RPC_LADDR | jq -r .node_info.id)
    echo -e "Validator ID: $VALIDATOR_ID"
    if ! grep -Fxq $VALIDATOR_ID ~/nodes_ids.txt; then
        echo $VALIDATOR_ID >> ~/nodes_ids.txt
    fi
    
    VALIDATOR_P2P_PORT=$(echo $P2P_LADDR | cut -d ":" -f3)
    VALIDATOR_ADDRESS="$VALIDATOR_ID@$EXTERNAL_IP:$VALIDATOR_P2P_PORT"
    echo -e "Validator address: $VALIDATOR_ADDRESS"
    if ! grep -Fxq $VALIDATOR_ADDRESS ~/nodes_addresses.txt; then
       echo $VALIDATOR_ADDRESS >> ~/nodes_addresses.txt
    fi
    
    
    SYNC_STATUS=$(blzcli status --node $RPC_LADDR | jq .sync_info.catching_up)
    while [[ $SYNC_STATUS != "false" ]]; do
        SYNC_STATUS=$(blzcli status --node $RPC_LADDR | jq .sync_info.catching_up)
        sleep 10
    done
    echo -e "Creating stake for $MONIKER"
    curl -s https://raw.githubusercontent.com/c29r3/bluzelle-utils/master/create-stake.sh | /bin/bash
    
    while true; 
    do 
        OPERATOR=$(blzcli q staking delegations --node $RPC_LADDR  $(blzcli keys list | jq -r .[0].address) | jq -r .[].validator_address)
        STATUS=$(blzcli query staking validator $OPERATOR --node $RPC_LADDR --trust-node -o json | jq -r .status)
        if [[ $STATUS != "2" ]]; then
            echo "UNJAIL"
            curl -s https://raw.githubusercontent.com/c29r3/bluzelle-utils/master/unjail.sh | /bin/bash
        fi
        sleep 520
        curl -s https://raw.githubusercontent.com/c29r3/bluzelle-utils/master/redelegate.sh | bash &
    done
    blzcli rest-server --laddr $REST_ADDR

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
