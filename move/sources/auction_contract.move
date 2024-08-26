module auction::auction_contract {


    use aptos_framework::object::{Self, Object, ObjectCore};
    use std::signer;
    use std::string::{Self, String};
    use aptos_std::smart_table;
    use aptos_std::vector;
    use aptos_std::smart_table::SmartTable;
    use aptos_std::smart_vector::{Self, SmartVector};
    use std::option::{Self, Option};
    use aptos_framework::timestamp;
    use aptos_framework::aptos_account;
    use aptos_framework::account::SignerCapability;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_std::debug;
    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_framework::aptos_coin::AptosCoin;

    use aptos_framework::event;


    #[test_only]
    use aptos_framework::stake;



    const WALLET_SEED: vector<u8> = b"Wallet seed for the object";


    //error constant
    const ERR_OBJECT_DONT_EXIST:u64 = 700;
    const ERR_BID_SMALLER_THAN_HIGHEST_BID:u64 = 705;
    const ERR_AUCTION_TIME_LAPSED:u64 = 706;
    const ERR_AUCTION_ENDED:u64 = 707;
    const ERR_AUCTION_TIME_NOT_LAPSED:u64 = 708;
    const ERR_AUCTION_STILL_RUNNING:u64 = 709;
    const ERR_NOT_THE_OWNER:u64 = 710;


    //event
    #[event]
    struct CreateAuctionEvent has store, drop {
        auction_creator: address,
        created_time: u64,
        auction_brief_description: String,
        auction_end_time: u64
    }


    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct SignerCapabilityStore has key {
        signer_capability: SignerCapability,
    }

    struct OwnerAuctions has key {
        auction_list: vector<Object<AuctionMetadata>>
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct AuctionMetadata has key{
        owner: address,
        auction_brief_description: String,
        highest_bidder: Option<address>,
        highest_bid: Option<u64>,
        auction_end_time: u64,
        created_date: u64,
        auction_ended: bool,
        pending_returns: SmartTable<address, u64>,
        auction_description_url: String,
        bidders: SmartTable<address, u64>
    }

    struct AuctionDetails has copy, drop {
        owner: address,
        auction_brief_description: String,
        highest_bidder: Option<address>,
        highest_bid: Option<u64>,
        auction_end_time: u64,
        created_date: u64,
        auction_ended: bool,
        auction_description_url: String,
        num_of_bidders: u64
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Registry has key {
        auction_objects: vector<Object<AuctionMetadata>>,
    }

    struct AuctionBid has store, drop{
        auction_address: address,
        bid_amount: u64
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct UserAuctionBid has key {
        bids: vector<AuctionBid>
    }


    fun init_module(creator: &signer){
        create_contract_resource(creator);
    }

    fun create_contract_resource(creator: &signer){
        //create a resource account to hold the contract funds
        let (_, signer_capability) = account::create_resource_account(creator, WALLET_SEED);
        move_to(creator, SignerCapabilityStore { signer_capability });
        move_to(
            creator,
            Registry {
                auction_objects: vector::empty<Object<AuctionMetadata>>()
            }
        )
    }



    public entry fun create_new_auction(auction_creator: &signer,
                                        auction_brief_description: String,
                                        auction_description_url: String,
                                        auction_end_date: u64) acquires OwnerAuctions, Registry {

        //create a normal object ownwed by the contract
        let auction_creator_address = signer::address_of(auction_creator);
        let obj_constructor_ref = object::create_object(auction_creator_address);
        let obj_constructor_signer = object::generate_signer(&obj_constructor_ref);

        //move the AuctionMetadata to the named object
        move_to(
            &obj_constructor_signer,
            AuctionMetadata{
                owner: signer::address_of(auction_creator),
                auction_brief_description,
                highest_bidder: option::none(),
                highest_bid: option::none(),
                auction_end_time: auction_end_date,
                created_date: timestamp::now_seconds(),
                auction_ended: false,
                pending_returns: smart_table::new<address, u64>(),
                auction_description_url,
                bidders: smart_table::new<address, u64>()
            }
        );

        //get the object reference and save to the creator address
        let  obj_auction_ref= object::object_from_constructor_ref<AuctionMetadata>(&obj_constructor_ref);
        if (exists<OwnerAuctions>(auction_creator_address)){
            let auctions_list = &mut borrow_global_mut<OwnerAuctions>(auction_creator_address).auction_list;
            vector::push_back(auctions_list, obj_auction_ref);
        } else{
            //initialize the
            let auctions_list = vector::empty<Object<AuctionMetadata>>();
            vector::push_back(&mut auctions_list, obj_auction_ref);
            move_to(
                auction_creator,
                OwnerAuctions {
                    auction_list: auctions_list
                }
            );
        };
        //save the object inside the contract registry
        let auction_registry =&mut borrow_global_mut<Registry>(@auction).auction_objects;
        vector::push_back( auction_registry, obj_auction_ref);
    }


    public entry fun make_auction_bid(bidder: &signer, auction_object: Object<AuctionMetadata>, bid_amount: u64) acquires AuctionMetadata, UserAuctionBid,SignerCapabilityStore {
        //get the auction object and check if it exists
        let auction_address = object::object_address(&auction_object);
        let resource_account_signer = &get_signer();
        let resource_account_address = signer::address_of(resource_account_signer);
        if (!object::object_exists<AuctionMetadata>(auction_address)) {
            abort(ERR_OBJECT_DONT_EXIST)
        };
        let auction = borrow_global_mut<AuctionMetadata>(auction_address);
        if ( timestamp::now_seconds() > auction.auction_end_time ){
            abort(ERR_AUCTION_TIME_LAPSED)
        };
        if ( auction.auction_ended ){
            abort(ERR_AUCTION_ENDED)
        };
        //check if the bid is greater than the existing highest bid
        let former_highest_bid: u64 = 0;
        if (option::is_some(&auction.highest_bid)){
            former_highest_bid = *option::borrow(&auction.highest_bid);
        };
        //check if the user bid is greater than the former bid
        if ( former_highest_bid > bid_amount ){
            abort(ERR_BID_SMALLER_THAN_HIGHEST_BID)
        };
        //we are good, we now update the auction data
        auction.highest_bid = option::some(bid_amount);
        let bidder_address = signer::address_of(bidder);
        auction.highest_bidder = option::some(bidder_address);
        let sm_table_returns = &mut auction.pending_returns;
        //check if the address is on the smart table
        let added_bid_amount = 0;
        if ( smart_table::contains(sm_table_returns, bidder_address)){
            //return the old amount
            let old_amount = smart_table::borrow(sm_table_returns, bidder_address);
            //get the object that owns the money
            let bids_vector = &mut borrow_global_mut<UserAuctionBid>(bidder_address).bids;
            //removed the old value
            added_bid_amount = bid_amount - *old_amount;

            vector::remove_value(bids_vector, &AuctionBid {
                bid_amount: *old_amount,
                auction_address
            });
        };

        smart_table::upsert(&mut auction.bidders, bidder_address, bid_amount);
        smart_table::upsert(sm_table_returns, bidder_address, bid_amount);
        if ( added_bid_amount > 0 ){
            aptos_account::transfer(bidder, resource_account_address, added_bid_amount);
        } else {
            aptos_account::transfer(bidder, resource_account_address, bid_amount);
        };

        //save the user bid made to the UserAuctionBid state
        if (exists<UserAuctionBid>(bidder_address)){
            let bids_vector = &mut borrow_global_mut<UserAuctionBid>(bidder_address).bids;
            vector::push_back(bids_vector, AuctionBid {
                bid_amount,
                auction_address
            });
        } else{
            //does not exist
            let bid_vector = vector::empty<AuctionBid>();
            vector::push_back(&mut bid_vector, AuctionBid{
                bid_amount,
                auction_address
            });

            move_to(
                bidder,
                UserAuctionBid {
                    bids: bid_vector
                }
            );
        }
    }

    //close_auction
    public entry fun close_auction(auction_object: Object<AuctionMetadata>) acquires AuctionMetadata, SignerCapabilityStore
    {
        //get the auction
        let auction_address = object::object_address(&auction_object);
        if (!object::object_exists<AuctionMetadata>(auction_address)) {
            abort(ERR_OBJECT_DONT_EXIST)
        };
        let auction = borrow_global_mut<AuctionMetadata>(auction_address);
        if ( timestamp::now_seconds() < auction.auction_end_time ){
            abort(ERR_AUCTION_TIME_NOT_LAPSED)
        };
        if ( auction.auction_ended ){
            abort(ERR_AUCTION_ENDED)
        };
        //end the auction
        auction.auction_ended = true;
        //return the bidders money that didn't win back
        let highest_bidder = option::borrow(&auction.highest_bidder);
        refund_money_back_to_non_win_bids(&auction.bidders, *highest_bidder);
    }

    public entry fun collect_winning_bid(auction_owner: &signer, auction_object: Object<AuctionMetadata>) acquires AuctionMetadata, SignerCapabilityStore{
        let auction_address = object::object_address(&auction_object);
        let resource_account_signer = &get_signer();
        let resource_account_address = signer::address_of(resource_account_signer);
        if (!object::object_exists<AuctionMetadata>(auction_address)) {
            abort(ERR_OBJECT_DONT_EXIST)
        };
        let auction = borrow_global<AuctionMetadata>(auction_address);
        if ( !auction.auction_ended ){
            abort(ERR_AUCTION_STILL_RUNNING)
        };
        assert!(auction.owner == signer::address_of(auction_owner), ERR_NOT_THE_OWNER);
        //collect the highest bid
        coin::transfer<AptosCoin>(resource_account_signer, auction.owner, *option::borrow(&auction.highest_bid))
    }

    fun refund_money_back_to_non_win_bids(bidders: &SmartTable<address, u64>, bid_winner: address) acquires SignerCapabilityStore {
        //loop through the smart table
        //retrieve the signer for the wallet object
        let resource_account_signer = &get_signer();
        let resource_account_address = signer::address_of(resource_account_signer);
        smart_table::for_each_ref(bidders, |key, value| {
            if ( *key != bid_winner){
                coin::transfer<AptosCoin>(resource_account_signer, *key, *value);
            }
        })
    }

    fun get_signer(): signer acquires SignerCapabilityStore {
        let signer_capability = &borrow_global<SignerCapabilityStore>(@auction).signer_capability;
        account::create_signer_with_capability(signer_capability)
    }

    #[view]
    public fun get_owner_auctions(owner_address: address): vector<Object<AuctionMetadata>> acquires OwnerAuctions {
        let auctions = vector::empty<Object<AuctionMetadata>>();
        if (exists<OwnerAuctions>(owner_address)) {
        auctions = borrow_global<OwnerAuctions>(owner_address).auction_list
        };
        auctions
    }

    #[view]
    public fun get_all_auctions(): vector<Object<AuctionMetadata>> acquires Registry {
        borrow_global<Registry>(@auction).auction_objects
    }

    #[view]
    public fun get_auction_details(auction_reference: Object<AuctionMetadata>): AuctionDetails acquires AuctionMetadata {
        let object_address = object::object_address(&auction_reference);
        let auction_meta_data = borrow_global<AuctionMetadata>(object_address);
        let auction_details = AuctionDetails {
            owner: auction_meta_data.owner,
            auction_brief_description: auction_meta_data.auction_brief_description,
            highest_bidder: auction_meta_data.highest_bidder,
            highest_bid: auction_meta_data.highest_bid,
            auction_end_time: auction_meta_data.auction_end_time,
            created_date: auction_meta_data.created_date,
            auction_ended: auction_meta_data.auction_ended,
            auction_description_url: auction_meta_data.auction_description_url,
            num_of_bidders: smart_table::length(&auction_meta_data.bidders)
        };
        auction_details
    }

    #[view]
    public fun get_auction_bidders(auction_reference: Object<AuctionMetadata>): SimpleMap<address, u64> acquires AuctionMetadata {
        let object_address = object::object_address(&auction_reference);
        let auction_meta_data = borrow_global<AuctionMetadata>(object_address);
        smart_table::to_simple_map(&auction_meta_data.bidders)
    }


    #[test_only]
    fun setup_test(
        creator: &signer,
        owner_1: &signer,
        owner_2: &signer,
        aptos_framework: &signer,
    ) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        stake::initialize_for_test(&account::create_signer_for_test(@0x1));

        account::create_account_for_test(signer::address_of(aptos_framework));
        account::create_account_for_test(signer::address_of(creator));
        account::create_account_for_test(signer::address_of(owner_1));
        account::create_account_for_test(signer::address_of(owner_2));
        create_contract_resource(creator);
    }

    #[test_only]
    fun test_mint_aptos(creator: &signer,
                        owner_1: &signer,
                        owner_2: &signer) {
        stake::mint(creator, 10000000000);
        stake::mint(owner_1, 10000000000);
        stake::mint(owner_2, 10000000000);
    }

    #[test(creator = @auction, owner_1 = @0x124,
        owner_2 = @0x125,
        aptos_framework = @0x1, )]
    fun test_auction_creation(creator: &signer, owner_1: &signer, owner_2: &signer, aptos_framework: &signer) acquires OwnerAuctions, Registry {
        setup_test(creator, owner_1, owner_2, aptos_framework);
        let auction_brief_description = string::utf8(b"Selling the voucher drapper");
        let auction_description_url = string::utf8(b"https//space.com");
        create_new_auction(
            creator,
            auction_brief_description,
            auction_description_url,
            timestamp::now_seconds(),
        );
        create_new_auction(
            creator,
            auction_brief_description,
            auction_description_url,
            timestamp::now_seconds(),
        );
        let creator_address = signer::address_of(creator);
        let owner_auction = borrow_global<OwnerAuctions>(creator_address);
        let owner_auction_length = vector::length(&owner_auction.auction_list);
        let contract_registry = borrow_global<Registry>(@auction);
        let contract_registry_length = vector::length(&contract_registry.auction_objects);
        assert!(owner_auction_length == 2, 501);
        assert!(contract_registry_length == 2, 502);
    }


    #[test(creator = @auction, owner_1 = @0x124,
        owner_2 = @0x125,
        aptos_framework = @0x1, )]
    fun test_auction_bid(creator: &signer, owner_1: &signer, owner_2: &signer, aptos_framework: &signer) acquires OwnerAuctions, Registry,
    AuctionMetadata, UserAuctionBid, SignerCapabilityStore {
        setup_test(creator, owner_1, owner_2, aptos_framework);
        test_mint_aptos(creator, owner_1, owner_2);
        let auction_brief_description = string::utf8(b"Selling the voucher drapper");
        let auction_description_url = string::utf8(b"https//space.com");
        create_new_auction(
            creator,
            auction_brief_description,
            auction_description_url,
            timestamp::now_seconds(),
        );
        //get the created auction object
        let auction_vector_ref = borrow_global<Registry>(@auction).auction_objects;
        let auction_ref = vector::borrow(&auction_vector_ref, 0);
        let resource_account_signer = &get_signer();
        let resource_account_address = signer::address_of(resource_account_signer);
        make_auction_bid(owner_1, *auction_ref, 10_00000000);
        //get the balance of the conctract
        make_auction_bid(owner_1, *auction_ref, 12_00000000);
        make_auction_bid(owner_2, *auction_ref, 20_00000000);
        //test the bid
        let contract_balance = coin::balance<AptosCoin>(resource_account_address);
        //check the Registry length
        let num_vector = borrow_global<Registry>(@auction).auction_objects;
        let auction_object_reference = vector::borrow(&num_vector, 0);
        let auction_address = object::object_address(auction_object_reference);
        let auction = borrow_global<AuctionMetadata>(auction_address);
        let bidder_one_bid = smart_table::borrow(&auction.bidders, signer::address_of(owner_1));
        assert!(contract_balance == 32_00000000, 900);
        assert!(exists<UserAuctionBid>(signer::address_of(owner_1)), 901);
        assert!(smart_table::length(&auction.bidders) == 2 , 902);
        assert!(*bidder_one_bid == 12_00000000, 903);
    }

    #[test(creator = @auction, owner_1 = @0x124,
        owner_2 = @0x125,
        aptos_framework = @0x1, )]
    fun test_end_auction_bid(creator: &signer, owner_1: &signer, owner_2: &signer, aptos_framework: &signer) acquires OwnerAuctions, Registry,
    AuctionMetadata, UserAuctionBid, SignerCapabilityStore {
        setup_test(creator, owner_1, owner_2, aptos_framework);
        test_mint_aptos(creator, owner_1, owner_2);
        let auction_brief_description = string::utf8(b"Selling the voucher drapper");
        let auction_description_url = string::utf8(b"https//space.com");

        create_new_auction(
            creator,
            auction_brief_description,
            auction_description_url,
            1724361612
        );
        //get the created auction object

        let auction_vector_ref = borrow_global<Registry>(@auction).auction_objects;
        let auction_ref = vector::borrow(&auction_vector_ref, 0);
        let owner1_bal_before = coin::balance<AptosCoin>(signer::address_of(owner_1));
        let owner2_bal_before = coin::balance<AptosCoin>(signer::address_of(owner_2));
        make_auction_bid(owner_1, *auction_ref, 10_00000000);
        //get the balance of the conctract
        make_auction_bid(owner_2, *auction_ref, 20_00000000);
        timestamp::fast_forward_seconds(1727040012);

        close_auction(*auction_ref);
        let owner1_bal_after = coin::balance<AptosCoin>(signer::address_of(owner_1));
        let owner2_bal_after = coin::balance<AptosCoin>(signer::address_of(owner_2));
        assert!(owner1_bal_after == owner1_bal_before, 908);
        assert!(owner2_bal_after < owner2_bal_before, 909);
    }

    #[test(creator = @auction, owner_1 = @0x124,
        owner_2 = @0x125,
        aptos_framework = @0x1, )]
    fun test_winning_bid_collection(creator: &signer, owner_1: &signer, owner_2: &signer, aptos_framework: &signer) acquires OwnerAuctions, Registry,
    AuctionMetadata, UserAuctionBid, SignerCapabilityStore {
        setup_test(creator, owner_1, owner_2, aptos_framework);
        test_mint_aptos(creator, owner_1, owner_2);
        let auction_brief_description = string::utf8(b"Selling the voucher drapper");
        let auction_description_url = string::utf8(b"https//space.com");
        create_new_auction(
            creator,
            auction_brief_description,
            auction_description_url,
            1724361612
        );
        //get the created auction object
        let auction_vector_ref = borrow_global<Registry>(@auction).auction_objects;
        let auction_ref = vector::borrow(&auction_vector_ref, 0);
        let creator_bal_before = coin::balance<AptosCoin>(signer::address_of(creator));
        make_auction_bid(owner_1, *auction_ref, 10_00000000);
        make_auction_bid(owner_2, *auction_ref, 20_00000000);
        timestamp::fast_forward_seconds(1727040012);

        close_auction(*auction_ref);
        collect_winning_bid(creator, *auction_ref);
        let creator_bal_after = coin::balance<AptosCoin>(signer::address_of(creator));
        assert!(creator_bal_after > creator_bal_before, 909);
    }

    #[test(creator = @auction, owner_1 = @0x124,
        owner_2 = @0x125,
        aptos_framework = @0x1, )]
    fun test_get_owner_auction(creator: &signer, owner_1: &signer, owner_2: &signer, aptos_framework: &signer) acquires OwnerAuctions, Registry,
   {
        setup_test(creator, owner_1, owner_2, aptos_framework);
        test_mint_aptos(creator, owner_1, owner_2);
        let creator_address = signer::address_of(creator);
        let auction_brief_description = string::utf8(b"Selling the voucher drapper");
        let auction_description_url = string::utf8(b"https//space.com");
        create_new_auction(
            creator,
            auction_brief_description,
            auction_description_url,
            1724361612
        );

        create_new_auction(
            creator,
            auction_brief_description,
            auction_description_url,
            1724361612
        );
        //get the created auction object
        let auctions = get_owner_auctions(creator_address);
        assert!(vector::length(&auctions) == 2, 888);
    }

    #[test(creator = @auction, owner_1 = @0x124,
        owner_2 = @0x125,
        aptos_framework = @0x1, )]
    fun test_get_auction_details(creator: &signer, owner_1: &signer, owner_2: &signer, aptos_framework: &signer) acquires OwnerAuctions, Registry, AuctionMetadata, UserAuctionBid, SignerCapabilityStore
    {
        setup_test(creator, owner_1, owner_2, aptos_framework);
        test_mint_aptos(creator, owner_1, owner_2);
        let auction_brief_description = string::utf8(b"Selling the voucher drapper");
        let auction_description_url = string::utf8(b"https//space.com");
        create_new_auction(
            creator,
            auction_brief_description,
            auction_description_url,
            1724361612
        );

        //get the created auction object
        let auction_registry = borrow_global<Registry>(@auction).auction_objects;
        let auction_ref = vector::borrow(&auction_registry, 0);

        make_auction_bid(owner_1, *auction_ref, 10_00000000);
        make_auction_bid(owner_2, *auction_ref, 20_00000000);

        let auction_meta_data = get_auction_details(*auction_ref);
        assert!( auction_meta_data.auction_brief_description == auction_brief_description, 1000);
        assert!( auction_meta_data.num_of_bidders == 2, 1001);

        debug::print(&auction_meta_data);
    }

    #[test(creator = @auction, owner_1 = @0x124,
        owner_2 = @0x125,
        aptos_framework = @0x1, )]
    fun test_get_auction_bidders(creator: &signer, owner_1: &signer, owner_2: &signer, aptos_framework: &signer) acquires OwnerAuctions, Registry, AuctionMetadata, UserAuctionBid, SignerCapabilityStore
    {
        setup_test(creator, owner_1, owner_2, aptos_framework);
        test_mint_aptos(creator, owner_1, owner_2);
        let auction_brief_description = string::utf8(b"Selling the voucher drapper");
        let auction_description_url = string::utf8(b"https//space.com");
        create_new_auction(
            creator,
            auction_brief_description,
            auction_description_url,
            1724361612
        );
        //get the created auction object
        let auction_registry = borrow_global<Registry>(@auction).auction_objects;
        let auction_ref = vector::borrow(&auction_registry, 0);
        make_auction_bid(owner_1, *auction_ref, 10_00000000);
        make_auction_bid(owner_2, *auction_ref, 20_00000000);
        let auction_bidders = get_auction_bidders(*auction_ref);
        simple_map::length(&auction_bidders);
        assert!(simple_map::length(&auction_bidders) == 2, 1003);
    }





}

// aptos account transfer --account superuser --amount 100
// aptos init --profile <profile-name>