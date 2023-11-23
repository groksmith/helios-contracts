# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

all: clean remove install update build

# Clean the repo
clean-all:
	forge clean

# Remove modules
remove:
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

deploy:
	forge create StakeContract --private-key ${PRIVATE_KEY} # --rpc-url

format:
	forge fmt

test-all:
	forge test -vvvvv

coverage-all:
	forge coverage
