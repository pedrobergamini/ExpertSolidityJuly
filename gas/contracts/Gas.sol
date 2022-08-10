// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "./Ownable.sol";

library Constants {
    uint256 internal constant tradeFlag = 1;
    uint256 internal constant basicFlag = 0;
    uint256 internal constant dividendFlag = 1;
    uint256 internal constant tradePercent = 12;
}

contract GasContract is Ownable {
    enum PaymentType {
        Unknown,
        BasicPayment,
        Refund,
        Dividend,
        GroupPayment
    }

    struct Payment {
        PaymentType paymentType;
        bool adminUpdated;
        // change to bytes8
        string recipientName;
        address recipient;
        uint16 paymentID;
        address admin; // administrators address
        uint256 amount;
    }

    struct History {
        uint128 lastUpdate;
        uint128 blockNumber;
        address updatedBy;
    }

    struct ImportantStruct {
        uint128 valueA; // max 3 digits
        uint128 valueB; // max 3 digits
        uint256 bigValue;
    }

    uint16 private paymentCounter;
    uint256 public totalSupply;
    address private contractOwner;
    uint8 private _wasLastOdd;

    mapping(address => uint256) private _balances;
    mapping(address => Payment[]) private _payments;
    mapping(address => uint256) public whitelist;
    address[5] public administrators;

    PaymentType private constant defaultPayment = PaymentType.Unknown;
    History[] private _paymentHistory; // when a payment was updated

    mapping(address => uint256) public isOddWhitelistUser;
    mapping(address => ImportantStruct) public whiteListStruct;

    modifier onlyAdminOrOwner() {
        require(
            contractOwner == msg.sender || checkForAdmin(msg.sender),
            "unauthorized"
        );
        _;
    }

    modifier checkIfWhiteListed() {
        uint256 usersTier = whitelist[msg.sender];
        require(usersTier > 0 && usersTier < 4, "invalid whitelist");
        _;
    }

    event AddedToWhitelist(address userAddress, uint256 tier);
    event SupplyChanged(address indexed, uint256 indexed);
    event Transfer(address recipient, uint256 amount);
    event PaymentUpdated(
        address admin,
        uint256 ID,
        uint256 amount,
        string recipient
    );
    event WhiteListTransfer(address indexed);

    constructor(address[] memory _admins, uint256 _totalSupply) {
        contractOwner = msg.sender;
        totalSupply = _totalSupply;

        for (uint256 i = 0; i < _admins.length; i++) {
            address admin = _admins[i];
            if (admin != address(0)) {
                administrators[i] = admin;
                uint256 balanceToAdd = admin == msg.sender ? _totalSupply : 0;
                if (balanceToAdd > 0) {
                    _balances[admin] = balanceToAdd;
                }
                emit SupplyChanged(admin, balanceToAdd);
            }
        }
    }

    function getPaymentHistory()
        public
        payable
        returns (History[] memory paymentHistory)
    {
        paymentHistory = _paymentHistory;
    }

    function checkForAdmin(address _user) public view returns (bool admin_) {
        for (uint256 i = 0; i < administrators.length; i++) {
            if (administrators[i] == _user) {
                admin_ = true;
                break;
            }
        }
    }

    function balanceOf(address _user) public view returns (uint256 balance_) {
        balance_ = _balances[_user];
    }

    function getTradingMode() public pure returns (bool mode_) {
        mode_ = (Constants.tradeFlag == 1 || Constants.dividendFlag == 1)
            ? true
            : false;
    }

    function addHistory(address _updateAddress) public {
        History memory history;
        history.blockNumber = uint128(block.number);
        history.lastUpdate = uint128(block.timestamp);
        history.updatedBy = _updateAddress;
        _paymentHistory.push(history);
    }

    function getPayments(address _user)
        public
        view
        returns (Payment[] memory payments_)
    {
        require(_user != address(0), "invalid user");
        payments_ = _payments[_user];
    }

    function transfer(
        address _recipient,
        uint256 _amount,
        string calldata _name
    ) public {
        require(_balances[msg.sender] >= _amount, "not enough balance");
        require(
            bytes(_name).length > 0 && bytes(_name).length <= 8,
            "invalid name"
        );
        _balances[msg.sender] -= _amount;
        _balances[_recipient] += _amount;
        Payment memory payment = Payment({
            admin: address(0),
            adminUpdated: false,
            paymentType: PaymentType.BasicPayment,
            recipient: _recipient,
            amount: _amount,
            recipientName: _name,
            paymentID: ++paymentCounter
        });

        _payments[msg.sender].push(payment);

        emit Transfer(_recipient, _amount);
    }

    function updatePayment(
        address _user,
        uint256 _ID,
        uint256 _amount,
        PaymentType _type
    ) public onlyAdminOrOwner {
        require(_ID > 0);
        require(_amount > 0);
        require(_user != address(0));

        for (uint256 ii = 0; ii < _payments[_user].length; ii++) {
            if (_payments[_user][ii].paymentID == _ID) {
                _payments[_user][ii].adminUpdated = true;
                _payments[_user][ii].admin = _user;
                _payments[_user][ii].paymentType = _type;
                _payments[_user][ii].amount = _amount;
                addHistory(_user);
                emit PaymentUpdated(
                    msg.sender,
                    _ID,
                    _amount,
                    _payments[_user][ii].recipientName
                );
            }
        }
    }

    function addToWhitelist(address _userAddrs, uint256 _tier)
        public
        onlyAdminOrOwner
    {
        require(_tier < 255 && _tier > 0, "invalid _tier range");
        whitelist[_userAddrs] = _tier;
        uint256 value = _tier > 3 ? 3 : _tier;
        whitelist[_userAddrs] -= _tier;
        whitelist[_userAddrs] = value;

        uint256 wasLastAddedOdd = _wasLastOdd;
        assert(wasLastAddedOdd == 1 || wasLastAddedOdd == 0);
        _wasLastOdd = wasLastAddedOdd == 1 ? 0 : 1;
        isOddWhitelistUser[_userAddrs] = wasLastAddedOdd;

        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(
        address _recipient,
        uint256 _amount,
        ImportantStruct memory _struct
    ) public checkIfWhiteListed {
        require(_balances[msg.sender] >= _amount, "invalid balance");
        require(_amount > 3, "invalid _amount");
        _balances[msg.sender] -= _amount;
        _balances[_recipient] += _amount;
        _balances[msg.sender] += whitelist[msg.sender];
        _balances[_recipient] -= whitelist[msg.sender];

        ImportantStruct storage newImportantStruct = whiteListStruct[
            msg.sender
        ];
        newImportantStruct.valueA = _struct.valueA;
        newImportantStruct.bigValue = _struct.bigValue;
        newImportantStruct.valueB = _struct.valueB;
        emit WhiteListTransfer(_recipient);
    }
}
