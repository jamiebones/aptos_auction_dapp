export interface AuctionData {
    description: string;
    link: string;
    highestBid: number;
    isModalOpen: boolean;
    auctionRef:string;
    toggleModal: () => void;
    placeAuctionBid: (ref:string, amount: number) => void;
  }