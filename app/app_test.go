package app_test

import (
	"io"
	"testing"

	dbm "github.com/cometbft/cometbft-db"
	"github.com/cometbft/cometbft/libs/log"
	"github.com/cosmos/cosmos-sdk/baseapp"
	"github.com/cosmos/cosmos-sdk/client/flags"
	"github.com/cosmos/cosmos-sdk/server"
	servertypes "github.com/cosmos/cosmos-sdk/server/types"
	simtestutil "github.com/cosmos/cosmos-sdk/testutil/sims"
	simcli "github.com/cosmos/cosmos-sdk/x/simulation/client/cli"
	app "github.com/s16rv/maestro-chain/app"
	appparams "github.com/s16rv/maestro-chain/app/params"
)

func TestNew(t *testing.T) {
	appOptions := make(simtestutil.AppOptionsMap, 0)
	appOptions[flags.FlagHome] = app.DefaultNodeHome
	appOptions[server.FlagInvCheckPeriod] = simcli.FlagPeriodValue

	type args struct {
		logger             log.Logger
		db                 dbm.DB
		traceStore         io.Writer
		loadLatest         bool
		skipUpgradeHeights map[int64]bool
		homePath           string
		invCheckPeriod     uint
		encodingConfig     appparams.EncodingConfig
		appOpts            servertypes.AppOptions
		baseAppOptions     []func(*baseapp.BaseApp)
	}
	tests := []struct {
		name string
		args args
	}{
		{
			name: "return app object",
			args: args{
				log.NewNopLogger(),
				dbm.NewMemDB(),
				nil,
				true,
				map[int64]bool{},
				app.DefaultNodeHome,
				0,
				app.MakeEncodingConfig(),
				appOptions,
				[]func(*baseapp.BaseApp){
					baseapp.SetChainID("unit-test-1"),
				},
			},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			app.New(tt.args.logger, tt.args.db, tt.args.traceStore, tt.args.loadLatest, tt.args.skipUpgradeHeights, tt.args.homePath, tt.args.invCheckPeriod, tt.args.encodingConfig, tt.args.appOpts, tt.args.baseAppOptions...)
		})
	}
}
