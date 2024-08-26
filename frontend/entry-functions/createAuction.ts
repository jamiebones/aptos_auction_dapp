import { InputTransactionData } from "@aptos-labs/wallet-adapter-react";


export type CreateAuctionArguments = {
    auction_brief_description: string; 
    auction_description_url: string;
    auction_end_date: number;
};

export const writeMessage = (args: CreateAuctionArguments): InputTransactionData => {
  const {auction_brief_description, auction_description_url, auction_end_date } = args;
  return {
    data: {
      function: `${import.meta.env.VITE_MODULE_ADDRESS}::auction::auction_contract`,
      functionArguments: [auction_brief_description, auction_description_url, auction_end_date ],
    },
  };
};


