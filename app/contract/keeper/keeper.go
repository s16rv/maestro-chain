package contract

import (
	"fmt"

	"cosmossdk.io/math"
	storetypes "github.com/cosmos/cosmos-sdk/store/types"
	sdk "github.com/cosmos/cosmos-sdk/types"

	callbacktypes "github.com/s16rv/interchain-auth/x/callbacks/types"

	clienttypes "github.com/cosmos/ibc-go/v7/modules/core/02-client/types"
	channeltypes "github.com/cosmos/ibc-go/v7/modules/core/04-channel/types"
	ibcexported "github.com/cosmos/ibc-go/v7/modules/core/exported"

	"github.com/s16rv/maestro-chain/app/contract/types"

	stakingtypes "github.com/cosmos/cosmos-sdk/x/staking/types"
	icauthtypes "github.com/s16rv/interchain-auth/x/icauth/types"
)

// MockKeeper implements callbacktypes.ContractKeeper
var _ callbacktypes.ContractKeeper = (*Keeper)(nil)

// This is a mock contract keeper used for testing. It is not wired up to any modules.
// It implements the interface functions expected by the ibccallbacks middleware
// so that it can be tested with simapp. The keeper is responsible for tracking
// two metrics:
//   - number of callbacks called per callback type
//   - stateful entry attempts
//
// The counter for callbacks allows us to ensure the correct callbacks were routed to
// and the stateful entries allows us to track state reversals or reverted state upon
// contract execution failure or out of gas errors.
type Keeper struct {
	stakingKeeper types.StakingKeeper
}

// NewKeeper creates a new mock ContractKeeper.
func NewKeeper(key storetypes.StoreKey, sk types.StakingKeeper) Keeper {
	return Keeper{
		stakingKeeper: sk,
	}
}

// IBCPacketSendCallback returns nil if the gas meter has greater than
// or equal to 500_000 gas remaining.
// This function oog panics if the gas remaining is less than 500_000.
// This function errors if the authAddress is MockCallbackUnauthorizedAddress.
func (k Keeper) IBCSendPacketCallback(
	ctx sdk.Context,
	sourcePort string,
	sourceChannel string,
	timeoutHeight clienttypes.Height,
	timeoutTimestamp uint64,
	packetData []byte,
	contractAddress string,
	packetSenderAddress string,
) error {
	ctx.Logger().Info("IBCSendPacketCallback")
	return nil
}

// IBCOnAcknowledgementPacketCallback returns nil if the gas meter has greater than
// or equal to 500_000 gas remaining.
// This function oog panics if the gas remaining is less than 500_000.
// This function errors if the authAddress is MockCallbackUnauthorizedAddress.
func (k Keeper) IBCOnAcknowledgementPacketCallback(
	ctx sdk.Context,
	packet channeltypes.Packet,
	acknowledgement []byte,
	relayer sdk.AccAddress,
	contractAddress string,
	packetSenderAddress string,
) error {
	ctx.Logger().Info("IBCOnAcknowledgementPacketCallback")
	return nil
}

// IBCOnTimeoutPacketCallback returns nil if the gas meter has greater than
// or equal to 500_000 gas remaining.
// This function oog panics if the gas remaining is less than 500_000.
// This function errors if the authAddress is MockCallbackUnauthorizedAddress.
func (k Keeper) IBCOnTimeoutPacketCallback(
	ctx sdk.Context,
	packet channeltypes.Packet,
	relayer sdk.AccAddress,
	contractAddress string,
	packetSenderAddress string,
) error {
	ctx.Logger().Info("IBCOnTimeoutPacketCallback")
	return nil
}

// IBCReceivePacketCallback returns nil if the gas meter has greater than
// or equal to 500_000 gas remaining.
// This function oog panics if the gas remaining is less than 500_000.
// This function errors if the authAddress is MockCallbackUnauthorizedAddress.
func (k Keeper) IBCReceivePacketCallback(
	ctx sdk.Context,
	packet ibcexported.PacketI,
	ack ibcexported.Acknowledgement,
	delegatorAddress, validatorAddress, amount string,
) error {
	var icauthData icauthtypes.InterchainAuthPacketData
	if err := icauthtypes.ModuleCdc.UnmarshalJSON(packet.GetData(), &icauthData); err != nil {
		return err
	}

	switch icauthData.Type {
	case icauthtypes.EXECUTE_TX:
		if err := k.processDelegateCallback(ctx, delegatorAddress, validatorAddress, amount); err != nil {
			ctx.Logger().Error(fmt.Sprintf("IBCReceivePacketCallback.processDelegateCallback: %v", err))
			return err
		}
	}

	return nil
}

func (k Keeper) processDelegateCallback(ctx sdk.Context, delegatorAddress, validatorAddress, amount string) error {
	delAddress, err := sdk.AccAddressFromBech32(delegatorAddress)
	if err != nil {
		return err
	}
	valAddress, err := sdk.ValAddressFromBech32(validatorAddress)
	if err != nil {
		return err
	}
	validator, found := k.stakingKeeper.GetValidator(ctx, valAddress)
	if !found {
		return fmt.Errorf("validator not exist: %s", validatorAddress)
	}

	bondDenom := k.stakingKeeper.BondDenom(ctx)

	coin, err := sdk.ParseCoinNormalized(amount)
	if err != nil {
		return err
	}

	if coin.Denom != bondDenom {
		return fmt.Errorf("invalid coin denomination: got %s, expected %s", coin.Denom, bondDenom)
	}

	// NOTE: source funds are always unbonded
	newShares, err := k.stakingKeeper.Delegate(ctx, delAddress, math.Int(coin.Amount), stakingtypes.Unbonded, validator, true)
	if err != nil {
		return err
	}

	ctx.Logger().Info(fmt.Sprintf("IBCReceivePacketCallback.processDelegateCallback success, new shares: %v, data: %s %s %s", newShares, delegatorAddress, validatorAddress, amount))

	return nil
}
