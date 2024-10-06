#!/bin/bash
CHAINID="maestro-test-1"
CHAIN_DIR=$HOME/.maestrod
MONIKER="maestro-node"
KEYRING="test"
DENOM=umaestro

API_ADDRESS=1317
GRPC_ADDRESS=9090
GRPC_WEB_ADDRESS=9091
P2P_LADDR=26656
RPC_LADDR=26657
RPC_PPROF_LADDR=6060

# Check if the 'maestrod' command exists
if ! command -v maestrod &> /dev/null; then
    echo "Error: 'maestrod' command not found."
    exit 1  # Exit with a failure status
fi

CMD="maestrod --home $CHAIN_DIR"
CONFIG_FILE="$CHAIN_DIR/config/config.toml"
APP_FILE="$CHAIN_DIR/config/app.toml"

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

if [ -d "$CHAIN_DIR" ]; then
    echo "Error: CHAIN_DIR '$CHAIN_DIR' already exists."
    exit 1  # Exit with a failure status
fi

mkdir $CHAIN_DIR

$CMD config keyring-backend $KEYRING
$CMD config chain-id $CHAINID

# Set moniker and chain-id for Pouch (Moniker can be anything, chain-id must be an integer)
echo "Initializing $CHAINID..."
$CMD init $MONIKER --chain-id $CHAINID

# Change parameter token denominations
cat $CHAIN_DIR/config/genesis.json | jq '.app_state["staking"]["params"]["bond_denom"]="umaestro"' >$CHAIN_DIR/config/tmp_genesis.json && mv $CHAIN_DIR/config/tmp_genesis.json $CHAIN_DIR/config/genesis.json
cat $CHAIN_DIR/config/genesis.json | jq '.app_state["staking"]["params"]["unbonding_time"]="259200s"' >$CHAIN_DIR/config/tmp_genesis.json && mv $CHAIN_DIR/config/tmp_genesis.json $CHAIN_DIR/config/genesis.json # unbonding 3 days
cat $CHAIN_DIR/config/genesis.json | jq '.app_state["staking"]["params"]["max_validators"]=20' >$CHAIN_DIR/config/tmp_genesis.json && mv $CHAIN_DIR/config/tmp_genesis.json $CHAIN_DIR/config/genesis.json
cat $CHAIN_DIR/config/genesis.json | jq '.app_state["crisis"]["constant_fee"]["denom"]="umaestro"' >$CHAIN_DIR/config/tmp_genesis.json && mv $CHAIN_DIR/config/tmp_genesis.json $CHAIN_DIR/config/genesis.json
cat $CHAIN_DIR/config/genesis.json | jq '.app_state["gov"]["deposit_params"]["min_deposit"][0]["denom"]="umaestro"' >$CHAIN_DIR/config/tmp_genesis.json && mv $CHAIN_DIR/config/tmp_genesis.json $CHAIN_DIR/config/genesis.json
cat $CHAIN_DIR/config/genesis.json | jq '.app_state["gov"]["params"]["min_deposit"][0]["denom"]="umaestro"' >$CHAIN_DIR/config/tmp_genesis.json && mv $CHAIN_DIR/config/tmp_genesis.json $CHAIN_DIR/config/genesis.json
cat $CHAIN_DIR/config/genesis.json | jq '.app_state["gov"]["params"]["voting_period"]="3600s"' >$CHAIN_DIR/config/tmp_genesis.json && mv $CHAIN_DIR/config/tmp_genesis.json $CHAIN_DIR/config/genesis.json
cat $CHAIN_DIR/config/genesis.json | jq '.app_state["mint"]["params"]["mint_denom"]="umaestro"' >$CHAIN_DIR/config/tmp_genesis.json && mv $CHAIN_DIR/config/tmp_genesis.json $CHAIN_DIR/config/genesis.json

# Update config
sed -i 's/cors_allowed_origins = \[\]/cors_allowed_origins = ["*"]/g' "$CONFIG_FILE"

sed -i "s/minimum-gas-prices *= *\"[^\"]*\"/minimum-gas-prices = \"0$DENOM\"/" "$APP_FILE"
sed -i '/\[api\]/,/enable = false/s/enable = false/enable = true/' "$APP_FILE"
sed -i 's/enabled-unsafe-cors = false/enabled-unsafe-cors = true/' "$APP_FILE"

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