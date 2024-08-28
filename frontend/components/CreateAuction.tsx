import { useState } from "react";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { useQueryClient } from "@tanstack/react-query";
// Internal components
import { toast } from "@/components/ui/use-toast";
import { aptosClient } from "@/utils/aptosClient";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import DatePicker from "react-datepicker";
import "react-datepicker/dist/react-datepicker.css";
import { createAuction } from "@/entry-functions/createAuction";



export function CreateAuction() {
  const { account, signAndSubmitTransaction } = useWallet();
  const queryClient = useQueryClient();

  const [auctionDescription, setAuctionDescription] = useState<string>();
  const [auctionUrl, setAuctionUrl] = useState<string>();
  const [auctionEndDate, setAuctionEndDate] = useState(new Date());


  const createNewAuction = async () => {
    if (!account || !auctionDescription || !auctionUrl || !auctionEndDate) {
      return;
    }

    try {
      const endDateTimestamp = (strDate: string): number => Date.parse(strDate) / 1000;
      const committedTransaction = await signAndSubmitTransaction(
        createAuction({
          auction_brief_description: auctionDescription!,
          auction_description_url: auctionUrl!,
          auction_end_date: +endDateTimestamp(auctionEndDate.toDateString()),
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
      setAuctionDescription("");
      setAuctionUrl("");
      setAuctionEndDate(new Date());
    } catch (error) {
      console.error(error);
    }
  };

  return (
    <div className="flex flex-col md:flex-row w-full">
      <div className="w-full md:w-1/2 p-4">
        <div className="flex flex-col gap-6">
          <Input
            disabled={!account}
            value={auctionDescription}
            placeholder="description of the auction"
            onChange={(e) => setAuctionDescription(e.target.value)}
          />
          <Input
            disabled={!account}
            value={auctionUrl}
            placeholder="url that points to auction item"
            onChange={(e) => setAuctionUrl(e.target.value)}
          />

          <DatePicker selected={auctionEndDate} onChange={(date) => setAuctionEndDate(date!)} />

          <Button disabled={!account} onClick={createNewAuction}>
            create auction
          </Button>
        </div>
      </div>
    </div>
  );
}
