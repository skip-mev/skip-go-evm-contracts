<!-- ABOUT THE PROJECT -->
## Skip Axelar Handler



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
   git clone https://github.com/github_username/repo_name.git
   ```
2. Run tests:
   ```sh
   forge test
   ```

3. Set your private key and RPC url as environment variables:
    ```sh
   export PRIVATE_KEY=<key>
   export RPC_URL=<url>
   ```

4. Test deployment:
   ```sh
   forge script ./script/AxelarHandlerDeployment.s.sol
   ```

5. If you want to broadcast the transaction and deploy add --broadcast to the command:
   ```sh
   forge script ./script/AxelarHandlerDeployment.s.sol --broadcast
   ```