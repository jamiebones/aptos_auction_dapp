import { InputTransactionData } from "@aptos-labs/wallet-adapter-react";


export type CreateAuctionArguments = {
    auction_brief_description: string; 
    auction_description_url: string;
    auction_end_date: number;
};

export const createAuction = (args: CreateAuctionArguments): InputTransactionData => {
  const {auction_brief_description, auction_description_url, auction_end_date } = args;
  return {
    data: {
      function: `${import.meta.env.VITE_MODULE_ADDRESS}::auction_contract::create_new_auction`,
      functionArguments: [auction_brief_description, auction_description_url, auction_end_date ],
    },
  };
};


