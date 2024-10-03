package types // noalias

import (
	"cosmossdk.io/math"
	sdk "github.com/cosmos/cosmos-sdk/types"
	stakingtypes "github.com/cosmos/cosmos-sdk/x/staking/types"
)

// StakingKeeper defines the expected staking keeper
type StakingKeeper interface {
	Delegate(ctx sdk.Context, delAddr sdk.AccAddress, bondAmt math.Int, tokenSrc stakingtypes.BondStatus, validator stakingtypes.Validator, subtractAccount bool) (newShares sdk.Dec, err error)
	GetValidator(ctx sdk.Context, addr sdk.ValAddress) (validator stakingtypes.Validator, exist bool)
	BondDenom(ctx sdk.Context) string
	GetAllValidators(ctx sdk.Context) (validators []stakingtypes.Validator)
}
