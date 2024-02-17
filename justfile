#!/usr/bin/env just --justfile

# load .env file
set dotenv-load

# pass recipe args as positional arguments to commands
set positional-arguments

set export

RPC_URL := env_var_or_default("RPC_URL", "")
VERIFIER_URL := env_var_or_default("VERIFIER_URL", "")
HELIOS_OWNER := env_var_or_default("HELIOS_OWNER", "")
HELIOS_GLOBALS_ADDRESS := env_var_or_default("HELIOS_GLOBALS_ADDRESS", "")
POOL_FACTORY_ADDRESS := env_var_or_default("POOL_FACTORY_ADDRESS", "")
USDT_ADDRESS := env_var_or_default("USDT_ADDRESS", "")

_default:
  just --list

# utility functions
start_time := `date +%s`
_timer:
    @echo "Task executed in $(($(date +%s) - {{ start_time }})) seconds"

clean-all: && _timer
	forge clean
	rm -rf lcov.info
	rm -rf crytic-export
	rm -rf tests-results
	rm -rf output

remove-modules: && _timer
	rm -rf .gitmodules
	rm -rf .git/modules/*
	rm -rf lib
	touch .gitmodules
	git add .
	git commit -m "modules"

# Install the Modules
install: && _timer
	forge install foundry-rs/forge-std
	forge install OpenZeppelin/openzeppelin-contracts

# Update Dependencies
update: && _timer
	forge update

remap: && _timer
	forge remappings > remappings.txt

# Builds
generate-abi: && _timer
    forge clean
    forge build --names --skip .t.sol .s.sol --extra-output-files abi --out output/abi

deploy-all: && _timer
	forge script ./script/DeployScript.s.sol:DeployScript --rpc-url {{ RPC_URL }} --broadcast -vvvv

verify-all: && _timer
	forge verify-contract {{ HELIOS_GLOBALS_ADDRESS }} ./contracts/global/HeliosGlobals.sol:HeliosGlobals \
		--constructor-args `cast abi-encode "constructor(address)" {{ HELIOS_OWNER }}` \
		--verifier-url {{ VERIFIER_URL }} --watch

	forge verify-contract {{ POOL_FACTORY_ADDRESS }} ./contracts/pool/PoolFactory.sol:PoolFactory \
		--constructor-args `cast abi-encode "constructor(address)" {{ HELIOS_GLOBALS_ADDRESS }}` \
		--verifier-url {{ VERIFIER_URL }} --watch

	#SKIP IN PROD
	forge verify-contract {{ USDT_ADDRESS }} ./tests/mocks/MockTokenERC20.sol:MockTokenERC20 \
		--constructor-args `cast abi-encode "constructor(string memory _name, string memory _symbol)" mUSDC mUSDC` \
		--verifier-url {{ VERIFIER_URL }} --watch

initialize-all: && _timer
	forge script ./script/InitializeScript.s.sol:InitializeScript --rpc-url {{ RPC_URL }} --broadcast -vvvv

format: && _timer
	forge fmt

build: && _timer
	forge clean
	forge remappings > remappings.txt
	forge build --names --sizes

test-all: && _timer
	forge test -vvvvv

test-one: && _timer
	forge test -vvvvv --match-contract PoolLibrary

test-echidna: && _timer
    echidna ./tests/echidna/*.sol --contract BlendedPoolEchidna --config echidna.yaml

test-gas: && _timer
    forge test --gas-report

coverage-all: && _timer
	forge coverage --report lcov
	genhtml -o tests-results/coverage_report --branch-coverage lcov.info --ignore-errors category