import { useWallet } from "@aptos-labs/wallet-adapter-react";
// Internal Components
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Header } from "@/components/Header";
import { CreateAuction } from "@/components/CreateAuction";
import { ListAuctionData } from "@/components/ListAuctionData";

function App() {
  const { connected } = useWallet();

  return (
    <>
      <Header />

      <div className="flex flex-col md:flex-row w-full">
        <div className="w-1/2">
          {connected ? (
            <div className="w-full p-4">
              <Card>
                <CardContent className="flex flex-col gap-10 pt-6 ">
                  {/* <WalletDetails />
              <NetworkInfo />
              <AccountInfo />
              <TransferAPT />  */}
                  <CreateAuction />
                </CardContent>
              </Card>
            </div>
          ) : (
            <CardHeader>
              <CardTitle>To get started Connect a wallet</CardTitle>
            </CardHeader>
          )}
        </div>

        <div className="w-1/2">
          <ListAuctionData />
        </div>
      </div>
    </>
  );
}

export default App;
