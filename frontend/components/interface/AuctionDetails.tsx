export interface AuctionDetails {
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