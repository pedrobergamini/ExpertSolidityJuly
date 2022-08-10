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

    modifier checkIfWhiteListed(address sender) {
        require(msg.sender == sender, "invalid sender");
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

        for (uint256 ii = 0; ii < administrators.length; ii++) {
            if (_admins[ii] != address(0)) {
                administrators[ii] = _admins[ii];
                if (_admins[ii] == contractOwner) {
                    _balances[contractOwner] = totalSupply;
                } else {
                    _balances[_admins[ii]] = 0;
                }
                if (_admins[ii] == contractOwner) {
                    emit SupplyChanged(_admins[ii], totalSupply);
                } else if (_admins[ii] != contractOwner) {
                    emit SupplyChanged(_admins[ii], 0);
                }
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
        bool admin = false;
        for (uint256 ii = 0; ii < administrators.length; ii++) {
            if (administrators[ii] == _user) {
                admin = true;
            }
        }
        return admin;
    }

    function balanceOf(address _user) public view returns (uint256 balance_) {
        uint256 balance = _balances[_user];
        return balance;
    }

    function getTradingMode() public pure returns (bool mode_) {
        bool mode = false;
        if (Constants.tradeFlag == 1 || Constants.dividendFlag == 1) {
            mode = true;
        } else {
            mode = false;
        }
        return mode;
    }

    function addHistory(address _updateAddress, bool _tradeMode)
        public
        returns (bool status_, bool tradeMode_)
    {
        History memory history;
        history.blockNumber = uint128(block.number);
        history.lastUpdate = uint128(block.timestamp);
        history.updatedBy = _updateAddress;
        _paymentHistory.push(history);
        bool[] memory status = new bool[](Constants.tradePercent);
        for (uint256 i = 0; i < Constants.tradePercent; i++) {
            status[i] = true;
        }
        return ((status[0] == true), _tradeMode);
    }

    function getPayments(address _user)
        public
        view
        returns (Payment[] memory _payments_)
    {
        require(
            _user != address(0),
            "Gas Contract - getPayments function - User must have a valid non zero address"
        );
        return _payments[_user];
    }

    function transfer(
        address _recipient,
        uint256 _amount,
        string calldata _name
    ) public returns (bool status_) {
        address senderOfTx = msg.sender;
        require(
            _balances[senderOfTx] >= _amount,
            "Gas Contract - Transfer function - Sender has insufficient Balance"
        );
        require(
            bytes(_name).length > 0 && bytes(_name).length <= 8,
            "Gas Contract - Transfer function -  The recipient name is too long, there is a max length of 8 characters"
        );
        _balances[senderOfTx] -= _amount;
        _balances[_recipient] += _amount;
        emit Transfer(_recipient, _amount);
        Payment memory payment;
        payment.admin = address(0);
        payment.adminUpdated = false;
        payment.paymentType = PaymentType.BasicPayment;
        payment.recipient = _recipient;
        payment.amount = _amount;
        payment.recipientName = _name;
        payment.paymentID = ++paymentCounter;
        _payments[senderOfTx].push(payment);
        bool[] memory status = new bool[](Constants.tradePercent);
        for (uint256 i = 0; i < Constants.tradePercent; i++) {
            status[i] = true;
        }
        return (status[0] == true);
    }

    function updatePayment(
        address _user,
        uint256 _ID,
        uint256 _amount,
        PaymentType _type
    ) public onlyAdminOrOwner {
        require(
            _ID > 0,
            "Gas Contract - Update Payment function - ID must be greater than 0"
        );
        require(
            _amount > 0,
            "Gas Contract - Update Payment function - Amount must be greater than 0"
        );
        require(
            _user != address(0),
            "Gas Contract - Update Payment function - Administrator must have a valid non zero address"
        );

        address senderOfTx = msg.sender;

        for (uint256 ii = 0; ii < _payments[_user].length; ii++) {
            if (_payments[_user][ii].paymentID == _ID) {
                _payments[_user][ii].adminUpdated = true;
                _payments[_user][ii].admin = _user;
                _payments[_user][ii].paymentType = _type;
                _payments[_user][ii].amount = _amount;
                bool tradingMode = getTradingMode();
                addHistory(_user, tradingMode);
                emit PaymentUpdated(
                    senderOfTx,
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
        require(
            _tier < 255,
            "Gas Contract - addToWhitelist function -  tier level should not be greater than 255"
        );
        whitelist[_userAddrs] = _tier;
        if (_tier > 3) {
            whitelist[_userAddrs] -= _tier;
            whitelist[_userAddrs] = 3;
        } else if (_tier == 1) {
            whitelist[_userAddrs] -= _tier;
            whitelist[_userAddrs] = 1;
        } else if (_tier > 0 && _tier < 3) {
            whitelist[_userAddrs] -= _tier;
            whitelist[_userAddrs] = 2;
        }
        uint256 wasLastAddedOdd = _wasLastOdd;
        if (wasLastAddedOdd == 1) {
            _wasLastOdd = 0;
            isOddWhitelistUser[_userAddrs] = wasLastAddedOdd;
        } else if (wasLastAddedOdd == 0) {
            _wasLastOdd = 1;
            isOddWhitelistUser[_userAddrs] = wasLastAddedOdd;
        } else {
            revert("Contract hacked, imposible, call help");
        }
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(
        address _recipient,
        uint256 _amount,
        ImportantStruct memory _struct
    ) public checkIfWhiteListed(msg.sender) {
        address senderOfTx = msg.sender;
        require(
            _balances[senderOfTx] >= _amount,
            "Gas Contract - whiteTransfers function - Sender has insufficient Balance"
        );
        require(
            _amount > 3,
            "Gas Contract - whiteTransfers function - amount to send have to be bigger than 3"
        );
        _balances[senderOfTx] -= _amount;
        _balances[_recipient] += _amount;
        _balances[senderOfTx] += whitelist[senderOfTx];
        _balances[_recipient] -= whitelist[senderOfTx];

        whiteListStruct[senderOfTx] = ImportantStruct(0, 0, 0);
        ImportantStruct storage newImportantStruct = whiteListStruct[
            senderOfTx
        ];
        newImportantStruct.valueA = _struct.valueA;
        newImportantStruct.bigValue = _struct.bigValue;
        newImportantStruct.valueB = _struct.valueB;
        emit WhiteListTransfer(_recipient);
    }
}
