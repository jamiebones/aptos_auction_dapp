import { useState, useEffect } from "react";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { Button } from "@/components/ui/button";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { AuctionDetails } from "@/components/interface/AuctionDetails";
import { toast } from "@/components/ui/use-toast";
import { aptosClient } from "@/utils/aptosClient";
import BidModal from "@/components/BidModal";
import { ModalData } from "@/components/interface/ModalData";
import { getAuctions } from "@/view-functions/getAuctions";
import { placeBid } from "@/entry-functions/placeBid";



export function ListAuctionData() {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const { account, signAndSubmitTransaction } = useWallet();
  const queryClient = useQueryClient();
  const [auctions, setAuctions] = useState<AuctionDetails[]>([]);

  const { data } = useQuery({
    queryKey: ["get-auctions"],
    refetchInterval: 10_000,
    queryFn: async () => {
      try {
        const auctionDetails = await getAuctions();
        return {
          auctionDetails,
        };
      } catch (error: any) {
        toast({
          variant: "destructive",
          title: "Error",
          description: error,
        });
        return {
          auctionDetails: [],
        };
      }
    },
  });

  useEffect(() => {
    if (data) {
      setAuctions(data?.auctionDetails);
    }
  }, [data]);

  const [modalData, setModalData] = useState<ModalData>({
    description: "",
    link: "",
    highestBid: 0,
    auctionRef: ""
  });

  const openModal = (description: string, link: string, highestBid: number, auctionRef: string) => {
    setModalData({
      description,
      link,
      highestBid,
      auctionRef
    });
    toggleModal();
  };

  const toggleModal = () => {
    setIsModalOpen(!isModalOpen);
  };

  const placeAuctionBid = async (ref:string, amount: number) => {
    if (!account || !ref || !amount) {
      return;
    }
    try {
      const decimal = 100_000_000
      const committedTransaction = await signAndSubmitTransaction(
        placeBid({
          ref,
          amount: amount * decimal
        }),
      );
      const executedTransaction = await aptosClient().waitForTransaction({
        transactionHash: committedTransaction.hash,
      });
      queryClient.invalidateQueries();
      toast({
        title: "Success",
        description: `Transaction succeeded, hash: ${executedTransaction.hash}`,
      });
      toggleModal();
      //close modal here
    } catch (error) {
      console.error(error);
      toggleModal();
    }
      
  }



  return (
    <div className="flex flex-wrap -mx-2">
      {auctions.map((auction, index) => (
        <div key={index} className="w-full p-2">
          <div className="p-4 border rounded-lg shadow-md bg-white">
            <h2 className="text-lg font-semibold mb-2">{auction.auction_brief_description}</h2>
            <p className="text-sm text-gray-600">
              <strong>Owner:</strong> {auction.owner}
            </p>

            <p className="text-sm text-gray-600">
              <strong>Highest Bidder:</strong> {auction.highest_bidder.vec[0]}
            </p>
            <p className="text-sm text-gray-600">
              <strong>Highest Bid:</strong> ${auction.highest_bid.vec[0] ? auction.highest_bid.vec[0] : 0}
            </p>
            <p className="text-sm text-gray-600">
              <strong>Auction Ends:</strong> {new Date(+auction.auction_end_time * 1000).toLocaleString()}
            </p>
            <p className="text-sm text-gray-600">
              <strong>Created Date:</strong> {new Date(+auction.created_date * 1000).toLocaleString()}
            </p>
            <p className={`text-sm font-semibold ${auction.auction_ended ? "text-red-500" : "text-green-500"}`}>
              {auction.auction_ended ? "Auction Ended" : "Auction Ongoing"}
            </p>
            <p className="text-sm text-gray-600">
              <strong>Number of Bidders:</strong> {auction.num_of_bidders}
            </p>
            <a
              href={auction.auction_description_url}
              target="_blank"
              rel="noopener noreferrer"
              className="text-blue-500 hover:underline text-sm"
            >
              View Full Description
            </a>

            <Button
              onClick={() => {
                openModal(auction.auction_brief_description, auction.auction_description_url, auction.highest_bid.vec[0] ? auction.highest_bid.vec[0] : 0, auction.object_ref.inner);
              }}
            >
              place bid
            </Button>
          </div>
        </div>
      ))}

      {modalData.description != "" && isModalOpen && (
        <BidModal
          description={modalData.description}
          link={modalData.link}
          highestBid={modalData.highestBid}
          auctionRef={modalData.auctionRef}
          isModalOpen={isModalOpen}
          toggleModal={toggleModal}
          placeAuctionBid={placeAuctionBid}
        />
      )}
    </div>
  );
};

