/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumber,
  BytesLike,
  CallOverrides,
  PopulatedTransaction,
  Signer,
  utils,
} from "ethers";
import type { FunctionFragment, Result } from "@ethersproject/abi";
import type { Listener, Provider } from "@ethersproject/providers";
import type {
  TypedEventFilter,
  TypedEvent,
  TypedListener,
  OnEvent,
} from "./common";

export interface MarketBorrowRateFeedInterface extends utils.Interface {
  functions: {
    "asset()": FunctionFragment;
    "getMarketBorrowRate()": FunctionFragment;
    "pool()": FunctionFragment;
  };

  getFunction(
    nameOrSignatureOrTopic: "asset" | "getMarketBorrowRate" | "pool"
  ): FunctionFragment;

  encodeFunctionData(functionFragment: "asset", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "getMarketBorrowRate",
    values?: undefined
  ): string;
  encodeFunctionData(functionFragment: "pool", values?: undefined): string;

  decodeFunctionResult(functionFragment: "asset", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "getMarketBorrowRate",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "pool", data: BytesLike): Result;

  events: {};
}

export interface MarketBorrowRateFeed extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: MarketBorrowRateFeedInterface;

  queryFilter<TEvent extends TypedEvent>(
    event: TypedEventFilter<TEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TEvent>>;

  listeners<TEvent extends TypedEvent>(
    eventFilter?: TypedEventFilter<TEvent>
  ): Array<TypedListener<TEvent>>;
  listeners(eventName?: string): Array<Listener>;
  removeAllListeners<TEvent extends TypedEvent>(
    eventFilter: TypedEventFilter<TEvent>
  ): this;
  removeAllListeners(eventName?: string): this;
  off: OnEvent<this>;
  on: OnEvent<this>;
  once: OnEvent<this>;
  removeListener: OnEvent<this>;

  functions: {
    asset(overrides?: CallOverrides): Promise<[string]>;

    getMarketBorrowRate(overrides?: CallOverrides): Promise<[BigNumber]>;

    pool(overrides?: CallOverrides): Promise<[string]>;
  };

  asset(overrides?: CallOverrides): Promise<string>;

  getMarketBorrowRate(overrides?: CallOverrides): Promise<BigNumber>;

  pool(overrides?: CallOverrides): Promise<string>;

  callStatic: {
    asset(overrides?: CallOverrides): Promise<string>;

    getMarketBorrowRate(overrides?: CallOverrides): Promise<BigNumber>;

    pool(overrides?: CallOverrides): Promise<string>;
  };

  filters: {};

  estimateGas: {
    asset(overrides?: CallOverrides): Promise<BigNumber>;

    getMarketBorrowRate(overrides?: CallOverrides): Promise<BigNumber>;

    pool(overrides?: CallOverrides): Promise<BigNumber>;
  };

  populateTransaction: {
    asset(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    getMarketBorrowRate(
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    pool(overrides?: CallOverrides): Promise<PopulatedTransaction>;
  };
}