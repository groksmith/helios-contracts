pragma solidity ^0.8.20;

contract MultiSigWallet {

    error NotOwner();
    error NotValidRequirement();
    error ZeroAddress();
    error NotUniqueOwner();
    error TransactionDoesNotExists();
    error TransactionAlreadyExecuted();
    error TransactionAlreadyConfirmed();
    error TransactionNotConfirmed();
    error TransactionFailed();

    event Deposit(address indexed sender, uint amount, uint balance);
    event SubmitTransaction(
        address indexed owner,
        uint indexed txIndex,
        address indexed to,
        uint value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public numConfirmationsRequired;

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint numConfirmations;
    }

    // mapping from tx index => owner => bool
    mapping(uint => mapping(address => bool)) public isConfirmed;

    Transaction[] public transactions;

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert NotOwner();
        _;
    }

    modifier txExists(uint _txIndex) {
        if (_txIndex >= transactions.length) revert TransactionDoesNotExists();
        _;
    }

    modifier notExecuted(uint _txIndex) {
        if (transactions[_txIndex].executed) revert TransactionAlreadyExecuted();
        _;
    }

    modifier notConfirmed(uint _txIndex) {
        if (isConfirmed[_txIndex][msg.sender]) revert TransactionAlreadyConfirmed();
        _;
    }

    constructor(address[] memory _owners, uint _numConfirmationsRequired) {
        if (_owners.length == 0) revert NotValidRequirement();
        if (_numConfirmationsRequired == 0 && _numConfirmationsRequired >= _owners.length) revert NotValidRequirement();

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            if (owner == address(0)) revert ZeroAddress();
            if (isOwner[owner]) revert NotUniqueOwner();

            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    receive() payable external {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(address _to, uint _value, bytes memory _data) public onlyOwner
    {
        uint txIndex = transactions.length;

        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            numConfirmations: 0
        }));

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint _txIndex)
    public onlyOwner txExists(_txIndex) notExecuted(_txIndex) notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint _txIndex)
    public onlyOwner txExists(_txIndex) notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        if (transaction.numConfirmations < numConfirmationsRequired) revert TransactionNotConfirmed();

        transaction.executed = true;

        (bool success,) = transaction.to.call{value: transaction.value}(transaction.data);
        if (!success) revert TransactionFailed();


        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint _txIndex)
    public onlyOwner txExists(_txIndex) notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        if (!isConfirmed[_txIndex][msg.sender]) revert TransactionNotConfirmed();

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }

    function getTransaction(uint _txIndex) public view
    returns (address to, uint value, bytes memory data, bool executed, uint numConfirmations)
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }
}