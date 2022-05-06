pragma solidity ^0.8.13;


import '../accesscontrol/FarmerRole.sol';
import '../accesscontrol/ConsumerRole.sol';
import '../accesscontrol/DistributorRole.sol';
import '../accesscontrol/RetailerRole.sol';
import '../accesscontrol/ManufacturerRole.sol';
import '../core/Ownable.sol';


// Define a contract 'Supplychain'
contract SupplyChain is Ownable, FarmerRole, DistributorRole, RetailerRole, ManufacturerRole, ConsumerRole {

  // Define a variable called 'upc' for Universal Product Code (UPC) - for tracking a product
  uint  upc;
  // Define a variable called 'sku' for Stock Keeping Unit (SKU) - for tracking movements 
  uint  sku;

  // Define a public mapping 'items' that maps the UPC to an Item.
  mapping (uint => Product) products;

  // Define a public mapping for 'rawmaterials' that map a lotNumber to each harvest time based on material id, timestamp and farmerid
  mapping (uint => RawMaterial) rawMaterials;

  // Define enum 'State' with the following values:
  enum State
  {
    Harvested,                 // 0
    Packed,                    // 1
    BoughtByManufacturer,      // 2
    Processed,                 // 3
    PackedByManufacturer,      // 4
    BoughtByDistributor,       // 5
    Shipped,                   // 6
    ReceivedByRetailer,        // 7
    Placed,                    // 8
    Purchased                  // 9
    }

  State constant defaultState = State.Harvested;

  // Define 8 events with the same 8 state values and accept 'upc' as input argument
  event Harvested(uint lotNumber);
  event Packed(uint lotNumber);
  event BoughtByManufacturer(uint lotNumber);
  event Processed(uint upc);
  event PackedByManufacturer(uint upc);
  event BoughtByDistributor(uint upc);
  event Shipped(uint upc);
  event ReceivedByRetailer(uint upc);
  event Placed(uint upc);
  event Purchased(uint upc);

  // Define a struct "RawMaterial" with the following fields
  struct RawMaterial{
    address payable ownerID;  // Metamask-Ethereum address of the current owner as the product moves through 8 stages
    address payable farmerID; // Metamask-Ethereum address of the Farmer
    address payable manufacturerID; // Address of the Manufacturer
    uint    lotNumber;
    uint    originFarmID;
    string  originFarmName;  // Farmer Information
    string  originFarmLatitude; // Farm Latitude
    string  originFarmLongitude;  // Farm Longitude
    string  materialName;
    uint    materialID;
    uint    rawMaterialMaxQuantity;
    uint    rawMaterialQuantity;
    uint    rawMaterialPrice;
    uint    harvestTime;
    State   materialState;
  }

  // Define a struct 'Item' with the following fields:
  struct Product {
    uint    sku;  // Stock Keeping Unit (SKU)
    uint    upc; // Universal Product Code (UPC), generated by the Farmer, goes on the package, can be verified by the Consumer
    address payable ownerID;
    address payable distributorID;  // Metamask-Ethereum address of the Distributor
    address payable manufacturerID; // Address of the Manufacturer
    address payable retailerID; // Metamask-Ethereum address of the Retailer
    address payable consumerID; // Metamask-Ethereum address of the Consumer
    uint    productID;  // Product ID potentially a combination of upc + sku
    string  productName;
    uint    productBasePrice; // Product Price
    uint    productFinalPrice;
    uint[] materialsUsed;
    State   productState;  // Product State as represented in the enum above
  }

  // Define a modifer that verifies the Caller
  modifier verifyCaller (address _address) {
    require(msg.sender == _address, "This account is not the owner of this item");
    _;
  }

  // Define a modifier that checks if the paid amount is sufficient to cover the price
  modifier paidEnough(uint _price) {
    require(msg.value >= _price, "The amount sent is not sufficient for the price");
    _;
  }

  modifier verifyQuantity(uint _lotNumber, uint _quantity) {
    require(rawMaterials[_lotNumber].rawMaterialMaxQuantity >= _quantity, "The quantity required is not enough");
    _;
    uint maxQuantity = rawMaterials[_lotNumber].rawMaterialMaxQuantity;
    rawMaterials[_lotNumber].rawMaterialMaxQuantity = maxQuantity - _quantity;
  }

  // Define a modifier that checks the price and refunds the remaining balance
  modifier checkValueForManufacturer(uint _lotNumber) {
    _;
    uint price = rawMaterials[_lotNumber].rawMaterialPrice;
    uint amountToReturn = msg.value - price;
    rawMaterials[_lotNumber].manufacturerID.transfer(amountToReturn);
  }

  // Define a modifier that checks the price and refunds the remaining balance
  modifier checkValueForDistributor(uint _upc) {
    _;
    uint price = products[_upc].productBasePrice;
    uint amountToReturn = msg.value - price;
    products[_upc].distributorID.transfer(amountToReturn);
  }

  // Define a modifier that checks the price and refunds the remaining balance
  // to the Consumer
  modifier checkValueForConsumer(uint _upc) {
    _;
    uint _price = products[_upc].productFinalPrice;
    uint amountToReturn = msg.value - _price;
    products[_upc].consumerID.transfer(amountToReturn);
  }

  modifier checkMaterialsOwner(uint[] memory _lotNumbers) {
    for(uint i=0; i < _lotNumbers.length; i++) {
      uint rmID = _lotNumbers[i];
      require(rawMaterials[rmID].ownerID == msg.sender, "The Manufacturer does not own the current RawMaterial!");
    }
    _;
  }

  // Define a modifier that checks if an item.state of a upc is Harvested
  modifier harvested(uint _lotNumber) {
    require(rawMaterials[_lotNumber].materialState == State.Harvested, "The Item is not in Harvested state!");
    _;
  }

  // Define a modifier that checks if an item.state of a upc is Packed
  modifier packed(uint _lotNumber) {
    require(rawMaterials[_lotNumber].materialState == State.Packed, "The Item is not in Packed state!");
    _;
  }

  // Define a modifier that checks if an item.state of a upc is Processed
  modifier processed(uint _upc) {
    require(products[_upc].productState == State.Processed, "The Item is not in Processed state!");
    _;
  }

  // Define a modifier that checks if an item.state of a upc is BoughtByManufacturer
  modifier packed_by_manufacturer(uint _upc) {
    require(products[_upc].productState == State.PackedByManufacturer, "The Item is not in PackedByManufacturer state!");
    _;
  }

  // Define a modifier that checks if an item.state of a upc is BoughtByDistributor
  modifier bought_by_distributor(uint _upc) {
    require(products[_upc].productState == State.BoughtByDistributor, "The Item is not in BoughtByDistributor state!");
    _;
  }

  // Define a modifier that checks if an item.state of a upc is Shipped
  modifier shipped(uint _upc) {
    require(products[_upc].productState == State.Shipped, "The Item is not in Shipped state!");
    _;
  }

  // Define a modifier that checks if an item.state of a upc is ReceivedByRetailer
  modifier received_by_retailer(uint _upc) {
    require(products[_upc].productState == State.ReceivedByRetailer, "The Item is not in ReceivedByRetailer state!");
    _;
  }

  modifier placed(uint _upc) {
    require(products[_upc].productState == State.Placed, "The Item is not in Placed state!");
    _;
  }

  // Define a modifier that checks if an item.state of a upc is Purchased
  modifier purchased(uint _upc) {
    require(products[_upc].productState == State.Purchased, "The Item is not in Purchased state!");
    _;
  }

  // and set 'sku' to 1
  // and set 'upc' to 1
  // Using Ownable to define the ownwerm
  constructor() {
    sku = 1;
    upc = 1;
  }

  // Define a function 'harvestItem' that allows a farmer to mark an item 'Harvested'
  function harvestItem(uint    _originFarmID,
                       string  memory _originFarmName,  
                       string  memory _originFarmLatitude,
                       string  memory _originFarmLongitude,
                       string  memory _materialName,
                       uint    _materialID,
                       uint    _rawMaterialMaxQuantity) 
                       public 
                       onlyFarmer
  {
    // Add the new item as part of Harvest
    RawMaterial memory newMaterial;
    newMaterial.ownerID = payable(msg.sender);
    newMaterial.farmerID = payable(msg.sender);
    newMaterial.originFarmName = _originFarmName;
    newMaterial.originFarmID = _originFarmID;
    newMaterial.originFarmLatitude = _originFarmLatitude;
    newMaterial.originFarmLongitude = _originFarmLongitude;
    newMaterial.materialName = _materialName;
    newMaterial.materialID = _materialID;
    newMaterial.rawMaterialMaxQuantity = _rawMaterialMaxQuantity;
    newMaterial.harvestTime = block.timestamp;
    uint rmID = _originFarmID + _materialID + newMaterial.harvestTime;
    newMaterial.lotNumber = rmID;
    // Setting state
    newMaterial.materialState = State.Harvested;
    // Adding new Item to map
    rawMaterials[rmID] = newMaterial;
    // Emit the appropriate event
    emit Harvested(rmID);
  }

  // Define a function 'packItem' that allows a farmer to mark an item 'Packed'
  function packItem(uint _lotNumber,
                    uint _quantity,
                    uint _price)
                    public 
                    onlyFarmer 
                    harvested(_lotNumber) 
                    verifyCaller(rawMaterials[_lotNumber].ownerID) 
                    verifyQuantity(_lotNumber, _quantity)
  {
    // Update the appropriate fields
    RawMaterial storage existingMaterial = rawMaterials[_lotNumber];
    existingMaterial.rawMaterialQuantity = _quantity;
    existingMaterial.rawMaterialPrice = _price;
    existingMaterial.materialState = State.Packed;
    // Emit the appropriate event
    emit Packed(_lotNumber);
  }

  // Define a function 'buyItem' that allows the disributor to mark an item 'Sold'
  // Use the above defined modifiers to check if the item is available for sale, if the buyer has paid enough,
  // and any excess ether sent is refunded back to the buyer
  function buyMaterial(uint _lotNumber) 
                       public 
                       payable 
                       onlyManufacturer 
                       packed(_lotNumber) 
                       paidEnough(rawMaterials[_lotNumber].rawMaterialPrice) 
                       checkValueForManufacturer(_lotNumber)
    {
    // Update the appropriate fields - ownerID, distributorID, itemState
    RawMaterial storage existingMaterial = rawMaterials[_lotNumber];
    existingMaterial.ownerID = payable(msg.sender);
    existingMaterial.manufacturerID = payable(msg.sender);
    existingMaterial.materialState = State.BoughtByManufacturer;
    // Transfer money to farmer
    uint materialPrice = rawMaterials[_lotNumber].rawMaterialPrice;
    rawMaterials[_lotNumber].farmerID.transfer(materialPrice);
    // emit the appropriate event
    emit BoughtByManufacturer(_lotNumber);
  }


  function processProduct(uint    _upc,
                          uint[]  memory _lotNumbers,
                          string  memory _productName)
                          public
                          onlyManufacturer
                          checkMaterialsOwner(_lotNumbers)
  {
    Product memory newProduct;
    newProduct.ownerID = payable(msg.sender);
    newProduct.manufacturerID = payable(msg.sender);
    newProduct.upc = _upc;
    newProduct.sku = sku;
    newProduct.productID = _upc + sku;
    newProduct.materialsUsed = _lotNumbers;
    newProduct.productName = _productName;
    newProduct.productState = State.Processed;
    // Increment sku
    sku = sku + 1;
    // Add newProduct to mapping
    products[_upc] = newProduct;
    // Emit proper event
    emit Processed(_upc);
  }

  function packProduct(uint _upc,
                       uint _productBasePrice)
                       public
                       onlyManufacturer
                       processed(_upc)
                       verifyCaller(products[_upc].ownerID) 
  {
    Product storage existingProduct = products[_upc];
    existingProduct.productBasePrice = _productBasePrice;
    existingProduct.productState = State.PackedByManufacturer;
    emit PackedByManufacturer(_upc);
  }

  // Define a function 'shipItem' that allows the distributor to mark an item 'Shipped'
  // Use the above modifers to check if the item is sold
  function buyProduct(uint _upc) 
                      public
                      payable
                      onlyDistributor
                      packed_by_manufacturer(_upc)
                      paidEnough(products[_upc].productBasePrice) 
                      checkValueForDistributor(_upc)
    {
    // Update the appropriate fields
    Product storage existingProduct = products[_upc];
    existingProduct.ownerID = payable(msg.sender);
    existingProduct.distributorID = payable(msg.sender);
    existingProduct.productState = State.BoughtByDistributor;
    // Transfer money to farmer
    uint productPrice = products[_upc].productBasePrice;
    products[_upc].manufacturerID.transfer(productPrice);
    // Emit the appropriate event
    emit BoughtByDistributor(_upc);
  }

  function shipProduct(uint _upc) 
                       public
                       onlyDistributor
                       bought_by_distributor(_upc)
                       verifyCaller(products[_upc].distributorID)
    {
    // Update the appropriate fields
    Product storage existingProduct = products[_upc];
    existingProduct.productState = State.Shipped;
    // Emit the appropriate event
    emit Shipped(_upc);
  }

  // Define a function 'receiveItem' that allows the retailer to mark an item 'Received'
  // Use the above modifiers to check if the item is shipped
  function receiveProduct(uint _upc) 
                       public
                       onlyRetailer
                       shipped(_upc)
    {
    // Update the appropriate fields - ownerID, retailerID, itemState
    Product storage existingProduct = products[_upc];
    existingProduct.ownerID = payable(msg.sender);
    existingProduct.productState = State.ReceivedByRetailer;
    existingProduct.retailerID = payable(msg.sender);
    // Emit the appropriate event
    emit ReceivedByRetailer(_upc);
  }

  function placeProduct(uint _upc,
                        uint _productFinalPrice)
                        public
                        onlyRetailer
                        received_by_retailer(_upc)
                        verifyCaller(products[_upc].ownerID)
  {
    // Update the appropriate fields - ownerID, retailerID, itemState
    Product storage existingProduct = products[_upc];
    existingProduct.productFinalPrice = _productFinalPrice;
    existingProduct.productState = State.Placed;
    // Emit the appropriate event
    emit Placed(_upc);
  }

  // Define a function 'purchaseItem' that allows the consumer to mark an item 'Purchased'
  // Use the above modifiers to check if the item is received
  function purchaseProduct(uint _upc) 
                        public 
                        payable 
                        onlyConsumer
                        placed(_upc)
                        paidEnough(products[_upc].productFinalPrice)
                        checkValueForConsumer(_upc)
    {
    // Update the appropriate fields - ownerID, consumerID, itemState
      Product storage existingProduct = products[_upc];
      existingProduct.ownerID = payable(msg.sender);
      existingProduct.productState = State.Purchased;
      existingProduct.consumerID = payable(msg.sender);
    // Emit the appropriate event
      emit Purchased(_upc);
  }

  // Define a function 'fetchItemBufferTwo' that fetches the data
  function fetchRawMaterial(uint _lotNumber) public view returns 
  (
  string memory farmName,
  string memory farmLatitude,
  string memory farmLongitude,
  string memory materialName,
  uint    harvestTime
  ) 
  {
    // Assign values to the 9 parameters
  RawMaterial memory existingMaterial = rawMaterials[_lotNumber];
  farmName = existingMaterial.originFarmName;
  farmLatitude = existingMaterial.originFarmLatitude;
  farmLongitude = existingMaterial.originFarmLongitude;
  materialName = existingMaterial.materialName;
  harvestTime = existingMaterial.harvestTime;
  
  return 
  (
  farmName,
  farmLatitude,
  farmLongitude,
  materialName,
  harvestTime
  );
  }


  function fetchProductLots(uint _upc) public view returns 
  (
    uint[] memory lotNumbers
  )
  {
    Product memory existingProduct = products[_upc];
    lotNumbers = existingProduct.materialsUsed;
    return (lotNumbers);
  }
}
