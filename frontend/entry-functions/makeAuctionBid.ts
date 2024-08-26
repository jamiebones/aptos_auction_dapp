import { InputTransactionData } from "@aptos-labs/wallet-adapter-react";
import { MoveObjectType} from "@aptos-labs/ts-sdk";


export type MakeAuctionBidArguments = {
    auction_object: MoveObjectType; 
    bid_amount: number;

};

export const writeMessage = (args: MakeAuctionBidArguments): InputTransactionData => {
  const {auction_object, bid_amount } = args;
  return {
    data: {
      function: `${import.meta.env.VITE_MODULE_ADDRESS}::auction::make_auction_bid`,
      functionArguments: [ auction_object, bid_amount ],
    },
  };
};


