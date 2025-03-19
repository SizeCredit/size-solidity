const SafeApiKit = require("@safe-global/api-kit").default;
const Safe = require("@safe-global/protocol-kit").default;
const { OperationType } = require("@safe-global/types-kit");
const { ethers } = require("ethers");
const TransportNodeHid = require("@ledgerhq/hw-transport-node-hid").default;
const AppEth = require("@ledgerhq/hw-app-eth").default;
const axios = require("axios");

const RPC_URLS = {
  base: "https://base-mainnet.g.alchemy.com/v2/",
  mainnet: "https://eth-mainnet.g.alchemy.com/v2/",
};

const OWNER = process.env.OWNER;
const API_KEY_ALCHEMY = process.env.API_KEY_ALCHEMY;
const RPC_URL = RPC_URLS[process.env.RPC_URL] + API_KEY_ALCHEMY;
const LEDGER_PATH = process.env.LEDGER_PATH;

const TENDERLY_ACCESS_KEY = process.env.TENDERLY_ACCESS_KEY;
const TENDERLY_ACCOUNT_NAME = process.env.TENDERLY_ACCOUNT_NAME;
const TENDERLY_PROJECT_NAME = process.env.TENDERLY_PROJECT_NAME;

if (process.argv.length < 4) {
  console.error("Error: Missing required arguments. Usage: node script/proposeTransaction.js <TO> <DATA>");
  process.exit(1);
}
const TO = process.argv[2];
const DATA = process.argv[3];

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const network = await provider.getNetwork();
  const apiKit = new SafeApiKit({ chainId: BigInt(network.chainId) });

  const safeAddress = OWNER;

  const transport = await TransportNodeHid.create();
  const eth = new AppEth(transport);

  const owner1 = await eth.getAddress(LEDGER_PATH);
  console.log("owner1:", owner1);

  const protocolKit = await Safe.init({
    provider: RPC_URL,
    signer: owner1.address,
    safeAddress: safeAddress,
  });

  const safeTransactionData = {
    to: TO,
    value: "0",
    data: DATA,
    operation: OperationType.DelegateCall,
  };
  const safeTransaction = await protocolKit.createTransaction({
    transactions: [safeTransactionData],
  });
  console.log("safeTransaction:", safeTransaction);

  const safeTxHash = await protocolKit.getTransactionHash(safeTransaction);
  console.log("safeTxHash:", safeTxHash);

  const messageHex = Buffer.from(safeTxHash.slice(2), "hex").toString("hex");
  console.log("messageHex:", messageHex);

  const typeData = {
    account: owner1.address,
    domain: {
      chainId: BigInt(network.chainId),
      verifyingContract: safeAddress,
    },
    message: {
      to: safeTransaction.data.to,
      value: safeTransaction.data.value,
      data: safeTransaction.data.data,
      operation: safeTransaction.data.operation,
      safeTxGas: safeTransaction.data.safeTxGas,
      baseGas: safeTransaction.data.baseGas,
      gasPrice: safeTransaction.data.gasPrice,
      gasToken: safeTransaction.data.gasToken,
      refundReceiver: safeTransaction.data.refundReceiver,
      nonce: safeTransaction.data.nonce,
    },
    primaryType: "SafeTx",
    types: {
      SafeTx: [
        { name: "to", type: "address" },
        { name: "value", type: "uint256" },
        { name: "data", type: "bytes" },
        { name: "operation", type: "uint8" },
        { name: "safeTxGas", type: "uint256" },
        { name: "baseGas", type: "uint256" },
        { name: "gasPrice", type: "uint256" },
        { name: "gasToken", type: "address" },
        { name: "refundReceiver", type: "address" },
        { name: "nonce", type: "uint256" },
      ],
    },
  };
  console.log("typeData:", typeData);

  const domainSeparator = ethers.TypedDataEncoder.hashDomain(typeData.domain);

  const domainSeparatorHex = domainSeparator.slice(2);
  console.log("domainSeparatorHex:", domainSeparatorHex);

  const hashStruct = ethers.TypedDataEncoder.from(typeData.types).hash(
    typeData.message
  );
  const hashStructMessageHex = hashStruct.slice(2);
  console.log("hashStructMessageHex:", hashStructMessageHex);

  const signature = await eth.signEIP712HashedMessage(
    LEDGER_PATH,
    domainSeparatorHex,
    hashStructMessageHex
  );
  console.log("signature:", signature);

  const r = signature.r.padStart(64, "0");
  const s = signature.s.padStart(64, "0");
  const v = signature.v.toString(16).padStart(2, "0");
  const owner1Signature = `0x${r}${s}${v}`;
  console.log("owner1Signature:", owner1Signature);

  console.log("owner1.address:", owner1.address);

  await apiKit.proposeTransaction({
    safeAddress: safeAddress,
    safeTransactionData: safeTransaction.data,
    safeTxHash: safeTxHash,
    senderAddress: owner1.address,
    senderSignature: owner1Signature,
  });

  await transport.close();

  const gasPrice = (await provider.getFeeData()).gasPrice;
  console.log("gasPrice:", gasPrice);

  const safeAbi = [
    "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) public returns (bool success)",
  ];
  const safeInterface = new ethers.Interface(safeAbi);
  const execTransactionData = safeInterface.encodeFunctionData(
    "execTransaction",
    [
      safeTransaction.data.to,
      safeTransaction.data.value,
      safeTransaction.data.data,
      safeTransaction.data.operation,
      safeTransaction.data.safeTxGas,
      safeTransaction.data.baseGas,
      safeTransaction.data.gasPrice,
      safeTransaction.data.gasToken,
      safeTransaction.data.refundReceiver,
      owner1Signature,
    ]
  );

  const { data } = await axios.post(
    `https://api.tenderly.co/api/v1/account/${TENDERLY_ACCOUNT_NAME}/project/${TENDERLY_PROJECT_NAME}/simulate`,
    {
      save: true,
      save_if_fails: true,
      simulation_type: "full",
      network_id: network.chainId.toString(),
      from: owner1.address,
      to: safeAddress,
      input: execTransactionData,
      gas: 30e6,
      state_objects: {
        [safeAddress]: {
          storage: {
            // threshold
            "0x0000000000000000000000000000000000000000000000000000000000000004":
            // 1
              "0x0000000000000000000000000000000000000000000000000000000000000001",
          },
        },
      },
    },
    {
      headers: {
        "X-Access-Key": TENDERLY_ACCESS_KEY,
      },
    }
  );

  const simulationId = data.simulation.id;

  const simulationUrl = `https://dashboard.tenderly.co/${TENDERLY_ACCOUNT_NAME}/${TENDERLY_PROJECT_NAME}/simulator/${simulationId}`;
  console.log("Simulation URL:", simulationUrl);
}

main();
