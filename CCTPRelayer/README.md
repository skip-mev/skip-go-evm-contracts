<!-- ABOUT THE PROJECT -->
## Skip CCTP Relayer



<!-- GETTING STARTED -->
## Getting Started

### Prerequisites
In order to build and run the project both solidity and foundry are required:

* solidity
  ```sh
  npm install -g solc
  ```
* foundry
  ```sh
  curl -L https://foundry.paradigm.xyz | bash
  foundryup
  ```

### Usage

1. Clone the repo
   ```sh
   git clone https://github.com/skip-mev/skip-api-evm-contracts
   ```
2. Run tests:
   ```sh
   cd ./CTTPRelayer
   forge test
   ```

3. Set your RPC urls as environment variables for tests to work:
    ```sh
   export PRIVATE_KEY=<key>
   export RPC_URL=<url>
   ```

4. Test deployment:
   ```sh
   forge script ./script/Deployment.s.sol --fork-url "RPC URL" --private-key "DEPLOYMENT ACCOUNT PRIVATE KEY"
   ```

5. If you want to broadcast the transaction and deploy add --broadcast to the command:
   ```sh
   forge script ./script/Deployment.s.sol --fork-url "RPC URL" --private-key "DEPLOYMENT ACCOUNT PRIVATE KEY" --broadcast
   ```