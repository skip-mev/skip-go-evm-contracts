update-abis:
	jq '.abi' AxelarHandler/out/AxelarHandler.sol/AxelarHandler.json > abi/AxelarHandler.json
	jq '.abi' AxelarHandler/out/GoFastHandler.sol/GoFastHandler.json > abi/GoFastHandler.json
	jq '.abi' CCTPRelayer/out/CCTPRelayer.sol/CCTPRelayer.json > abi/CCTPRelayer.json
	jq '.abi' EurekaHandler/out/EurekaHandler.sol/EurekaHandler.json > abi/EurekaHandler.json
	jq '.abi' SwapRouter/out/SkipGoSwapRouter.sol/SkipGoSwapRouter.json > abi/SkipGoSwapRouter.json