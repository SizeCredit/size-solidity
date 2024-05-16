const { ethers, Contract } = require("ethers");

const { Defender } = require("@openzeppelin/defender-sdk");

const axios = require("axios");

const apiUrl = "https://api.binance.us/api/v3/ticker/price";

const subgraphUrl =
  "https://api.studio.thegraph.com/query/45982/size-v2-sepolia/v0.1.rc.2b";

const sizeContractAddress = "0xBa4Eb5533C57b1641d982706c20e71aBe5d5a0EB";

const lenderAddress = "0xd20baeccd9f77faa9e2c2b185f33483d7911f9c8";

const botAddress = "0x35411F58488d705A994Fc2b9766D99e6F7384ED8";


const CREATE_CREDIT_POSITION_QUERY = `
  query GetCreateCreditPosition($where: CreateCreditPosition_filter) {
    createCreditPositions(subgraphError: allow, where: $where) {
      id
      creditPositionId
      lender
      borrower
      exitPositionId
      debtPositionId
      credit
      blockNumber
      blockTimestamp
      transferFrom
    }
  }
`;

const creds = {
  relayerApiKey: "mzFCHramPtcs9vSKgSaGrMEouNphLdR7",
  relayerApiSecret:
    "3MNKysMxMvLydRHfMHr2Y93rxeyytjLpCVwJoMmrPbYmWkojmTzhbEV9ZrKjrzS4",
};
const validUntil = new Date(Date.now() + 120 * 1000).toISOString();
// console.log(validUntil)

const client = new Defender(creds);
const provider = client.relaySigner.getProvider();
const signer = client.relaySigner.getSigner(provider, {
  speed: "fast",
  validUntil,
});

let arraysDebtPositionIdToLiquidate = [];

const fetchPrice = async (symbol, maxRetries = 3) => {
  let attempts = 0;
  while (attempts < maxRetries) {
    try {
      const response = await axios.get(apiUrl, {
        params: {
          symbol: symbol,
        },
      });
      console.log(`The price of ${symbol} is: ${response.data.price}`);
      return response.data.price; // Return the price as a string
    } catch (error) {
      console.error("Error fetching price:", error.message);
      attempts++;
      if (attempts === maxRetries) {
        return null; // Return null if max retries are reached without success
      }
    }
  }
}

fetchPrice("ETHUSDT");

async function fetchPositions() {
  const response = await axios.post(subgraphUrl, {
    query: CREATE_CREDIT_POSITION_QUERY,
    variables: { where: {} },
  });
  const position = response.data.data.createCreditPositions;

  const sortedPosition = position.sort(
    (a, b) => a.blockTimestamp - b.blockTimestamp
  );

  const seTarraysDebtPositionIdToLiquidate = new Set(
    sortedPosition.map((positionId) => positionId.debtPositionId)
  );
  arraysDebtPositionIdToLiquidateWhole = Array.from(
    seTarraysDebtPositionIdToLiquidate
  );

  for (const position of arraysDebtPositionIdToLiquidateWhole) {
    const check = await checkIfLiquidatedBefore(position);
    if (check == false) {
      arraysDebtPositionIdToLiquidate.push(position);
    }
  }
  
     

  console.log("Debt Positions available", arraysDebtPositionIdToLiquidate);

  return arraysDebtPositionIdToLiquidate;
}


//change the workflow, fetch all 1 time
async function checkIfLiquidatedBefore(currentDebtPositionId) {
  try {
    const response = await axios.post(subgraphUrl, {
      query: `
        query CheckLiquidate($debtPositionId: BigInt!) {
          liquidates(where: {debtPositionId: $debtPositionId}) {
            id
            blockNumber
            blockTimestamp
            transactionHash
            transferFrom
          }
        }`,
      variables: {
        debtPositionId: currentDebtPositionId,
      },
    });

    const responseIfTrue = response.data.data.liquidates;

    return responseIfTrue.length !== 0;
  } catch (error) {
    return false;
  }
}

async function liquidatePositions(arraysDebtPositionIdToLiquidate) {
  // TODO flashloanliquidator deployment/address
  const contract = new ethers.Contract(flashLoanLiquidatorAddress, flashLoanLiquidatorAbi, signer);

  // Fetch live Ethereum price
  const ethPriceUSD = await fetchEthPrice();
  if (!ethPriceUSD) {
    console.error('Failed to fetch Ethereum price, cannot proceed with liquidation.');
    return;
  }

  for (const position of arraysDebtPositionIdToLiquidate) {
    try {
      const creditPositionId = position;
      console.log("Position ID to liquidate:", creditPositionId);

      const debtPositions = await contract.getDebtPosition(creditPositionId);
      const faceValue = debtPositions.faceValue;
      const minimumCollateralProfit = faceValue; 

      const flashLoanAsset = '0x...'; // Address of the asset to borrow, e.g., WETH or USDC
      const flashLoanAmount = faceValue; // Amount to borrow

      console.log(`Initiating flash loan for position ${creditPositionId} with amount ${flashLoanAmount}`);

      const tx = await contract.liquidatePositionWithFlashLoan(
        creditPositionId,
        minimumCollateralProfit,
        flashLoanAsset,
        flashLoanAmount
      );

      console.log("Transaction Hash:", tx.hash);
      console.log(`Flash loan liquidation initiated for position ${creditPositionId}`);
    } catch (error) {
      console.error(`Error liquidating position ID: ${creditPositionId}`, error);
    }
  }
}

async function liquidatePositions(arraysDebtPositionIdToLiquidate) {
  const contract = new ethers.Contract(sizeContractAddress, abi, signer);

    const balancesLender = await contract.getUserView(lenderAddress);
    console.log("WETH Lender", balancesLender[2].toString()/1e18);
    console.log("USDC Lender", balancesLender[3].toString()/1e6);
    console.log("Debt Lender", balancesLender[4].toString()/1e6);

    const balancesBot = await contract.getUserView(botAddress);
    console.log("WETH Bot", balancesBot[2].toString()/1e18);
    console.log("USDC Bot", balancesBot[3].toString()/1e6);
    console.log("Debt Bot", balancesBot[4].toString()/1e6); 
  
  for (const position of arraysDebtPositionIdToLiquidate) {
    try {
      creditPositionId = position;
      console.log("positionId", creditPositionId);
      const logger = await logDebtPositions(position);
      
       const debtPositions = await contract.getDebtPosition(creditPositionId);
       const facevalue = debtPositions.faceValue; //.toString(); // talk with team about it

       const usdcAmount = facevalue; //ethers.utils.parseUnits("56", 6);
       const ethPriceUSD = await fetchPrice("ETHUSDT");
       if (!ethPriceUSD) {
         console.error("Failed to fetch Ethereum price.");
         return; // Exit if the price could not be fetched
       }
       
       const ethAmount = usdcAmount
         .mul(ethers.utils.parseUnits("1", 18))
         .div(ethers.utils.parseUnits(ethPriceUSD, 6));

       const ethAmountFormatted = ethers.utils.formatUnits(ethAmount, 18);

       console.log(`face value formatted on eth ${ethAmountFormatted}`);
      
      const isPositionLiquidable = await contract.isDebtPositionLiquidatable(
        creditPositionId
      );

      console.log(isPositionLiquidable);
      if (isPositionLiquidable == true) {
        
        console.log("WETH Lender Before Liquidate", balancesLender[2].toString()/1e18);
        console.log("USDC Lender Before Liquidate", balancesLender[3].toString()/1e6);
        console.log("Debt Lender Before Liquidate", balancesLender[4].toString()/1e6);

        console.log("WETH Bot Before Liquidate", balancesBot[2].toString()/1e18);
        console.log("USDC Bot Before Liquidate", balancesBot[3].toString()/1e6);
        console.log("Debt Bot Before Liquidate", balancesBot[4].toString()/1e6);
        
        const debtPositions = await contract.getDebtPosition(creditPositionId);
        const facevalue = debtPositions.faceValue.toString() * 1e6; // talk with team about it
        const collateral = debtPositions.borrower.toString();
        console.log(collateral);
        let lender = "0xd20baeccd9f77faa9e2c2b185f33483d7911f9c8";
        let minimumCollateralProfit = facevalue;
        let minAPR = 0;

        params = [
          creditPositionId,
          lender,
          minimumCollateralProfit,
          new Date(Date.now() / 1000 + 1440).getTime(),
          minAPR,
        ];

        const liquidate = await contract.liquidateWithReplacement(params);
        console.log(liquidate);
        
        console.log("WETH Lender After Liquidate", balancesLender[2].toString()/1e18);
        console.log("USDC Lender After Liquidate", balancesLender[3].toString()/1e6);
        console.log("Debt Lender After Liquidate", balancesLender[4].toString()/1e6);

        console.log("WETH Bot After Liquidate", balancesBot[2].toString()/1e18);
        console.log("USDC Bot After Liquidate", balancesBot[3].toString()/1e6);
        console.log("Debt Bot After Liquidate", balancesBot[4].toString()/1e6);     
      }
    } catch (error) {
      console.error(
        `Error liquidate creditPositionId: ${creditPositionId}`,
        error
      );
    }
  }
}


async function logDebtPositions(position) {
  const contract = new ethers.Contract(sizeContractAddress, abi, signer);
  try {
    
      const debtPositions = await contract.getDebtPosition(position);
      console.log("Loan Index:", position);
      console.log("Lender Address:", debtPositions.lender);
      console.log("Borrower Address:", debtPositions.borrower);
      console.log("Issuance Value:", debtPositions.issuanceValue.toString());
      console.log("Face Value:", debtPositions.faceValue.toString());
      console.log("Start Date:", new Date(debtPositions.startDate * 1000));
      console.log("Due Date:", new Date(debtPositions.dueDate * 1000));
      const dueDate = new Date(debtPositions.dueDate * 1000);
      console.log("Date now", new Date(Date.now()));
      const currentDate = new Date();
      if (dueDate < currentDate) {
        console.log("The due date is before the current date.");
      } else {
        console.log("The due date is not before the current date.");
      }
    
  } catch (error) {
    console.error("Error in logger:", error);
 }
}

 exports.handler = async function (event, context) {

  try {
    const sortedPosition = await fetchPositions();
    

    const isUserLiquidatable = await liquidatePositions(sortedPosition);

    console.log(isUserLiquidatable);
    console.log("Completed processing check if position are Liquidable");
  } catch (error) {
    console.error("Error in Autotask:", error);
  }
}


const abi = [
  {
    type: "function",
    name: "borrowAsLimitOrder",
    inputs: [
      {
        name: "params",
        type: "tuple",
        internalType: "struct BorrowAsLimitOrderParams",
        components: [
          {
            name: "openingLimitBorrowCR",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "curveRelativeTime",
            type: "tuple",
            internalType: "struct YieldCurve",
            components: [
              {
                name: "maturities",
                type: "uint256[]",
                internalType: "uint256[]",
              },
              {
                name: "aprs",
                type: "int256[]",
                internalType: "int256[]",
              },
              {
                name: "marketRateMultipliers",
                type: "uint256[]",
                internalType: "uint256[]",
              },
            ],
          },
        ],
      },
    ],
    outputs: [],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "borrowAsMarketOrder",
    inputs: [
      {
        name: "params",
        type: "tuple",
        internalType: "struct BorrowAsMarketOrderParams",
        components: [
          { name: "lender", type: "address", internalType: "address" },
          { name: "amount", type: "uint256", internalType: "uint256" },
          { name: "dueDate", type: "uint256", internalType: "uint256" },
          {
            name: "deadline",
            type: "uint256",
            internalType: "uint256",
          },
          { name: "maxAPR", type: "uint256", internalType: "uint256" },
          { name: "exactAmountIn", type: "bool", internalType: "bool" },
          {
            name: "receivableCreditPositionIds",
            type: "uint256[]",
            internalType: "uint256[]",
          },
        ],
      },
    ],
    outputs: [],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "borrowerExit",
    inputs: [
      {
        name: "params",
        type: "tuple",
        internalType: "struct BorrowerExitParams",
        components: [
          {
            name: "debtPositionId",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "borrowerToExitTo",
            type: "address",
            internalType: "address",
          },
          {
            name: "deadline",
            type: "uint256",
            internalType: "uint256",
          },
          { name: "minAPR", type: "uint256", internalType: "uint256" },
        ],
      },
    ],
    outputs: [],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "buyMarketCredit",
    inputs: [
      {
        name: "params",
        type: "tuple",
        internalType: "struct BuyMarketCreditParams",
        components: [
          {
            name: "creditPositionId",
            type: "uint256",
            internalType: "uint256",
          },
          { name: "amount", type: "uint256", internalType: "uint256" },
          {
            name: "deadline",
            type: "uint256",
            internalType: "uint256",
          },
          { name: "maxAPR", type: "uint256", internalType: "uint256" },
          { name: "exactAmountIn", type: "bool", internalType: "bool" },
        ],
      },
    ],
    outputs: [],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "claim",
    inputs: [
      {
        name: "params",
        type: "tuple",
        internalType: "struct ClaimParams",
        components: [
          {
            name: "creditPositionId",
            type: "uint256",
            internalType: "uint256",
          },
        ],
      },
    ],
    outputs: [],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "collateralRatio",
    inputs: [{ name: "user", type: "address", internalType: "address" }],
    outputs: [{ name: "", type: "uint256", internalType: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "compensate",
    inputs: [
      {
        name: "params",
        type: "tuple",
        internalType: "struct CompensateParams",
        components: [
          {
            name: "creditPositionWithDebtToRepayId",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "creditPositionToCompensateId",
            type: "uint256",
            internalType: "uint256",
          },
          { name: "amount", type: "uint256", internalType: "uint256" },
        ],
      },
    ],
    outputs: [],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "data",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "tuple",
        internalType: "struct DataView",
        components: [
          {
            name: "nextDebtPositionId",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "nextCreditPositionId",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "underlyingCollateralToken",
            type: "address",
            internalType: "contract IERC20Metadata",
          },
          {
            name: "underlyingBorrowToken",
            type: "address",
            internalType: "contract IERC20Metadata",
          },
          {
            name: "variablePool",
            type: "address",
            internalType: "contract IPool",
          },
          {
            name: "collateralToken",
            type: "address",
            internalType: "contract NonTransferrableToken",
          },
          {
            name: "borrowAToken",
            type: "address",
            internalType: "contract IAToken",
          },
          {
            name: "debtToken",
            type: "address",
            internalType: "contract NonTransferrableToken",
          },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "debtTokenAmountToCollateralTokenAmount",
    inputs: [
      {
        name: "borrowATokenAmount",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [{ name: "", type: "uint256", internalType: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "deposit",
    inputs: [
      {
        name: "params",
        type: "tuple",
        internalType: "struct DepositParams",
        components: [
          { name: "token", type: "address", internalType: "address" },
          { name: "amount", type: "uint256", internalType: "uint256" },
          { name: "to", type: "address", internalType: "address" },
        ],
      },
    ],
    outputs: [],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "feeConfig",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "tuple",
        internalType: "struct InitializeFeeConfigParams",
        components: [
          {
            name: "repayFeeAPR",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "earlyLenderExitFee",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "earlyBorrowerExitFee",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "collateralLiquidatorPercent",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "collateralProtocolPercent",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "overdueLiquidatorReward",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "overdueColLiquidatorPercent",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "overdueColProtocolPercent",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "feeRecipient",
            type: "address",
            internalType: "address",
          },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getAPR",
    inputs: [
      {
        name: "debtPositionId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [{ name: "", type: "uint256", internalType: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getBorrowOfferAPR",
    inputs: [
      { name: "borrower", type: "address", internalType: "address" },
      { name: "dueDate", type: "uint256", internalType: "uint256" },
    ],
    outputs: [{ name: "", type: "uint256", internalType: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getCreditPosition",
    inputs: [
      {
        name: "creditPositionId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [
      {
        name: "",
        type: "tuple",
        internalType: "struct CreditPosition",
        components: [
          { name: "lender", type: "address", internalType: "address" },
          { name: "forSale", type: "bool", internalType: "bool" },
          { name: "credit", type: "uint256", internalType: "uint256" },
          {
            name: "debtPositionId",
            type: "uint256",
            internalType: "uint256",
          },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getCreditPositionProRataAssignedCollateral",
    inputs: [
      {
        name: "creditPositionId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [{ name: "", type: "uint256", internalType: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getDebtPosition",
    inputs: [
      {
        name: "debtPositionId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [
      {
        name: "",
        type: "tuple",
        internalType: "struct DebtPosition",
        components: [
          { name: "lender", type: "address", internalType: "address" },
          {
            name: "borrower",
            type: "address",
            internalType: "address",
          },
          {
            name: "issuanceValue",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "faceValue",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "repayFee",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "overdueLiquidatorReward",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "startDate",
            type: "uint256",
            internalType: "uint256",
          },
          { name: "dueDate", type: "uint256", internalType: "uint256" },
          {
            name: "liquidityIndexAtRepayment",
            type: "uint256",
            internalType: "uint256",
          },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getDebtPositionAssignedCollateral",
    inputs: [
      {
        name: "debtPositionId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [{ name: "", type: "uint256", internalType: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getDueDateDebt",
    inputs: [
      {
        name: "debtPositionId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [{ name: "", type: "uint256", internalType: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getLoanOfferAPR",
    inputs: [
      { name: "lender", type: "address", internalType: "address" },
      { name: "dueDate", type: "uint256", internalType: "uint256" },
    ],
    outputs: [{ name: "", type: "uint256", internalType: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getLoanStatus",
    inputs: [{ name: "positionId", type: "uint256", internalType: "uint256" }],
    outputs: [{ name: "", type: "uint8", internalType: "enum LoanStatus" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getOverdueDebt",
    inputs: [
      {
        name: "debtPositionId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [{ name: "", type: "uint256", internalType: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getPositionsCount",
    inputs: [],
    outputs: [
      { name: "", type: "uint256", internalType: "uint256" },
      { name: "", type: "uint256", internalType: "uint256" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getRoleAdmin",
    inputs: [{ name: "role", type: "bytes32", internalType: "bytes32" }],
    outputs: [{ name: "", type: "bytes32", internalType: "bytes32" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getUserView",
    inputs: [{ name: "user", type: "address", internalType: "address" }],
    outputs: [
      {
        name: "",
        type: "tuple",
        internalType: "struct UserView",
        components: [
          {
            name: "user",
            type: "tuple",
            internalType: "struct User",
            components: [
              {
                name: "loanOffer",
                type: "tuple",
                internalType: "struct LoanOffer",
                components: [
                  {
                    name: "maxDueDate",
                    type: "uint256",
                    internalType: "uint256",
                  },
                  {
                    name: "curveRelativeTime",
                    type: "tuple",
                    internalType: "struct YieldCurve",
                    components: [
                      {
                        name: "maturities",
                        type: "uint256[]",
                        internalType: "uint256[]",
                      },
                      {
                        name: "aprs",
                        type: "int256[]",
                        internalType: "int256[]",
                      },
                      {
                        name: "marketRateMultipliers",
                        type: "uint256[]",
                        internalType: "uint256[]",
                      },
                    ],
                  },
                ],
              },
              {
                name: "borrowOffer",
                type: "tuple",
                internalType: "struct BorrowOffer",
                components: [
                  {
                    name: "openingLimitBorrowCR",
                    type: "uint256",
                    internalType: "uint256",
                  },
                  {
                    name: "curveRelativeTime",
                    type: "tuple",
                    internalType: "struct YieldCurve",
                    components: [
                      {
                        name: "maturities",
                        type: "uint256[]",
                        internalType: "uint256[]",
                      },
                      {
                        name: "aprs",
                        type: "int256[]",
                        internalType: "int256[]",
                      },
                      {
                        name: "marketRateMultipliers",
                        type: "uint256[]",
                        internalType: "uint256[]",
                      },
                    ],
                  },
                ],
              },
              {
                name: "scaledBorrowATokenBalance",
                type: "uint256",
                internalType: "uint256",
              },
              {
                name: "creditPositionsForSaleDisabled",
                type: "bool",
                internalType: "bool",
              },
            ],
          },
          { name: "account", type: "address", internalType: "address" },
          {
            name: "collateralTokenBalance",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "borrowATokenBalance",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "debtBalance",
            type: "uint256",
            internalType: "uint256",
          },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "grantRole",
    inputs: [
      { name: "role", type: "bytes32", internalType: "bytes32" },
      { name: "account", type: "address", internalType: "address" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "hasRole",
    inputs: [
      { name: "role", type: "bytes32", internalType: "bytes32" },
      { name: "account", type: "address", internalType: "address" },
    ],
    outputs: [{ name: "", type: "bool", internalType: "bool" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "initialize",
    inputs: [
      { name: "owner", type: "address", internalType: "address" },
      {
        name: "f",
        type: "tuple",
        internalType: "struct InitializeFeeConfigParams",
        components: [
          {
            name: "repayFeeAPR",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "earlyLenderExitFee",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "earlyBorrowerExitFee",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "collateralLiquidatorPercent",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "collateralProtocolPercent",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "overdueLiquidatorReward",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "overdueColLiquidatorPercent",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "overdueColProtocolPercent",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "feeRecipient",
            type: "address",
            internalType: "address",
          },
        ],
      },
      {
        name: "r",
        type: "tuple",
        internalType: "struct InitializeRiskConfigParams",
        components: [
          {
            name: "crOpening",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "crLiquidation",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "minimumCreditBorrowAToken",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "collateralTokenCap",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "borrowATokenCap",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "debtTokenCap",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "minimumMaturity",
            type: "uint256",
            internalType: "uint256",
          },
        ],
      },
      {
        name: "o",
        type: "tuple",
        internalType: "struct InitializeOracleParams",
        components: [
          {
            name: "priceFeed",
            type: "address",
            internalType: "address",
          },
          {
            name: "variablePoolBorrowRateFeed",
            type: "address",
            internalType: "address",
          },
        ],
      },
      {
        name: "d",
        type: "tuple",
        internalType: "struct InitializeDataParams",
        components: [
          { name: "weth", type: "address", internalType: "address" },
          {
            name: "underlyingCollateralToken",
            type: "address",
            internalType: "address",
          },
          {
            name: "underlyingBorrowToken",
            type: "address",
            internalType: "address",
          },
          {
            name: "variablePool",
            type: "address",
            internalType: "address",
          },
        ],
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "isCreditPositionId",
    inputs: [
      {
        name: "creditPositionId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [{ name: "", type: "bool", internalType: "bool" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "isDebtPositionId",
    inputs: [
      {
        name: "debtPositionId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [{ name: "", type: "bool", internalType: "bool" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "isDebtPositionLiquidatable",
    inputs: [
      {
        name: "debtPositionId",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [{ name: "", type: "bool", internalType: "bool" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "isUserUnderwater",
    inputs: [{ name: "user", type: "address", internalType: "address" }],
    outputs: [{ name: "", type: "bool", internalType: "bool" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "lendAsLimitOrder",
    inputs: [
      {
        name: "params",
        type: "tuple",
        internalType: "struct LendAsLimitOrderParams",
        components: [
          {
            name: "maxDueDate",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "curveRelativeTime",
            type: "tuple",
            internalType: "struct YieldCurve",
            components: [
              {
                name: "maturities",
                type: "uint256[]",
                internalType: "uint256[]",
              },
              {
                name: "aprs",
                type: "int256[]",
                internalType: "int256[]",
              },
              {
                name: "marketRateMultipliers",
                type: "uint256[]",
                internalType: "uint256[]",
              },
            ],
          },
        ],
      },
    ],
    outputs: [],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "lendAsMarketOrder",
    inputs: [
      {
        name: "params",
        type: "tuple",
        internalType: "struct LendAsMarketOrderParams",
        components: [
          {
            name: "borrower",
            type: "address",
            internalType: "address",
          },
          { name: "dueDate", type: "uint256", internalType: "uint256" },
          { name: "amount", type: "uint256", internalType: "uint256" },
          {
            name: "deadline",
            type: "uint256",
            internalType: "uint256",
          },
          { name: "minAPR", type: "uint256", internalType: "uint256" },
          { name: "exactAmountIn", type: "bool", internalType: "bool" },
        ],
      },
    ],
    outputs: [],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "liquidate",
    inputs: [
      {
        name: "params",
        type: "tuple",
        internalType: "struct LiquidateParams",
        components: [
          {
            name: "debtPositionId",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "minimumCollateralProfit",
            type: "uint256",
            internalType: "uint256",
          },
        ],
      },
    ],
    outputs: [
      {
        name: "liquidatorProfitCollateralAsset",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "liquidateWithReplacement",
    inputs: [
      {
        name: "params",
        type: "tuple",
        internalType: "struct LiquidateWithReplacementParams",
        components: [
          {
            name: "debtPositionId",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "borrower",
            type: "address",
            internalType: "address",
          },
          {
            name: "minimumCollateralProfit",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "deadline",
            type: "uint256",
            internalType: "uint256",
          },
          { name: "minAPR", type: "uint256", internalType: "uint256" },
        ],
      },
    ],
    outputs: [
      {
        name: "liquidatorProfitCollateralAsset",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "liquidatorProfitBorrowAsset",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "multicall",
    inputs: [{ name: "data", type: "bytes[]", internalType: "bytes[]" }],
    outputs: [{ name: "results", type: "bytes[]", internalType: "bytes[]" }],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "oracle",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "tuple",
        internalType: "struct InitializeOracleParams",
        components: [
          {
            name: "priceFeed",
            type: "address",
            internalType: "address",
          },
          {
            name: "variablePoolBorrowRateFeed",
            type: "address",
            internalType: "address",
          },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "pause",
    inputs: [],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "paused",
    inputs: [],
    outputs: [{ name: "", type: "bool", internalType: "bool" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "proxiableUUID",
    inputs: [],
    outputs: [{ name: "", type: "bytes32", internalType: "bytes32" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "renounceRole",
    inputs: [
      { name: "role", type: "bytes32", internalType: "bytes32" },
      {
        name: "callerConfirmation",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "repay",
    inputs: [
      {
        name: "params",
        type: "tuple",
        internalType: "struct RepayParams",
        components: [
          {
            name: "debtPositionId",
            type: "uint256",
            internalType: "uint256",
          },
        ],
      },
    ],
    outputs: [],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "repayFee",
    inputs: [
      {
        name: "issuanceValue",
        type: "uint256",
        internalType: "uint256",
      },
      { name: "startDate", type: "uint256", internalType: "uint256" },
      { name: "dueDate", type: "uint256", internalType: "uint256" },
      { name: "repayFeeAPR", type: "uint256", internalType: "uint256" },
    ],
    outputs: [{ name: "", type: "uint256", internalType: "uint256" }],
    stateMutability: "pure",
  },
  {
    type: "function",
    name: "revokeRole",
    inputs: [
      { name: "role", type: "bytes32", internalType: "bytes32" },
      { name: "account", type: "address", internalType: "address" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "riskConfig",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "tuple",
        internalType: "struct InitializeRiskConfigParams",
        components: [
          {
            name: "crOpening",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "crLiquidation",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "minimumCreditBorrowAToken",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "collateralTokenCap",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "borrowATokenCap",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "debtTokenCap",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "minimumMaturity",
            type: "uint256",
            internalType: "uint256",
          },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "selfLiquidate",
    inputs: [
      {
        name: "params",
        type: "tuple",
        internalType: "struct SelfLiquidateParams",
        components: [
          {
            name: "creditPositionId",
            type: "uint256",
            internalType: "uint256",
          },
        ],
      },
    ],
    outputs: [],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "setCreditForSale",
    inputs: [
      {
        name: "params",
        type: "tuple",
        internalType: "struct SetCreditForSaleParams",
        components: [
          {
            name: "creditPositionsForSaleDisabled",
            type: "bool",
            internalType: "bool",
          },
          { name: "forSale", type: "bool", internalType: "bool" },
          {
            name: "creditPositionIds",
            type: "uint256[]",
            internalType: "uint256[]",
          },
        ],
      },
    ],
    outputs: [],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "supportsInterface",
    inputs: [{ name: "interfaceId", type: "bytes4", internalType: "bytes4" }],
    outputs: [{ name: "", type: "bool", internalType: "bool" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "unpause",
    inputs: [],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "updateConfig",
    inputs: [
      {
        name: "params",
        type: "tuple",
        internalType: "struct UpdateConfigParams",
        components: [
          { name: "key", type: "string", internalType: "string" },
          { name: "value", type: "uint256", internalType: "uint256" },
        ],
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "upgradeToAndCall",
    inputs: [
      {
        name: "newImplementation",
        type: "address",
        internalType: "address",
      },
      { name: "data", type: "bytes", internalType: "bytes" },
    ],
    outputs: [],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "withdraw",
    inputs: [
      {
        name: "params",
        type: "tuple",
        internalType: "struct WithdrawParams",
        components: [
          { name: "token", type: "address", internalType: "address" },
          { name: "amount", type: "uint256", internalType: "uint256" },
          { name: "to", type: "address", internalType: "address" },
        ],
      },
    ],
    outputs: [],
    stateMutability: "payable",
  },
  {
    type: "event",
    name: "Initialized",
    inputs: [
      {
        name: "version",
        type: "uint64",
        indexed: false,
        internalType: "uint64",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "Paused",
    inputs: [
      {
        name: "account",
        type: "address",
        indexed: false,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "RoleAdminChanged",
    inputs: [
      {
        name: "role",
        type: "bytes32",
        indexed: true,
        internalType: "bytes32",
      },
      {
        name: "previousAdminRole",
        type: "bytes32",
        indexed: true,
        internalType: "bytes32",
      },
      {
        name: "newAdminRole",
        type: "bytes32",
        indexed: true,
        internalType: "bytes32",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "RoleGranted",
    inputs: [
      {
        name: "role",
        type: "bytes32",
        indexed: true,
        internalType: "bytes32",
      },
      {
        name: "account",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "sender",
        type: "address",
        indexed: true,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "RoleRevoked",
    inputs: [
      {
        name: "role",
        type: "bytes32",
        indexed: true,
        internalType: "bytes32",
      },
      {
        name: "account",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "sender",
        type: "address",
        indexed: true,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "Unpaused",
    inputs: [
      {
        name: "account",
        type: "address",
        indexed: false,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "Upgraded",
    inputs: [
      {
        name: "implementation",
        type: "address",
        indexed: true,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  { type: "error", name: "AccessControlBadConfirmation", inputs: [] },
  {
    type: "error",
    name: "AccessControlUnauthorizedAccount",
    inputs: [
      { name: "account", type: "address", internalType: "address" },
      { name: "neededRole", type: "bytes32", internalType: "bytes32" },
    ],
  },
  {
    type: "error",
    name: "AddressEmptyCode",
    inputs: [{ name: "target", type: "address", internalType: "address" }],
  },
  {
    type: "error",
    name: "ERC1967InvalidImplementation",
    inputs: [
      {
        name: "implementation",
        type: "address",
        internalType: "address",
      },
    ],
  },
  { type: "error", name: "ERC1967NonPayable", inputs: [] },
  { type: "error", name: "EnforcedPause", inputs: [] },
  { type: "error", name: "ExpectedPause", inputs: [] },
  { type: "error", name: "FailedInnerCall", inputs: [] },
  { type: "error", name: "InvalidInitialization", inputs: [] },
  { type: "error", name: "NULL_OFFER", inputs: [] },
  { type: "error", name: "NotInitializing", inputs: [] },
  {
    type: "error",
    name: "PAST_DUE_DATE",
    inputs: [{ name: "dueDate", type: "uint256", internalType: "uint256" }],
  },
  { type: "error", name: "UUPSUnauthorizedCallContext", inputs: [] },
  {
    type: "error",
    name: "UUPSUnsupportedProxiableUUID",
    inputs: [{ name: "slot", type: "bytes32", internalType: "bytes32" }],
  },
];
