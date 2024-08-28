import { InputTransactionData } from "@aptos-labs/wallet-adapter-react";


export type PlaceBidArguments = {
    ref: string; 
    amount: number;
};

export const placeBid = (args: PlaceBidArguments): InputTransactionData => {
  const {ref, amount } = args;
  return {
    data: {
      function: `${import.meta.env.VITE_MODULE_ADDRESS}::auction_contract::make_auction_bid`,
      functionArguments: [ref, BigInt(amount) ],
    },
  };
};


