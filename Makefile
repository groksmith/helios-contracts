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
remove_modules:
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
	forge build

deploy_all:
	forge script ./script/DeployScript.s.sol:DeployScript --rpc-url ${RPC_URL} --broadcast -vvvv

verify_all:
	forge verify-contract 0x528Fcd0E3a36ca90C7eA05DE128e763a1FA38525 ./contracts/global/HeliosGlobals.sol:HeliosGlobals --constructor-args $(shell cast abi-encode "constructor(address)" ${HELIOS_OWNER}) --verifier-url ${VERIFIER_URL} --watch
	forge verify-contract 0xb5cA9428b37e1e70c1B2568b72e9bda619670098 ./contracts/pool/PoolFactory.sol:PoolFactory --constructor-args $(shell cast abi-encode "constructor(address)" 0x528Fcd0E3a36ca90C7eA05DE128e763a1FA38525) --verifier-url ${VERIFIER_URL} --watch
	forge verify-contract 0x9357e38C376Bb82F73194A1231B56e5BfE79EcBd ./contracts/pool/LiquidityLockerFactory.sol:LiquidityLockerFactory --constructor-args $(shell cast abi-encode "constructor()") --verifier-url ${VERIFIER_URL} --watch
	forge verify-contract 0x984ECd10B04464F6B367fB9d34A5eeccC0424Ec6 ./forge-test/mocks/MockTokenERC20.sol:MockTokenERC20 --constructor-args $(shell cast abi-encode "constructor(string memory _name, string memory _symbol)" mUSDC mUSDC) --verifier-url ${VERIFIER_URL} --watch

format:
	forge fmt

test-all:
	forge test -vvv

coverage-all:
	forge coverage --report lcov
	genhtml -o coverage_report --branch-coverage lcov.info --ignore-errors category

