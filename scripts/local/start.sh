#!/bin/bash
CHAINID="maestro-test-1"
CHAIN_DIR=$HOME/.maestrod
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
MONIKER="mymoniker"
KEYRING="test"
DENOM=umaestro

API_ADDRESS=1317
GRPC_ADDRESS=9090
GRPC_WEB_ADDRESS=9091
P2P_LADDR=26656
RPC_LADDR=26657
RPC_PPROF_LADDR=6060

if [ ! -f "$SCRIPT_DIR/../../build/maestrod" ]; then
    echo >&2 "maestrod binary is not found! Please build first."
    exit 1
fi

CMD="$SCRIPT_DIR/../../build/maestrod --home $CHAIN_DIR"

# The logging level (trace|debug|info|warn|error|fatal|panic) (default: debug)
if [[ -z "$LOGLEVEL" ]]; then
   LOGLEVEL="info"
fi

KEY_ALICE="alice"
KEY_RELAYER="relayer"
MNEMONIC_ALICE="entry garbage bike poem grunt negative easily annual miss happy license blur false fringe program picture inner tape dismiss eagle include quality drill master"
MNEMONIC_RELAYER="use glove remain glance twin scout tank seminar purchase mix window illness"

# validate dependencies are installed
command -v jq >/dev/null 2>&1 || {
    echo >&2 "jq not installed. More info: https://stedolan.github.io/jq/download/"
    exit 1
}

# remove existing daemon
rm -rf $CHAIN_DIR
mkdir $CHAIN_DIR

$CMD config keyring-backend $KEYRING
$CMD config chain-id $CHAINID

# Set moniker and chain-id for Pouch (Moniker can be anything, chain-id must be an integer)
echo "Initializing $CHAINID..."
$CMD init $MONIKER --chain-id $CHAINID

# Change parameter token denominations
cat $CHAIN_DIR/config/genesis.json | jq '.app_state["staking"]["params"]["bond_denom"]="umaestro"' >$CHAIN_DIR/config/tmp_genesis.json && mv $CHAIN_DIR/config/tmp_genesis.json $CHAIN_DIR/config/genesis.json
cat $CHAIN_DIR/config/genesis.json | jq '.app_state["crisis"]["constant_fee"]["denom"]="umaestro"' >$CHAIN_DIR/config/tmp_genesis.json && mv $CHAIN_DIR/config/tmp_genesis.json $CHAIN_DIR/config/genesis.json
cat $CHAIN_DIR/config/genesis.json | jq '.app_state["gov"]["deposit_params"]["min_deposit"][0]["denom"]="umaestro"' >$CHAIN_DIR/config/tmp_genesis.json && mv $CHAIN_DIR/config/tmp_genesis.json $CHAIN_DIR/config/genesis.json
cat $CHAIN_DIR/config/genesis.json | jq '.app_state["mint"]["params"]["mint_denom"]="umaestro"' >$CHAIN_DIR/config/tmp_genesis.json && mv $CHAIN_DIR/config/tmp_genesis.json $CHAIN_DIR/config/genesis.json
cat $CHAIN_DIR/config/genesis.json | jq '.app_state["interchainquery"]["params"]["allow_queries"][0]="/cosmos.tx.v1beta1.Service/GetTxsEvent"' >$CHAIN_DIR/config/tmp_genesis.json && mv $CHAIN_DIR/config/tmp_genesis.json $CHAIN_DIR/config/genesis.json

# CORS
sed -i '' 's/cors_allowed_origins = \[\]/cors_allowed_origins = ["*"]/g' "$CHAIN_DIR/config/config.toml"

# Add keys
echo "Adding genesis accounts..."
echo $MNEMONIC_ALICE | $CMD keys add $KEY_ALICE --recover --keyring-backend $KEYRING
echo $MNEMONIC_RELAYER | $CMD keys add $KEY_RELAYER --recover --keyring-backend $KEYRING

# Allocate genesis accounts (cosmos formatted addresses)
echo "Creating and collecting gentx..."
$CMD add-genesis-account $KEY_ALICE 39000000000000$DENOM --keyring-backend $KEYRING
$CMD add-genesis-account $KEY_RELAYER 5500000000000$DENOM --keyring-backend $KEYRING

# Sign and collect genesis transaction
$CMD gentx $KEY_ALICE 33500000000000$DENOM --keyring-backend $KEYRING --chain-id $CHAINID
$CMD collect-gentxs

# Run this to ensure everything worked and that the genesis file is setup correctly
$CMD validate-genesis

if [[ $1 == "pending" ]]; then
    echo "pending mode is on, please wait for the first block committed."
fi

# Start the node
$CMD start \
    --log_level $LOGLEVEL \
    --minimum-gas-prices=0$DENOM \
    --api.address=tcp://localhost:$API_ADDRESS \
    --api.enable=true \
    --api.enabled-unsafe-cors=true \
    --grpc.address=localhost:$GRPC_ADDRESS \
    --grpc-web.address=localhost:$GRPC_WEB_ADDRESS \
    --p2p.laddr=tcp://0.0.0.0:$P2P_LADDR \
    --rpc.laddr=tcp://127.0.0.1:$RPC_LADDR \
    --rpc.pprof_laddr=tcp://127.0.0.1:$RPC_PPROF_LADDR