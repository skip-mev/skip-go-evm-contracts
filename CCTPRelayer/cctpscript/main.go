package main

import (
	"context"
	"encoding/hex"
	"fmt"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

const (
	cctpMessageTransmitterAbiString = `[{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"caller","type":"address"},{"indexed":false,"internalType":"uint32","name":"sourceDomain","type":"uint32"},{"indexed":true,"internalType":"uint64","name":"nonce","type":"uint64"},{"indexed":false,"internalType":"bytes32","name":"sender","type":"bytes32"},{"indexed":false,"internalType":"bytes","name":"messageBody","type":"bytes"}],"name":"MessageReceived","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"bytes","name":"message","type":"bytes"}],"name":"MessageSent","type":"event"}]`
)

func main() {
	client, err := ethclient.Dial("FILL_ME_IN")
	if err != nil {
		panic(err)
	}

	messageSentABI, err := abi.JSON(strings.NewReader(cctpMessageTransmitterAbiString))
	if err != nil {
		panic(err)
	}

	mintTx := common.HexToHash("0x8486b4432432189df0e37c614ec29d1b44ed8c5cee092db80d4adc1f64a5d8fb")

	receipt, err := client.TransactionReceipt(context.Background(), mintTx)
	if err != nil {
		panic(err)
	}

	for _, log := range receipt.Logs {
		if log.Topics[0] != common.HexToHash("0x8c5261668696ce22758910d05bab8f186d6eb247ceac2af2e82c7dc17669b036") {
			continue
		}

		event := make(map[string]interface{})
		err := messageSentABI.UnpackIntoMap(event, "MessageSent", log.Data)
		if err != nil {
			panic(err)
		}

		rawMessageSentBytes := event["message"].([]byte)

		fmt.Println("TRANSFER MESSAGE:")

		fmt.Println("message bytes:")
		fmt.Println(hex.EncodeToString(rawMessageSentBytes)[2:])

		hashed := crypto.Keccak256(rawMessageSentBytes)
		messageHash := "0x" + hex.EncodeToString(hashed)

		fmt.Println("get attestation here:")
		fmt.Printf("https://iris-api.circle.com/v1/attestations/%s\n", messageHash)
	}
}
