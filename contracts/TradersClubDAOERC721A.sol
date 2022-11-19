//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
/**
 *
 *  TradersClubDAO
 *
*/

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./ERC721AWhitelist.sol";
contract TradersClubDAO is ERC2981, ERC721A, Ownable, ReentrancyGuard, ERC721AWhitelist{

    uint256 public immutable maxSupply;
    uint256 public immutable amountForDevs;
    address immutable teamAddress; 
    ///@notice Never used
    bool teamMintStatus;
    
    mapping(bytes => bool) public signatures;
    ///@notice Never used
    address whitelistSigningKey = address(0);

    constructor(uint256 _maxSupply, uint256 _amountForDev, address _teamAddress, uint96 royaltyFees) ERC721A("TradersClubDAO", "TCDAO"){
        require(_maxSupply > 0, "ERC721A: max batch size must be nonzero");
        ///@notice Better implementation: Consistent naming style
        _setDefaultRoyalty(_teamAddress, royaltyFees);

        maxSupply = _maxSupply;
        amountForDevs = _amountForDev;
        teamAddress = _teamAddress;
        ///@notice No need to initiate with false
        teamMintStatus = false;
        ///@notice Better implementation: Use EDCSA
        signatures["0x0000000000000000000000000000000000000000"] = true;
    }

    /**
     * @dev Caller is User.
     */
    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract.");
        _;
    }
    

    /**
     * @dev Mint for public.
     */
    function mint(bytes32 hash, bytes calldata whiteListSignature, bytes calldata signature) callerIsUser public {
        ///@notice No need to check here, already checked in #_whitelistMint
        ///@notice If really want to use this, just use internal _numberMinted
        require(numberMinted(msg.sender) < maxSupply , "Reached maximum NFT mint for public member");
        ///@notice Better implementation: Use EDCSA
        require(recoverWhitelistSigner(hash, whiteListSignature) == owner(), "You are not on the list.");
        ///@notice No need, as mentioned below
        require(!signatures[signature], "You have already minted NFT.");
        _whitelistMint();
        ///@notice No need to check here, already checked with numberMinted(msg.sender) < 1
        signatures[signature] = true;
    }

    function _whitelistMint() private {
        ///@notice Better implementation: Use EDCSA
        require(numberMinted(msg.sender) < 1, "1 NFT max per address");
        ///@notice This has no effect
        require(_totalMinted() < maxSupply, "NFT Sold out");
        _safeMint(msg.sender, 1);
    }

    /**
     * @dev Mint for internal team.
     */
   function teamMint() external payable callerIsUser{
        require( msg.sender == teamAddress, "This is only for team member.");
        _internalMint();
    }    
    
    function _internalMint() private {
        require(numberMinted(msg.sender) < amountForDevs , "Reached maximum NFT mint for team member");
        require(_totalMinted() < maxSupply, "NFT Sold out");
        _safeMint(msg.sender, 50);
    }

    /**
     * @dev BaseTokenURI for Traders Club DAO
     */
    string private _baseTokenURI;

    function _baseURI() internal view virtual override returns(string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Reset specific token royalty.
     */
    ///@notice No need to prevent owner from reentrant
    function setBaseURI(string calldata baseURI) external onlyOwner nonReentrant {
        _baseTokenURI = baseURI;
    }

    /**
     * @dev Default Royalty
     */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    /**
     * @dev Reset specific token royalty.
     */
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external onlyOwner {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }
    
    /**
     * @dev Reset specific token royalty.
     */
    function resetTokenRoyalty(uint256 tokenId) external onlyOwner {
        _resetTokenRoyalty(tokenId);
    }

    /**
     * @dev Get mint count of input address.
     */
    ///@notice No need with this function
    function numberMinted(address owner) public view returns(uint256) {
        return _numberMinted(owner);
    }

    /**
     * @dev Withdraw balnace to Team Address.
     */
    function withdraw() external onlyOwner {
        payable(teamAddress).transfer(address(this).balance);
    }

     /**
     * Override Royalty Interface
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721A, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {ERC721-_burn}. This override additionally clears the royalty information for the token.
     */
    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);
        _resetTokenRoyalty(tokenId);
    }

}