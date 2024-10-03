#!/usr/bin/make -f
VERSION := $(shell echo $(shell git describe --tags))
COMMIT := $(shell git log -1 --format='%H')
SDK_PACK := $(shell go list -m github.com/cosmos/cosmos-sdk | sed  's/ /\@/g')
BINDIR ?= $(GOPATH)/bin
SIMAPP = ./app/client
GO_VERSION=1.21.0
BUILDDIR ?= $(CURDIR)/build

GO_SYSTEM_VERSION = $(shell go version | cut -c 14- | cut -d' ' -f1 | cut -d'.' -f1-2)
REQUIRE_GO_VERSION = 1.21

export GO111MODULE = on

# process build tags
LEDGER_ENABLED ?= true
build_tags = netgo
ifeq ($(LEDGER_ENABLED),true)
  ifeq ($(OS),Windows_NT)
    GCCEXE = $(shell where gcc.exe 2> NUL)
    ifeq ($(GCCEXE),)
      $(error gcc.exe not installed for ledger support, please install or set LEDGER_ENABLED=false)
    else
      build_tags += ledger
    endif
  else
    UNAME_S = $(shell uname -s)
    ifeq ($(UNAME_S),OpenBSD)
      $(warning OpenBSD detected, disabling ledger support (https://github.com/cosmos/cosmos-sdk/issues/1988))
    else
      GCC = $(shell command -v gcc 2> /dev/null)
      ifeq ($(GCC),)
        $(error gcc not installed for ledger support, please install or set LEDGER_ENABLED=false)
      else
        build_tags += ledger
      endif
    endif
  endif
endif

build_tags += $(BUILD_TAGS)
build_tags := $(strip $(build_tags))

whitespace :=
empty = $(whitespace) $(whitespace)
comma := ,
build_tags_comma_sep := $(subst $(empty),$(comma),$(build_tags))

# process linker flags
ldflags = -X github.com/cosmos/cosmos-sdk/version.Name=maestro \
		  -X github.com/cosmos/cosmos-sdk/version.AppName=maestrod \
		  -X github.com/cosmos/cosmos-sdk/version.Version=$(VERSION) \
		  -X github.com/cosmos/cosmos-sdk/version.Commit=$(COMMIT) \
		  -X "github.com/cosmos/cosmos-sdk/version.BuildTags=$(build_tags_comma_sep)"

ifeq ($(LINK_STATICALLY),true)
	ldflags += -linkmode=external -extldflags "-Wl,-z,muldefs -static"
endif
ldflags += $(LDFLAGS)
ldflags := $(strip $(ldflags))

BUILD_FLAGS := -tags "$(build_tags_comma_sep)" -ldflags '$(ldflags)' -trimpath

# The below include contains the tools and runsim targets.
include contrib/devtools/Makefile

###############################################################################
###                              Build                                      ###
###############################################################################

check_version:
ifneq ($(GO_SYSTEM_VERSION), $(REQUIRE_GO_VERSION))
	@echo "ERROR: Go version ${REQUIRE_GO_VERSION} is required for $(VERSION) of Pouch."
	exit 1
endif

build: check_version go.sum
	mkdir -p $(BUILDDIR)/
	go build -mod=readonly $(BUILD_FLAGS) -trimpath -o $(BUILDDIR) ./...;

build-linux: check_version go.sum
	GOOS=linux GOARCH=amd64 $(MAKE) build

install: check_version go.sum
	go install -mod=readonly $(BUILD_FLAGS) ./cmd/maestrod

clean:
	rm -rf $(BUILDDIR)/*

###############################################################################
###                                Tools                                    ###
###############################################################################

go-mod-cache: go.sum
	@echo "--> Download go modules to local cache"
	@go mod download

go.sum: go.mod
	@echo "--> Ensure dependencies have not been modified"
	@go mod verify

test-unit-cov:
	@go test ./x/... ./app/... -coverprofile=coverage.out
	@bash scripts/test/exclude-from-code-coverage.sh
	go tool cover -func=coverage.out
	@rm coverage.out

###############################################################################
###                                Mocks                                 	###
###############################################################################

mock-expected-keepers:
	mockgen -source=x/callbacks/types/expected_keepers.go -destination=testutil/keeper/callbacks/mocks.go -package=callbacks
	mockgen -source=x/icauth/types/expected_keepers.go -destination=testutil/keeper/icauth/mocks.go -package=icauth

###############################################################################
###                             Local                                       ###
###############################################################################

localnet-build:
	$(MAKE) build

localnet-start:
	bash scripts/local/start.sh

localnet-clean:
	rm -rf $(HOME)/.maestrod

#############################################################################
###                             e2e                                       ###
#############################################################################
E2E_PATH=e2e

ictest-ibc-transfer-forward:
	cd $(E2E_PATH) && go test -race -v -timeout 15m -run TestIBCTransferForwardMiddleware .

ictest-ibc-transfer-forward-timeout:
	cd $(E2E_PATH) && go test -race -v -timeout 15m -run TestIBCTransferForwardTimeout .

ictest-ibc-icauth:
	cd $(E2E_PATH) && go test -race -v -timeout 15m -run TestIBCIcauth .

get-heighliner:
	git clone https://github.com/strangelove-ventures/heighliner.git
	cd heighliner && go install

local-image:
ifeq (,$(shell which heighliner))
	echo 'heighliner' binary not found. Consider running `make get-heighliner`
else
	heighliner build -c maestro --local --dockerfile cosmos --build-target "make install" --binaries "/go/bin/maestrod"
endif