# Helios Contracts Forge Project

## Prerequisites 

Install Just
```
https://github.com/casey/just
```

## Contracts build, test and metrics

```shell
yarn compile  // compile contarcts
yarn test     // run tests
yarn coverage // run coverage
yarn clean    // clean artefacts
yarn analyze  // run slither analyzer
yarn size     // run contract size analyzer
yarn verify   // verify contracts on etherscan
yarn export   // export contract's abi to json
```

## Core Deployment

#### Important: You should run each command step by step in the given sequence
#### Grab output of each command and use it in .env file

```shell
yarn test-deploy-globals          
yarn test-deploy-pool-factory     
yarn test-deploy-liquidity-locker
yarn test-set-variables
```

## Test pool functionality

```shell
yarn test-create-pool
yarn test-deposit
yarn test-borrow
yarn test-makePayment
yarn test-withdraw
```
