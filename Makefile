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

deploy:
	forge create StakeContract --private-key ${PRIVATE_KEY} # --rpc-url

verify:
	forge create StakeContract --private-key ${PRIVATE_KEY} # --rpc-url

format:
	forge fmt

test-all:
	forge test -vvv

coverage-all:
	forge coverage --report lcov
	genhtml -o coverage_report --branch-coverage lcov.info --ignore-errors category

