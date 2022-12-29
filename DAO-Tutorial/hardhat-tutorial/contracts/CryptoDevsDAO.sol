// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * Interface for the FakeNFTMarketplace
 */
 interface IFakeNFTMarketplace {
    // @dev getPrice() returns the price of an NFT from the FakeNFTMarketplace
    // @return Returns the price in Wei for an NFT
    function getPrice() external view returns (uint256);

    // @dev available() returns whether or not the given _tokenId has already been purchased
    // @return Returns a boolean value - true if available, false if not
    function available(uint256 _tokenId) external view returns (bool);

    // @dev purchase() purchases an NFT from the FakeNFTMarketplace
    // @param _tokenId - the fake NFT tokenID to purchase
    function purchase(uint256 _tokenId) external payable;
 }

 /**
 * Minimal interface for CryptoDevsNFT containing two functions
 */
 interface ICryptoDevsNFT {
    // @dev balanceOf() returns the number of NFTs owned by the given address
    // @param owner - address to fetch number of NFTs for
    // @return Returns the number of NFTs owned
    function balanceOf(address owner) external view returns (uint256);

    // @dev tokenOfOwnerByIndex returns a tokenID at given index of owner
    // @param owner - address to fetch the NFT TokenID for
    // @param index - index of NFT in owned tokens array to fetch
    // @return Returns the TokenID of the NFT
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
 }

contract CryptoDevsDAO is Ownable {
    // A struct named Proposal that contains all relevant information
    struct Proposal {
        /** 
        * nftTokenId - the tokenID of the NFT to purchase from FakeNFTMarketplace if the proposal passes
        * deadline - the UNIX timestamp until which this proposal is active. Proposal can be executed after the deadline has been exceeded.
        * yayVotes - number of yay votes for this proposal
        * nayVotes - the number of nay votes for this proposal
        * executed - whether or not this proposal has been executed yet. Cannot be executed before the deadline has been exceeded
        * voters - a mapping of CryptoDevsNFT tokenIDs to booleans indicating whether that NFT has already been used to cast a vote or not
        */
        uint256 nftTokenId;
        uint256 deadline;
        uint256 yayVotes;
        uint256 nayVotes;
        bool executed;
        mapping(uint256 => bool) voters;
    }

    // Create an enum named Vote containing possible options for a vote
    // YAY = 0, NAY = 1
    enum Vote {
        YAY, 
        NAY
    }

    // Create a mapping of ID to Proposal
    mapping(uint256 => Proposal) public proposals;
    // Number of proposals that have been created
    uint256 public numProposals;
    // Initialize variables for FakeNFTMarketplace and CryptoDevsNFT contracts
    IFakeNFTMarketplace nftMarketplace;
    ICryptoDevsNFT cryptoDevsNFT;

    // Create a modifier which only allows a function to be called by someone 
    // who owns at least 1 CryptoDevsNFT
    modifier nftHolderOnly() {
        require(cryptoDevsNFT.balanceOf(msg.sender) > 0, "NOT_A_DAO_MEMBER");
        _;
    }

    // Create a modifier which only allows a function to be called if the 
    // given proposal's deadline has NOT been exceed yet
    modifier activeProposalOnly(uint256 proposalIndex) {
        require(proposals[proposalIndex].deadline > block.timestamp, "DEADLINE_EXCEEDED");
        _;
    }

    // Create a modifier which only allows a function to be called if the
    // given proposal's deadline HAS been exceeded and if the proposal has not yet been executed
    modifier inactiveProposalOnly(uint256 proposalIndex) {
        require(proposals[proposalIndex].deadline <= block.timestamp, "DEADLINE_NOT_EXCEEDED");
        require(proposals[proposalIndex].executed == false, "PROPOSAL_ALREADY_EXECUTED");
        _;
    }

    constructor(address _nftMarketplace, address _cryptoDevsNFT) payable {
        nftMarketplace = IFakeNFTMarketplace(_nftMarketplace);
        cryptoDevsNFT = ICryptoDevsNFT(_cryptoDevsNFT);
    }

    // @dev createProposal() allows a CryptoDevsNFT holder to create a new proposal in the DAO
    // @param _nftTokenId - the tokenID of the NFT to be purchased from FakeNFTMarketplace if this proposal passes
    // @return Returns the proposal index for the newly created proposal
    function createProposal(uint256 _nftTokenId) external nftHolderOnly returns (uint256) {
        require(nftMarketplace.available(_nftTokenId), "NFT_NOT_FOR_SALE");
        Proposal storage proposal = proposals[numProposals];
        proposal.nftTokenId = _nftTokenId;
        // Set the proposal's voting deadline to be (current time + 5 minutes)
        proposal.deadline = block.timestamp + 5 minutes;
        ++numProposals;
        return numProposals - 1;
    }

    function voteOnProposal(uint256 proposalIndex, Vote vote) external nftHolderOnly activeProposalOnly(proposalIndex) {
        Proposal storage proposal = proposals[proposalIndex];

        uint256 voterNFTBalance = cryptoDevsNFT.balanceOf(msg.sender);
        uint256 numVotes = 0;
        // Calculate how many NFTs are owned by the voter that haven't already been used for voting on this proposal
        for (uint256 i = 0; i < voterNFTBalance; ++i) {
            uint256 tokenId = cryptoDevsNFT.tokenOfOwnerByIndex(msg.sender, i);
            if (proposal.voters[tokenId] == false) {
                ++numVotes;
                proposal.voters[tokenId] = true;
            }
        }
        require(numVotes > 0, "ALREADY_VOTED");

        if (vote == Vote.YAY) {
            proposal.yayVotes += numVotes;
        } else {
            proposal.nayVotes += numVotes;
        }
    }

    // @dev executeProposal allows any CryptoDevsNFT holder to execute a proposal after it's deadline has been exceeded
    // @param proposalIndex - the index of the proposal to execute in the proposals array
    function executeProposal(uint256 proposalIndex) external nftHolderOnly inactiveProposalOnly(proposalIndex) {
        Proposal storage proposal = proposals[proposalIndex];

        // If the proposal has more YAY votes than NAY votes => purchase the NFT from the FakeNFTMarketplace
        if (proposal.yayVotes > proposal.nayVotes) {
            uint256 nftPrice = nftMarketplace.getPrice();
            require(address(this).balance >= nftPrice, "NOT_ENOUGH_FUNDS");
            nftMarketplace.purchase{value: nftPrice}(proposal.nftTokenId);
        }
        proposal.executed = true;
    }

    // @dev withdrawEther allows the contract owner (deployer) to withdraw the ETH from the contract
    function withdrawEther() external onlyOwner {
        uint256 amount = address(this).balance;
        require(amount > 0, "Nothing to withdraw; contract balance empty");
        payable(owner()).transfer(amount);
    }

    // The following two functions allow the contract to acept ETH deposits directly from a wallet without calling a function
    receive() external payable {}

    fallback() external payable {}
}