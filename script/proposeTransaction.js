const SafeApiKit = require("@safe-global/api-kit").default;
const Safe = require("@safe-global/protocol-kit").default;
const { OperationType } = require("@safe-global/types-kit");
const { ethers } = require("ethers");
const TransportNodeHid = require("@ledgerhq/hw-transport-node-hid").default;
const AppEth = require("@ledgerhq/hw-app-eth").default;
const axios = require("axios");
const fs = require("fs");

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
const OPERATION =
  OperationType.DelegateCall; /* required for MultiSendCallOnly */

if (process.argv.length < 4) {
  console.error("Usage: node script/proposeTransaction.js <TO> <DATA>");
  process.exit(1);
}
const TO = process.argv[2];
const DATA = process.argv[3];
const LOG_FILE = process.argv[4] || "/tmp/proposeTransaction.log";

if (LOG_FILE !== "stdout") {
  if (fs.existsSync(LOG_FILE)) {
    fs.truncateSync(LOG_FILE, 0);
  }
  const accessLogStream = fs.createWriteStream(LOG_FILE, { flags: "a" });
  const errorLogStream = fs.createWriteStream(LOG_FILE, { flags: "a" });

  process.stdout.write = accessLogStream.write.bind(accessLogStream);
  process.stderr.write = errorLogStream.write.bind(errorLogStream);
}

async function setupProvider() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const network = await provider.getNetwork();
  return { provider, network };
}

async function connectLedger() {
  const transport = await TransportNodeHid.create();
  const eth = new AppEth(transport);
  const owner = await eth.getAddress(LEDGER_PATH);
  return { transport, eth, owner };
}

async function createSafeProtocolKit(ownerAddress) {
  return Safe.init({
    provider: RPC_URL,
    signer: ownerAddress,
    safeAddress: OWNER,
  });
}

async function buildSafeTransaction(protocolKit) {
  return protocolKit.createTransaction({
    transactions: [
      {
        to: TO,
        value: "0",
        data: DATA,
        operation: OPERATION,
      },
    ],
  });
}

async function buildEIP712Data(safeTx, network) {
  return {
    domain: {
      chainId: BigInt(network.chainId),
      verifyingContract: OWNER,
    },
    message: { ...safeTx.data },
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
}

async function signTransaction(eth, typeData) {
  const domainSeparator = ethers.TypedDataEncoder.hashDomain(
    typeData.domain
  ).slice(2);
  const hashStruct = ethers.TypedDataEncoder.from(typeData.types)
    .hash(typeData.message)
    .slice(2);
  const signature = await eth.signEIP712HashedMessage(
    LEDGER_PATH,
    domainSeparator,
    hashStruct
  );

  const r = signature.r.padStart(64, "0");
  const s = signature.s.padStart(64, "0");
  const v = signature.v.toString(16).padStart(2, "0");
  return `0x${r}${s}${v}`;
}

async function proposeTransaction(
  apiKit,
  safeTx,
  safeTxHash,
  senderAddress,
  senderSignature
) {
  await apiKit.proposeTransaction({
    safeAddress: OWNER,
    safeTransactionData: safeTx.data,
    safeTxHash,
    senderAddress,
    senderSignature,
  });
}

async function buildExecTransactionData(safeTx, signature) {
  const safeAbi = [
    "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) public returns (bool success)",
  ];
  const iface = new ethers.Interface(safeAbi);
  return iface.encodeFunctionData("execTransaction", [
    safeTx.data.to,
    safeTx.data.value,
    safeTx.data.data,
    safeTx.data.operation,
    safeTx.data.safeTxGas,
    safeTx.data.baseGas,
    safeTx.data.gasPrice,
    safeTx.data.gasToken,
    safeTx.data.refundReceiver,
    signature,
  ]);
}

async function simulateTransaction(network, execTransactionData, sender) {
  const url = `https://api.tenderly.co/api/v1/account/${TENDERLY_ACCOUNT_NAME}/project/${TENDERLY_PROJECT_NAME}/simulate`;
  const res = await axios.post(
    url,
    {
      save: true,
      save_if_fails: true,
      simulation_type: "full",
      network_id: network.chainId.toString(),
      from: sender,
      to: OWNER,
      input: execTransactionData,
      gas: 30e6,
      state_objects: {
        [OWNER]: {
          storage: {
            // threshold = 1
            "0x0000000000000000000000000000000000000000000000000000000000000004":
              "0x0000000000000000000000000000000000000000000000000000000000000001",
          },
        },
      },
    },
    {
      headers: { "X-Access-Key": TENDERLY_ACCESS_KEY },
    }
  );

  return res.data.simulation.id;
}

function capitalize(str) {
  return str.charAt(0).toUpperCase() + str.slice(1);
}

async function listVirtualTestnets() {
  const url = `https://api.tenderly.co/api/v1/account/${TENDERLY_ACCOUNT_NAME}/project/${TENDERLY_PROJECT_NAME}/vnets`;
  const res = await axios.get(url, {
    headers: { "X-Access-Key": TENDERLY_ACCESS_KEY },
  });
  return res.data;
}

async function deleteVirtualTestnet(vnetId) {
  const url = `https://api.tenderly.co/api/v1/account/${TENDERLY_ACCOUNT_NAME}/project/${TENDERLY_PROJECT_NAME}/vnets/${vnetId}`;
  const res = await axios.delete(url, {
    headers: { "X-Access-Key": TENDERLY_ACCESS_KEY },
  });
  return res.data;
}

async function createVirtualTestnet(network, simulationId) {
  const url = `https://api.tenderly.co/api/v1/account/${TENDERLY_ACCOUNT_NAME}/project/${TENDERLY_PROJECT_NAME}/vnets`;
  const res = await axios.post(
    url,
    {
      slug: `${TENDERLY_PROJECT_NAME}-${network.name}-vnet-${simulationId}`,
      display_name: `${capitalize(
        network.name
      )} Virtual TestNet (${simulationId})`,
      fork_config: {
        network_id: Number(network.chainId),
        block_number: "latest",
      },
      virtual_network_config: {
        chain_config: {
          chain_id: Number(network.chainId),
        },
      },
      sync_state_config: {
        enabled: false, // true only on the Pro plan
      },
      explorer_page_config: {
        enabled: true,
        verification_visibility: "src",
      },
    },
    {
      headers: { "X-Access-Key": TENDERLY_ACCESS_KEY },
    }
  );

  return res.data;
}

async function sendVirtualTestnetTransaction(
  vnetId,
  adminRpcUrl,
  sender,
  execTransactionData
) {
  const stateOverride = {
    jsonrpc: "2.0",
    method: "tenderly_setStorageAt",
    params: [
      OWNER,
      "0x0000000000000000000000000000000000000000000000000000000000000004",
      "0x0000000000000000000000000000000000000000000000000000000000000001",
    ],
    id: "1",
  };
  const response = await axios.post(adminRpcUrl, stateOverride);
  console.log("State Override Response:", response.data);

  const url = `https://api.tenderly.co/api/v1/account/${TENDERLY_ACCOUNT_NAME}/project/${TENDERLY_PROJECT_NAME}/vnets/${vnetId}/transactions`;
  const res = await axios.post(
    url,
    {
      callArgs: {
        from: sender,
        to: OWNER,
        gas: `0x${(30e6).toString(16)}`,
        gasPrice: "0x0",
        value: "0x0",
        data: execTransactionData,
      },
    },
    {
      headers: { "X-Access-Key": TENDERLY_ACCESS_KEY },
    }
  );

  return res.data.tx_hash;
}

async function main() {
  const { network } = await setupProvider();
  const apiKit = new SafeApiKit({ chainId: BigInt(network.chainId) });

  const { transport, eth, owner } = await connectLedger();
  console.log("Ledger Address:", owner.address);

  const protocolKit = await createSafeProtocolKit(owner.address);
  const safeTx = await buildSafeTransaction(protocolKit);

  const safeTxHash = await protocolKit.getTransactionHash(safeTx);
  console.log("Safe Transaction Hash:", safeTxHash);

  const typeData = await buildEIP712Data(safeTx, network);
  console.log("Signing Transaction...");
  const signature = await signTransaction(eth, typeData);
  console.log("Signature:", signature);

  await proposeTransaction(
    apiKit,
    safeTx,
    safeTxHash,
    owner.address,
    signature
  );
  console.log("Transaction Proposed to Safe");

  const execTransactionData = await buildExecTransactionData(safeTx, signature);
  const simulationId = await simulateTransaction(
    network,
    execTransactionData,
    owner.address
  );
  const simulationUrl = `https://dashboard.tenderly.co/${TENDERLY_ACCOUNT_NAME}/${TENDERLY_PROJECT_NAME}/simulator/${simulationId}`;
  console.log("Simulation URL:", simulationUrl);
  const vnets = await listVirtualTestnets();
  console.log("Virtual Testnets:", vnets);
  await Promise.all(
    vnets.map(async (vnet) => {
      console.log("Deleting Virtual Testnet:", vnet.id);
      await deleteVirtualTestnet(vnet.id);
    })
  );
  const vnet = await createVirtualTestnet(network, simulationId);
  const vnetUrl = `https://dashboard.tenderly.co/${TENDERLY_ACCOUNT_NAME}/${TENDERLY_PROJECT_NAME}/testnet/${vnet.id}`;
  console.log("Virtual Testnet:", vnet);
  console.log("Virtual Testnet URL:", vnetUrl);
  const adminRpcUrl = vnet.rpcs.find((rpc) =>
    rpc.name.toLowerCase().includes("admin rpc")
  ).url;
  const publicRpcUrl = vnet.rpcs.find((rpc) =>
    rpc.name.toLowerCase().includes("public rpc")
  ).url;
  const virtualTestnetTxHash = await sendVirtualTestnetTransaction(
    vnet.id,
    adminRpcUrl,
    owner.address,
    execTransactionData
  );
  console.log("Virtual Testnet Transaction Hash:", virtualTestnetTxHash);

  const sizeMinimalistFrontendUrl = `https://size-minimalist-frontend.vercel.app/?chainId=${encodeURIComponent(
    network.chainId
  )}&rpcUrl=${encodeURIComponent(
    publicRpcUrl
  )}&blockExplorerUrl=${encodeURIComponent(vnetUrl)}`;
  console.log("Size Minimalist Frontend URL:", sizeMinimalistFrontendUrl);

  await transport.close();
}

main();
