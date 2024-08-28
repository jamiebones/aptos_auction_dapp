import React, { useEffect, useState } from "react";
import Modal from "react-modal";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { AuctionData } from "@/components/interface/AuctionData";



const customStyles = {
  content: {
    top: "50%",
    left: "50%",
    right: "auto",
    bottom: "auto",
    marginRight: "-50%",
    transform: "translate(-50%, -50%)",
    width: "500px",
  },
};

Modal.setAppElement("#root");

const BidModal: React.FC<AuctionData> = ({
  description,
  link,
  highestBid,
  auctionRef,
  isModalOpen,
  toggleModal,
  placeAuctionBid
}) => {
  const [modalIsOpen, setIsOpen] = useState(false);
  const [bidAmount, setBidAmount] = useState(0);

  useEffect(() => {
    if (isModalOpen) {
      openModal();
    } else {
      closeModal();
    }
  });

  function openModal() {
    setIsOpen(true);
  }

  function closeModal() {
    setIsOpen(false);
  }

  const createBid = (auctionRef: string) => {
        if ( auctionRef && bidAmount > highestBid){
            placeAuctionBid(auctionRef, bidAmount);
        }
  };

  return (
    <div className="w-full">
      <Modal isOpen={modalIsOpen} onRequestClose={closeModal} style={customStyles} contentLabel="Bid Modal">
        <div className="flex flex-col">
          <p className="float-right" onClick={toggleModal}>
            close
          </p>
          <p className="py-1">Description: {description}</p>

          <p className=" py-1">Auction link: {link}</p>

          <p>Current highest bid {highestBid}</p>

          <div className="py-4">
            <Input type="number" value={bidAmount} placeholder="0.00" onChange={(e) => setBidAmount(+e.target.value)} />
          </div>

          <Button onClick={()=>createBid(auctionRef)}>place bid</Button>
        </div>
      </Modal>
    </div>
  );
};

export default BidModal;
