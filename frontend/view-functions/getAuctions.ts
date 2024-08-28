import { aptosClient } from "@/utils/aptosClient";

interface AuctionDetails {
  owner: string;
  auction_brief_description: string;
  highest_bidder: {vec: [string | undefined ]};
  highest_bid: {vec: [number | undefined ]};
  auction_end_time: string;
  created_date: string;
  auction_ended: boolean;
  auction_description_url: string;
  num_of_bidders: string;
  object_ref: {inner: string};
}

export const getAuctions = async (): Promise<AuctionDetails[]> => {
  const auctions = await aptosClient()
    .view<[[AuctionDetails]]>({
      payload: {
        function: `${import.meta.env.VITE_MODULE_ADDRESS}::auction_contract::get_all_auctions_details`,
      },
    })
    .catch((error) => {
      console.error(error);
      return [];
    });

  return auctions[0];
};
