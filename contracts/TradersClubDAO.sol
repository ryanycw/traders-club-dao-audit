//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

error ExceedAmount();
error InvalidInput();
error InvalidTime();
error InvalidAddress();
error InvalidSignature();
error TokenNotExist();

contract TradersClubDAO is 
    ERC2981, 
    ERC721A, 
    Ownable, 
    ReentrancyGuard 
{
    using Strings for uint256;

    uint256 public immutable maxSupply;
    uint256 public immutable amountForDevs;
    address immutable teamAddress;
    string public baseURI;
    string public uriSuffix;

    /// Set with #setWhitelistMintPhase
    uint256 public mintWhitelistStartTime;
    uint256 public mintWhitelistEndTime;
    // This event is triggered whenever a call to #setWhitelistMintPhase
    event PhaseSet(uint256 _startTime, uint256 _endTime, string _type);
    // This event is triggered whenever a call to #withdraw
    event FundWithdraw(uint256 _amount, address _treasury);
    // This event is triggered whenever a call to #setBaseURI succeeds.
    event URISet(string _context, string _type);

    constructor(
        uint256 _maxSupply, 
        uint256 _amountForDev, 
        address _teamAddress, 
        uint96 _royaltyFees
    ) 
        ERC721A("TradersClubDAO", "TCDAO")
    {
        if (_maxSupply < 1 || _amountForDev < 1 || _teamAddress == address(0)) {
            revert InvalidInput();
        }

        _setDefaultRoyalty(_teamAddress, _royaltyFees);

        maxSupply = _maxSupply;
        amountForDevs = _amountForDev;
        teamAddress = _teamAddress;
    }

    modifier mintWhitelistActive() {
        // If it's not yet or after the public mint time
        if (block.timestamp <= mintWhitelistStartTime || block.timestamp >= mintWhitelistEndTime) {
            revert InvalidTime();
        }
        _;
    }
    
    modifier setTimeCheck(uint256 _startTime, uint256 _endTime) {
        // If we set the start time before end time
        if (_startTime > _endTime) {
            revert InvalidInput();
        }
        _;
    }

    modifier onlyTeam() {
        // If we set the start time before end time
        if (msg.sender != teamAddress) {
            revert InvalidAddress();
        }
        _;
    }

    /** 
     * @dev Override same interface function in different inheritance.
     * @param _interfaceId Id of an interface to check whether the contract support
     */
    function supportsInterface(bytes4 _interfaceId) 
        public
        view 
        override(ERC721A, ERC2981)
        returns (bool)
    {
        // Supports the following `interfaceId`s:
        // - IERC165: 0x01ffc9a7
        // - IERC721: 0x80ac58cd
        // - IERC721Metadata: 0x5b5e139f
        // - IERC2981: 0x2a55205a
        return 
            ERC721A.supportsInterface(_interfaceId) || 
            ERC2981.supportsInterface(_interfaceId);
    }

    /**
     * @dev Check whether an address is in the list
     * @dev Check whether the signature generation process is abnormal
     * @param _maxMintableQuantity Maximum Quantity of tokens that an address can mint
     * @param _signature Signature used to verify the address is in the list
     */
    function verify(
        uint256 _maxMintableQuantity, 
        bytes calldata _signature
    ) 
        public
        view
        returns(bool _whitelisted)
    {
        bytes32 hash = ECDSA.toEthSignedMessageHash(
            keccak256(
                abi.encodePacked(msg.sender, _maxMintableQuantity)
            )
        );

        return ECDSA.recover(hash, _signature) == teamAddress;
    }

    /**
     * @dev Mint tokens as whitelisted addresses
     * @param _quantity Quantity of tokens that the address wants to mint
     * @param _maxMintableQuantity Maximum Quantity of tokens that the address can mint
     * @param _signature Signature used to verify the address is in the whitelist
     */
    function whitelistMint(
        uint256 _quantity, 
        uint256 _maxMintableQuantity, 
        bytes calldata _signature
    )
        external
        mintWhitelistActive
    {
        // If this signature is from a valid signer
        if (!verify(_maxMintableQuantity, _signature)) {
            revert InvalidSignature();
        }

        // If mint quantity exceed maximum mintable amount
        if (_numberMinted(msg.sender) + _quantity > _maxMintableQuantity) {
            revert ExceedAmount();
        }

        _safeMint(msg.sender, _quantity);
    }

    /**
     * @dev Mint for internal team.
     * @param _quantity Quantity of tokens that the address wants to mint
     */
    function teamMint(uint256 _quantity) 
        external
        onlyTeam
    {
        // If mint quantity exceed maximum mintable amount
        if (_numberMinted(msg.sender) + _quantity > amountForDevs) {
            revert ExceedAmount();
        }

        _safeMint(msg.sender, _quantity);
    }

    /**
     * @dev Internal minting called by #whitelistMint and #teamMint
     * @param _to Address to mint tokens
     * @param _quantity Amount of tokens
     */
    function _safeMint(
        address _to, 
        uint256 _quantity
    ) 
        internal 
        override
        nonReentrant
    {
        // Check if the mint amount will exceed the maximum token supply
        if (_totalMinted() + _quantity > maxSupply) {
            revert ExceedAmount();
        }

        super._safeMint(_to, _quantity);
    }

    /** 
     * @dev Retrieve token URI to get the metadata of a token
     * @param _tokenId TokenId which caller wants to get the metadata of
     */
	function tokenURI(uint256 _tokenId) 
        public 
        view 
        override
        returns (string memory _tokenURI) 
    {
        if (!_exists(_tokenId)) {
            revert TokenNotExist();
        }
        
		return bytes(baseURI).length > 0
            ? string(abi.encodePacked(baseURI, _tokenId.toString(), uriSuffix))
            : '';
	}

    /** 
     * @dev Set the mint time for whitelist users
     * @param _startTime After this timestamp the mint phase will be enabled
     * @param _endTime After this timestamp the mint phase will be disabled
     */
    function setWhitelistMintPhase(
        uint256 _startTime,
        uint256 _endTime
    ) 
        external
        onlyOwner
        setTimeCheck(_startTime, _endTime)
    {        
        mintWhitelistStartTime = _startTime;
        mintWhitelistEndTime = _endTime;
        emit PhaseSet(_startTime, _endTime, "Whitelist");
    }

    /** 
     * @dev Set the base URI for tokenURI, which returns the metadata of the tokens
     * @param _baseURI Base URI that caller wants to set with tokenURI
     */
    function setBaseURI(string memory _baseURI)
        external
        onlyOwner
    {
        baseURI = _baseURI;
        emit URISet(_baseURI, "BaseURI");
    }

    /** 
     * @dev Set the URI suffix for tokenURI, which returns the metadata of the tokens
     * @param _uriSuffix URI suffix that caller wants to set with tokenURI
     */
    function setURISuffix(string memory _uriSuffix)
        external
        onlyOwner
    {
        uriSuffix = _uriSuffix;
        emit URISet(_uriSuffix, "Suffix");
    }

    /** 
     * @dev Set the royalties information for platforms that support ERC2981, LooksRare & X2Y2
     * @param _receiver Address that should receive royalties
     * @param _feeNumerator Amount of royalties that collection creator wants to receive
     */
    function setDefaultRoyalty(
        address _receiver, 
        uint96 _feeNumerator
    )
        external
        onlyOwner
    {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    /** 
     * @dev Set the royalties information for platforms that support ERC2981, LooksRare & X2Y2
     * @param _tokenId Id of the token we are setting
     * @param _receiver Address that should receive royalties
     * @param _feeNumerator Amount of royalties that collection creator wants to receive
     */
    function setTokenRoyalty(
        uint256 _tokenId,
        address _receiver,
        uint96 _feeNumerator
    ) 
        external 
        onlyOwner 
    {
        _setTokenRoyalty(_tokenId, _receiver, _feeNumerator);
    }
    
    /**
     * @dev Reset the royalties information for platforms that support ERC2981, LooksRare & X2Y2
     * @param _tokenId Token Id to reset its royalty
     */
    function resetTokenRoyalty(uint256 _tokenId) 
        external 
        onlyOwner 
    {
        _resetTokenRoyalty(_tokenId);
    }

    /** 
     * @dev Retrieve fund from this contract to the treasury with the according amount
     * @param _amount The amount of fund that the caller wants to retrieve
     */
    function withdraw(uint256 _amount)
        external
        onlyOwner
    {
        payable(teamAddress).transfer(_amount);
        emit FundWithdraw(_amount, teamAddress);
    }
}