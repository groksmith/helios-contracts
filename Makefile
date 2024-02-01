# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

all: clean remove install update build

# Clean the repo
clean-all:
	forge clean
	rm -rf coverage_report
	rm -rf lcov.info
	rm -rf typechain-types
	rm -rf artifacts
	rm -rf out

# Remove modules
remove-modules:
	rm -rf .gitmodules
	rm -rf .git/modules/*
	rm -rf lib
	touch .gitmodules
	git add .
	git commit -m "modules"

# Install the Modules
install:
	forge install foundry-rs/forge-std
	forge install OpenZeppelin/openzeppelin-contracts

# Update Dependencies
update:
	forge update

remap:
	forge remappings > remappings.txt

# Builds
build:
	forge clean
	forge remappings > remappings.txt
	forge build --extra-output-files abi --out ./abi

generate-abi:
	forge build --names --skip .t.sol .s.sol

deploy-all:
	forge script ./script/DeployScript.s.sol:DeployScript --rpc-url ${RPC_URL} --broadcast -vvvv

verify-all:
	forge verify-contract ${HELIOS_GLOBALS_ADDRESS} ./contracts/global/HeliosGlobals.sol:HeliosGlobals \
		--constructor-args $(shell cast abi-encode "constructor(address)" ${HELIOS_OWNER}) \
		--verifier-url ${VERIFIER_URL} --watch

	forge verify-contract ${POOL_FACTORY_ADDRESS} ./contracts/pool/PoolFactory.sol:PoolFactory \
		--constructor-args $(shell cast abi-encode "constructor(address)" ${HELIOS_GLOBALS_ADDRESS}) \
		--verifier-url ${VERIFIER_URL} --watch

	forge verify-contract ${LIQUIDITY_LOCKER_FACTORY_ADDRESS} ./contracts/pool/LiquidityLockerFactory.sol:LiquidityLockerFactory \
		--constructor-args $(shell cast abi-encode "constructor()") --verifier-url ${VERIFIER_URL} --watch

	#SKIP IN PROD
	forge verify-contract ${USDT_ADDRESS} ./forge-test/mocks/MockTokenERC20.sol:MockTokenERC20 \
		--constructor-args $(shell cast abi-encode "constructor(string memory _name, string memory _symbol)" mUSDC mUSDC) \
		--verifier-url ${VERIFIER_URL} --watch

initialize-all:
	forge script ./script/InitializeScript.s.sol:InitializeScript --rpc-url ${RPC_URL} --broadcast -vvvv

format:
	forge fmt

test-all:
	forge test -vvv

coverage-all:
	forge coverage --report lcov
	genhtml -o coverage_report --branch-coverage lcov.info --ignore-errors category

