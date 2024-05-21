// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
error AlreadyDeployed();
import "./validatorsPool.sol";
import "./company.sol";
contract LandContract {
    //................events....................
    event buyGridEvent(address _applicant,uint256 _totalAmount,string _trackId);
    event sellGridEvent(address _seller,uint256 _sellAmount,string _trackId);
    event buyGridV2Event(address _applicant,uint256 _totalAmount,string _trackId);
    event buyGridForSellEvent(address _applicant,uint256 _amount,string _trackId);
    event unBlockGridsEvent(GridDetails[] grids,uint256 _landId,string _trackId);
    //................enums....................
    enum gridStatus{
        sales,
        sell,
        sold,
        stakeV2,
        nft
    }

    enum accessibleFunctions{
        createLand,
        createAllLand,
        updateLand,
        remove,
        unBlockGrid
    }
    //.............varaibles..............//
    address public immutable owner;
    IERC20 public token;
    uint256 public percentChangeLandPrice;
    address public salesContractAddress;
    ValidatorsPool public validatorsPool;
    uint256 public tax;
    address public headSeasonContract;
    Company public companyContract;
    address public stakeV2ContractAddress;
    address public nftContractAddress;
    uint8 public minimumBuyGrid=1;
    uint8 public maximumBuyGrid=50;
    uint256 public companyBuyGridMaticFee=200000000000000000;
    //..............................structs............................//
    struct landDetails {
        string tag;
        uint256 defaultPrice;
        uint256 landX;
        uint256 landY;
        uint256 fixedArea;
        uint256 TotalNumberGridSold;
    }

    struct gridOwnerDetails {
        address currentAddress;
        uint256 price;
        gridhistory[] gridHistory;
        gridStatus status;
    }

    struct gridhistory {
        address userAddress;
        uint256 price;
    }

    struct sellGridDetails {
        address gridOwner;
        uint256 sellPrice;
        bool isSold;
    }

    struct GridDetails {
        uint256 row;
        uint256 column;
    }

    struct createLands{
        uint256 landId;
        string tag;
        uint256 defaultPrice;
        uint256 landX;
        uint256 landY;
        uint256 fixedArea;
    }

    struct addGridOwner{
        address owner;
        uint256 row;
        uint256 column;
        uint256 price;
    }

    //...................maps..........................//
    mapping (uint256=>mapping(uint256 => mapping(uint256 => gridOwnerDetails))) public gridOwner;
    mapping(uint256 =>mapping(uint256 => mapping(uint256 => sellGridDetails))) public sellGridHistory;
    mapping(uint256 => landDetails) public land;
    mapping(address=>mapping (uint8 => bool))public operators;
    //..........................modifiers.............................//
    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner of the contract");
        _;
    }

    modifier notAlreadyDeployed(uint256 _landId){
        if(land[_landId].landX > 0){
            revert AlreadyDeployed();
        }
        _;
    }

    modifier onlySalesContract(){
        require(msg.sender==salesContractAddress,"This function can only call by sales contract");
        _;
    }

    modifier onlyHeadSeasonContract(){
        if(msg.sender==owner || msg.sender==headSeasonContract){
            _;
        }
        else{
            revert("This function can only call by headSeason contract or owner of the contract");
        }
    }

    modifier onlyValidatorsPoolContract(){
        require(msg.sender==address(validatorsPool),"This function can only call by validatorsPool contract");
        _;
    }

    modifier onlyStakeV2Contract(){
        require(msg.sender==stakeV2ContractAddress,"This function can only call by stakeV2 contract");
        _;
    }

    modifier onlyNFTContract(){
        require(msg.sender==nftContractAddress,"This function can only call by NFT contract");
        _;
    }

    modifier onlyOwnerAndOperators(uint8 _accessibleFunctionsId){
        if(msg.sender==owner || operators[msg.sender][_accessibleFunctionsId]){
            _;
        }
        else{
            revert("You are not the owner of the contract or you don't have access to call this function");
        }
    }

    constructor(address _token, uint256 _percentChangeLandPrice, uint256 _tax,address _companyContractAddress) {
        owner = msg.sender;
        token = IERC20(_token);
        percentChangeLandPrice = _percentChangeLandPrice;
        tax=_tax;
        companyContract=Company(_companyContractAddress);
    }

    function createLand(createLands memory _land)
        public
        onlyOwnerAndOperators(0)
        notAlreadyDeployed(_land.landId)
    {
        land[_land.landId].tag=_land.tag;
        land[_land.landId].defaultPrice=_land.defaultPrice;
        land[_land.landId].landX=_land.landX;
        land[_land.landId].landY=_land.landY;
        land[_land.landId].fixedArea=_land.fixedArea;
        land[_land.landId].TotalNumberGridSold=0;
    }

    function createAllLand(createLands[] memory _lands) public onlyOwnerAndOperators(1){
        for (uint256 i=0; i<_lands.length; i++) 
        {   if(land[_lands[i].landId].landX > 0){
                revert AlreadyDeployed();
            }
            land[_lands[i].landId].tag=_lands[i].tag;
            land[_lands[i].landId].defaultPrice=_lands[i].defaultPrice;
            land[_lands[i].landId].landX=_lands[i].landX;
            land[_lands[i].landId].landY=_lands[i].landY;
            land[_lands[i].landId].fixedArea=_lands[i].fixedArea;
            land[_lands[i].landId].TotalNumberGridSold=0;
        }
    }

    function updateLand(uint256 _landId, landDetails memory _land)
        public
        onlyOwnerAndOperators(2)
    {
        land[_landId].tag = _land.tag;
        land[_landId].landX=_land.landX;
        land[_landId].landY=_land.landY;
    }

    function removeLand(uint256 _landId) public onlyOwnerAndOperators(3) {
        delete land[_landId];
    }

    //.........................Grid..........................//

    function buyGrid(GridDetails[] memory buyDetails,uint256 _landId,string memory _trackId) public payable{
        require(address(validatorsPool)!=address(0),"The validatorPool contract is not defined");
        require(land[_landId].defaultPrice != 0,"land is not found");
        if(minimumBuyGrid>buyDetails.length || buyDetails.length>maximumBuyGrid){
            revert("You can only buy 1 to 4 grid");
        }
        uint256 totalAmount = 0;
        for (uint256 i; i < buyDetails.length; i++) {
                uint256 fixArea=(land[_landId].fixedArea + ((land[_landId].fixedArea * percentChangeLandPrice)/100));
                if (fixArea<=land[_landId].TotalNumberGridSold) {
                    land[_landId].defaultPrice+=(land[_landId].defaultPrice*percentChangeLandPrice)/100;
                    land[_landId].fixedArea=land[_landId].TotalNumberGridSold;
                }

                if (
                    1 <= buyDetails[i].row &&
                    land[_landId].landX >= buyDetails[i].row &&
                    1 <= buyDetails[i].column &&
                    land[_landId].landY >= buyDetails[i].column
                ) {
                    if (gridOwner[_landId][buyDetails[i].row][buyDetails[i].column].price == 0) {
                        gridOwner[_landId][buyDetails[i].row][buyDetails[i].column].currentAddress = msg.sender;
                        gridOwner[_landId][buyDetails[i].row][buyDetails[i].column].price = land[_landId].defaultPrice;
                        gridOwner[_landId][buyDetails[i].row][buyDetails[i].column].status=gridStatus.sold;
                        gridOwner[_landId][buyDetails[i].row][buyDetails[i].column].gridHistory.push(gridhistory(msg.sender,land[_landId].defaultPrice));
                        land[_landId].TotalNumberGridSold++;
                        totalAmount += land[_landId].defaultPrice;
                    }
                    else{
                        revert("Some of the grids you want to buy have already been purchased");
                    }
                }
                else{
                    revert("Grid is out of the land");
                }
        }
        if (totalAmount != 0) {
            uint256 validatorsProfit=(totalAmount*tax)/1000;
            uint256 companyTransferAmount=(totalAmount-validatorsProfit);
            companyContract.addLiquidity(companyTransferAmount);
            token.transferFrom(msg.sender, address(companyContract), companyTransferAmount);
            validatorsPool.addLiquidity(validatorsProfit);
            token.transferFrom(msg.sender,address(validatorsPool), validatorsProfit);
            require(msg.value==companyBuyGridMaticFee,"You must pay the buy Grid Fee");
            emit buyGridEvent(msg.sender, totalAmount,_trackId);
        }
    }

    function sellGrid(
        uint256 _landId,
        uint256 _row,
        uint256 _column,
        uint256 _sellPrice,
        string memory _trackId
    ) public {
        require(
            gridOwner[_landId][_row][_column].currentAddress == msg.sender,
            "This grid is not belong to you"
        );
        require(gridOwner[_landId][_row][_column].status==gridStatus.sold,"Grid must be in sold state");
        require(gridOwner[_landId][_row][_column].price<=_sellPrice,"sell price should be greater than price you bought");
        sellGridHistory[_landId][_row][_column] = sellGridDetails(
            msg.sender,
            _sellPrice,
            false
        );
        gridOwner[_landId][_row][_column].status=gridStatus.sell;
        emit sellGridEvent(msg.sender,_sellPrice,_trackId);
    }

    function buyGridForSell(uint256 _landId,uint256 _row, uint256 _column,string memory _trackId) public {
        require(address(validatorsPool)!=address(0),"The validatorPool contract is not defined");
        sellGridDetails memory _sellGrid = sellGridHistory[_landId][_row][_column];
        require(_sellGrid.sellPrice != 0, "This Grid is not in the sell list");
        require(_sellGrid.isSold==false,"This grid is already solded");
        //............................calculation of profits...........................
        uint256 companyTransferAmount;
        uint256 priceDifference=(_sellGrid.sellPrice-gridOwner[_landId][_row][_column].price);
        uint256 sellerTransferAmount=(gridOwner[_landId][_row][_column].price)+((priceDifference * 70)/100);
        if(tax>300){
            companyTransferAmount=(((priceDifference) * 300) /1000);
        }
        else{
            companyTransferAmount=(((priceDifference) * tax) /1000);
        }
        uint256 validatorsTransferAmount=priceDifference-(((priceDifference * 70)/100)+companyTransferAmount);
        //...........................transfer profits.........................
        require(
            token.transferFrom(
                msg.sender,
                _sellGrid.gridOwner,
                sellerTransferAmount
            ),
            "Transfer Faild"
        );
        if(validatorsTransferAmount!=0){
            require(token.transferFrom(msg.sender, address(validatorsPool), validatorsTransferAmount),"Transfer Faild");
            validatorsPool.addLiquidity(validatorsTransferAmount);
        }
        require(token.transferFrom(msg.sender, address(companyContract), companyTransferAmount),"Transfer Faild");
        companyContract.addLiquidity(companyTransferAmount);
        
        sellGridHistory[_landId][_row][_column].isSold = true;
        gridOwner[_landId][_row][_column].currentAddress = msg.sender;
        gridOwner[_landId][_row][_column].status=gridStatus.sold;
        gridOwner[_landId][_row][_column].price = _sellGrid.sellPrice;
        gridOwner[_landId][_row][_column].gridHistory.push(
            gridhistory(msg.sender, _sellGrid.sellPrice)
        );
        
        emit buyGridForSellEvent(msg.sender,_sellGrid.sellPrice,_trackId);
    }

    function getGridOwner(uint256 _landId,uint256 _row, uint256 _column)
        public
        view
        returns (address ownerAddress,uint256 ownerPrice,gridStatus state)
    {
        return (gridOwner[_landId][_row][_column].currentAddress,gridOwner[_landId][_row][_column].price,gridOwner[_landId][_row][_column].status);
    }

    function updateGridOwner(
        uint256 _landId,
        uint256 _row,
        uint256 _column,
        address _newGridOwner,
        uint256 _price
    ) public  onlySalesContract(){
        gridOwner[_landId][_row][_column].currentAddress = _newGridOwner;
        gridOwner[_landId][_row][_column].price = _price;
        gridOwner[_landId][_row][_column].status=gridStatus.sold;
        gridOwner[_landId][_row][_column].gridHistory.push(
            gridhistory(_newGridOwner, _price)
        );
    }

    function addSalesContractAddress(address _salesContract)public onlyOwner(){
        salesContractAddress=_salesContract;
    }

    function gridHistory(uint256 _landId,uint256 _row,uint256 _column)public view returns(gridhistory[] memory){
        return gridOwner[_landId][_row][_column].gridHistory;
    }

    function updateTax(uint256 _taxAmount)public onlyValidatorsPoolContract(){
        tax=_taxAmount;
    }

    function updateValidatorsPoolContractAddress(address _validatorsPool)public onlyHeadSeasonContract(){
        validatorsPool=ValidatorsPool(_validatorsPool);
    }

    function updateHeadSeasonContract(address _headSeasonAddress)public onlyOwner(){
        headSeasonContract=_headSeasonAddress;
    }

    function updateCompanyContractAddress(address _newCompanyContractAddress)public onlyOwner(){
        companyContract=Company(_newCompanyContractAddress);
    }

    function updateGridStatusToSales(uint256 _landId,uint256 _row,uint256 _column)public onlySalesContract(){
        gridOwner[_landId][_row][_column].status=gridStatus.sales;
    } 

    
    function buyGridFromStakeV2(GridDetails[] memory buyDetails,uint256 _landId,address _applicant,string memory _trackId)public onlyStakeV2Contract(){
        require(land[_landId].defaultPrice != 0,"land is not found");
        uint256 totalAmount = 0;
        for (uint256 i; i < buyDetails.length; i++) {
                uint256 fixArea=(land[_landId].fixedArea + ((land[_landId].fixedArea * percentChangeLandPrice)/100));
                if (fixArea<=land[_landId].TotalNumberGridSold) {
                    land[_landId].defaultPrice+=(land[_landId].defaultPrice*percentChangeLandPrice)/100;
                    land[_landId].fixedArea=land[_landId].TotalNumberGridSold;
                }

                if (
                    1 <= buyDetails[i].row &&
                    land[_landId].landX >= buyDetails[i].row &&
                    1 <= buyDetails[i].column &&
                    land[_landId].landY >= buyDetails[i].column
                ) {
                    if (gridOwner[_landId][buyDetails[i].row][buyDetails[i].column].price == 0) {
                        gridOwner[_landId][buyDetails[i].row][buyDetails[i].column].currentAddress = _applicant;
                        gridOwner[_landId][buyDetails[i].row][buyDetails[i].column].price = land[_landId].defaultPrice;
                        gridOwner[_landId][buyDetails[i].row][buyDetails[i].column].status=gridStatus.stakeV2;
                        gridOwner[_landId][buyDetails[i].row][buyDetails[i].column].gridHistory.push(gridhistory(_applicant,land[_landId].defaultPrice));
                        land[_landId].TotalNumberGridSold++;
                        totalAmount += land[_landId].defaultPrice;
                    }
                    else{
                        revert("Some of the grids you want to buy have already been purchased");
                    }
                }
                else{
                    revert("Grid is out of the land");
                }
        }
        if (totalAmount != 0) {
            require(token.transferFrom(msg.sender, address(companyContract), totalAmount));
            companyContract.addLiquidity(totalAmount);
            emit buyGridV2Event(msg.sender, totalAmount,_trackId);
        }
    }

    function addStakeV2ContractAddress(address _stakeV2ContractAddress)public onlyOwner(){
        stakeV2ContractAddress=_stakeV2ContractAddress;
    }

    function unBlockGrid(GridDetails[] memory grids,uint256 _landId,string memory _trackId)public onlyOwnerAndOperators(4){
        require(land[_landId].defaultPrice != 0,"land is not found");
        for (uint256 i; i < grids.length; i++) {
            if (
                    1 <= grids[i].row &&
                    land[_landId].landX >= grids[i].row &&
                    1 <= grids[i].column &&
                    land[_landId].landY >= grids[i].column
            ) {
                    if(gridOwner[_landId][grids[i].row][grids[i].column].status==gridStatus.stakeV2){
                        gridOwner[_landId][grids[i].row][grids[i].column].status=gridStatus.sold;
                    }
            }
            else{
                    revert("Grid is out of the land");
            }
        }
        emit unBlockGridsEvent(grids,_landId,_trackId);
    }

    function getGridsPrice(GridDetails[] memory buyDetails,uint256 _landId) public view returns(uint256){
        require(land[_landId].defaultPrice != 0,"land is not found");
        uint256 landFixedArea=land[_landId].fixedArea;
        uint256 landTotalNumberGridSold=land[_landId].TotalNumberGridSold;
        uint256 landDefaultPrice=land[_landId].defaultPrice;
        uint256 totalAmount = 0;
        for (uint256 i; i < buyDetails.length; i++) {
                uint256 fixArea=(landFixedArea + ((landFixedArea * percentChangeLandPrice)/100));
                if (fixArea<=landTotalNumberGridSold) {
                    landDefaultPrice+=(landDefaultPrice*percentChangeLandPrice)/100;
                    landFixedArea=landTotalNumberGridSold;
                }

                if (
                    1 <= buyDetails[i].row &&
                    land[_landId].landX >= buyDetails[i].row &&
                    1 <= buyDetails[i].column &&
                    land[_landId].landY >= buyDetails[i].column
                ) {
                    if (gridOwner[_landId][buyDetails[i].row][buyDetails[i].column].price == 0) {
                        landTotalNumberGridSold++;
                        totalAmount += landDefaultPrice;
                    }
                    else{
                        revert("Some of the grids you want to buy have already been purchased");
                    }
                }
                else{
                    revert("Grid is out of the land");
                }
        }
        return totalAmount;
    }

    function addOperator(address _operator,uint8 _accessibleFunctionsId)public onlyOwner(){
        require(!operators[_operator][_accessibleFunctionsId],"operator is already added");
        operators[_operator][_accessibleFunctionsId]=true;
    }

    function removeOperator(address _operator,uint8 _accessibleFunctionsId)public onlyOwner(){
        require(operators[_operator][_accessibleFunctionsId],"operator not found");
        delete operators[_operator][_accessibleFunctionsId];
    }

    function updateGridStatusToNFT(GridDetails[] memory grids,uint256 _landId)public onlyNFTContract(){
        require(land[_landId].defaultPrice != 0,"land is not found");
        for (uint256 i; i < grids.length; i++) {
            if (
                    1 <= grids[i].row &&
                    land[_landId].landX >= grids[i].row &&
                    1 <= grids[i].column &&
                    land[_landId].landY >= grids[i].column
            ) {
                    if(gridOwner[_landId][grids[i].row][grids[i].column].status==gridStatus.sold){
                        gridOwner[_landId][grids[i].row][grids[i].column].status=gridStatus.nft;
                    }
            }
            else{
                    revert("Grid is out of the land");
            }
        }
    }

    function addNFTContractAddress(address _nftContractAddress)public onlyOwner(){
        nftContractAddress=_nftContractAddress;
    }

    function updatePercentChangeLandPrice(uint256 _percentChangeLandPrice)public onlyOwner(){
        percentChangeLandPrice=_percentChangeLandPrice;
    }

    function updateBuyGridLimitation(uint8 _minimumBuyGrid,uint8 _maximumBuyGrid)public onlyOwner(){
        minimumBuyGrid=_minimumBuyGrid;
        maximumBuyGrid=_maximumBuyGrid;
    }

    function changeMaticFee(uint256 _companyBuyGridMaticFee)public onlyOwner(){
        companyBuyGridMaticFee=_companyBuyGridMaticFee;
    }

    function ownerWithdrawMatic(uint256 _amount)public onlyOwner(){
        (bool success,)=payable(msg.sender).call{value: _amount}("");
        require(success,"Failed to withdraw matic");
    }

    function addGridOwners(addGridOwner[] memory _gridOwners,uint256 _landId)public onlyOwner(){
        for (uint256 i; i<_gridOwners.length; i++) 
        {
            gridOwner[_landId][_gridOwners[i].row][_gridOwners[i].column].currentAddress = _gridOwners[i].owner;
            gridOwner[_landId][_gridOwners[i].row][_gridOwners[i].column].price = _gridOwners[i].price;
            gridOwner[_landId][_gridOwners[i].row][_gridOwners[i].column].status=gridStatus.sold;
            gridOwner[_landId][_gridOwners[i].row][_gridOwners[i].column].gridHistory.push(gridhistory(_gridOwners[i].owner,_gridOwners[i].price));
            land[_landId].TotalNumberGridSold++;
        }
    } 
}
