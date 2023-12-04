// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Market {
    IERC20 public erc20;
    IERC721 public erc721;

    bytes4 internal constant MAGIC_ON_ERC721_RECEIVED = 0x150b7a02;

    struct Order {
        address seller;
        uint tokenId;
        uint price;
    }
    //token id to order
    mapping(uint256 => Order) public orderOfId;
    //存储所有订单数组
    Order[] public orders;
    //token id to index
    mapping(uint => uint256) public idToOrderIndex;  

    //事件买卖，上架，改价，撤单
    event Deal(address seller, address buyer, uint256 tokenId, uint256 price);
    event NewOrder(address seller, uint256 tokenId ,uint256 price);
    event CancelOrder(address seller , uint256 tokenId);
    event ChangePrice(
        address seller,
        uint256 tokenId,
        uint256 previousPrice,
        uint256 price
    );


    constructor(IERC20 _erc20, IERC721 _erc721) {
        require(
            address(_erc20) != address(0),
            "Market: IERC20 contract address must be non-null"
        );
        require(
            address(_erc721) != address(0),
            "Market: IERC721 contract address must be non-null"
        );
        erc20 = _erc20;
        erc721 = _erc721;
    }

    function buy(uint256 _tokenId) external {
        require(isListed(_tokenId),"Market:Token ID is not listed");

        address seller = orderOfId[_tokenId].seller;
        address buyer = msg.sender;
        uint256 price = orderOfId[_tokenId].price;

        require(erc20.transferFrom(buyer, seller, price),"transfer not successful");
        erc721.safeTransferFrom(address(this), buyer, _tokenId);
        removeListing(_tokenId);

        emit Deal(buyer,seller, _tokenId, price);
    }

    //取消订单
    function cancelOrder(uint256 _tokenId) external {
        require(isListed(_tokenId),"Market:Token ID is not listed");

            address seller = orderOfId[_tokenId].seller;
            //确认是不是本人
            require(msg.sender == seller,"not seller");
            erc721.safeTransferFrom(address(this), seller, _tokenId);
            removeListing(_tokenId);
            emit CancelOrder(seller, _tokenId);
        }

        function changePrice(uint256 _tokenId,uint256 _price) external {
            require(isListed(_tokenId),"Market:Token ID is not listed");
            address seller = orderOfId[_tokenId].seller;
            //确认是不是本人
            require(seller == msg.sender,"not seller");

            uint256 previousPrice = orderOfId[_tokenId].price;
            orderOfId[_tokenId].price= _price;
            Order storage order = orders[idToOrderIndex[_tokenId]];
            order.price = _price;

            emit ChangePrice(seller, _tokenId, previousPrice, _price);
        }


        function getAllNFTs() public view returns (Order[] memory) {
            return orders;
        }

        function getMyNFTs() public view returns (Order[] memory) {
            Order[] memory myOrders = new Order[](orders.length);
            uint256 myOrdersCount = 0;

            for (uint256 i = 0;i < orders.length;i++) {
                if (orders[i].seller == msg.sender) {
                    myOrders[myOrdersCount] = orders[i];
                    myOrdersCount++;
                }
            }

            Order[] memory myOrdersTrimmed = new Order[](myOrdersCount);
            for (uint256 i = 0;i<myOrdersCount;i++) {
                myOrdersTrimmed[i] = myOrders[i];
            }

            return myOrdersTrimmed;
        }

        function isListed(uint256 _tokenId)public view returns (bool) {
            return orderOfId[_tokenId].seller != address(0);
        }
        function getOrderLength() public view returns (uint256) {
            return orders.length;
        }


        //上架
        function onERC721Received(
            address _operator,
            address _seller,
            uint256 _tokenId,
            bytes calldata _data
        ) public  returns (bytes4) {
            require(_operator == _seller, "Market: Seller must be operator");
            uint256 _price = toUint256(_data, 0);
            placeOrder(_seller, _tokenId, _price);

            return MAGIC_ON_ERC721_RECEIVED;
        }

        

        function toUint256(
            bytes memory _bytes,
            uint256 _start
        ) public pure returns (uint256) {
            require(_start + 32 >= _start,"Market:toUint256_overflow");
            require(_bytes.length >= _start+32,"Market:toUint256_outOfBounds");
            uint256 tempUint;

            assembly {
            tempUint := mload(add(add(_bytes, 0x20), _start))
        }


            return tempUint;
        }

        function placeOrder(
            address _seller,
            uint256 _tokenId,
            uint256 _price
        )internal {
            require(_price > 0,"Market:Price must be greater than zero");

            orderOfId[_tokenId].seller = _seller;
            orderOfId[_tokenId].price = _price;
            orderOfId[_tokenId].tokenId = _tokenId;

            orders.push(orderOfId[_tokenId]);
            idToOrderIndex[_tokenId] = orders.length - 1;

            emit NewOrder(_seller, _tokenId, _price);
        }

        function removeListing(uint256 _tokenId) internal {
        delete orderOfId[_tokenId];

        uint256 orderToRemoveIndex = idToOrderIndex[_tokenId];
        uint256 lastOrderIndex = orders.length - 1;

        if (lastOrderIndex != orderToRemoveIndex) {
            Order memory lastOrder = orders[lastOrderIndex];
            orders[orderToRemoveIndex] = lastOrder;
            idToOrderIndex[lastOrder.tokenId] = orderToRemoveIndex;
        }

        orders.pop();
    }
    
}