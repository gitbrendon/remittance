pragma solidity 0.5;

import "./Pausable.sol";

contract Remittance is Pausable {
    struct Payment {
        uint balance;
        address payer; 
        address exchanger;
        uint deadline;
        bool used;
    }
    mapping(bytes32 => Payment) paymentList;
    uint public maxDeadlineDays; // if this value is 0, deadline cannot be set by payer
    uint public transactionFee;
    uint public contractBalance;

    event LogMaxDeadlineChanged(address indexed changer, uint newMaxDeadlineDays);
    event LogTransactionFeeChanged(address indexed changer, uint newTransactionFee);
    event LogWithdrawContractFunds(address indexed admin, uint amount);
    event LogDeposit(address indexed sender, uint amount, address exchanger, bytes32 passwordHash);
    event LogWithdrawal(address indexed recipient, address indexed exchanger, bytes32 password, uint amount, uint transactionFee);
    event LogClaimed(address indexed claimer, bytes32 passwordHash, uint amount);

    constructor() public {
        transactionFee = 3 finney; // 1,690,000 (gas) * 2 (gas price) = 3,380,000 gwe = 3.38 finney to deploy contract
    }

    function setMaxDeadline(uint _maxDeadlineDays) public onlyOwner {
        maxDeadlineDays = _maxDeadlineDays;
        emit LogMaxDeadlineChanged(msg.sender, _maxDeadlineDays);
    }

    function setTransactionFee(uint _transactionFee) public onlyOwner {
        transactionFee = _transactionFee;
        emit LogTransactionFeeChanged(msg.sender, _transactionFee);
    }

    function getDeadlineTimestamp(uint _days) private view returns(uint timestamp) {
        require(maxDeadlineDays >= _days, "Deadline is too far in the future");
        
        return (maxDeadlineDays > 0) ? now + (_days * 1 days) : 0;
    }

    function createHash(bytes32 password, address recipient) public pure returns (bytes32 _passHash) {
        return keccak256(abi.encodePacked(password, recipient));
    }

    function deposit(address _exchanger, bytes32 hashOfPasswordAndRecipient, uint daysUntilDeadline) 
        public
        onlyIfRunning
        payable {

        require(msg.value > 0, "Must include value to transfer");
        require(_exchanger != address(0), "Exchanger address is missing");
        require(!paymentList[hashOfPasswordAndRecipient].used, "This hash has already been used");
        
        paymentList[hashOfPasswordAndRecipient].payer = msg.sender;
        paymentList[hashOfPasswordAndRecipient].exchanger = _exchanger;
        paymentList[hashOfPasswordAndRecipient].balance = msg.value;
        paymentList[hashOfPasswordAndRecipient].deadline = getDeadlineTimestamp(daysUntilDeadline);
        paymentList[hashOfPasswordAndRecipient].used = true; // this hash can't be used again
        emit LogDeposit(msg.sender, msg.value, _exchanger, hashOfPasswordAndRecipient);
    }

    function withdraw(bytes32 password, address recipient) public onlyIfRunning {
        bytes32 passHash = createHash(password, recipient);
        require (paymentList[passHash].balance > 0, "No balance found for this recipient and password");
        require (paymentList[passHash].exchanger == msg.sender, "Transaction sender is not the specified exchanger");
        
        uint amount = paymentList[passHash].balance;
        // take tx fee on withdrawal, unless amount is smaller than tx fee
        uint withdrawTxFee = (amount > transactionFee) ? transactionFee : 0;
        amount -= withdrawTxFee;
        contractBalance += withdrawTxFee;
        assert(contractBalance >= withdrawTxFee); // make sure contractBalance doesn't overflow

        paymentList[passHash].balance = 0;
        emit LogWithdrawal(recipient, msg.sender, password, amount, withdrawTxFee);
        msg.sender.transfer(amount);
    }

    function claim(bytes32 _hash) public onlyIfRunning {
        require(paymentList[_hash].balance > 0, "No balance found for this recipient and password");
        require(paymentList[_hash].payer == msg.sender, "Only payment sender can claim funds");
        require(paymentList[_hash].deadline > 0, "This payment does not have a deadline for recipient to withdraw funds");
        require(paymentList[_hash].deadline < now, "Deadline for recipient to withdraw funds has not yet passed");

        uint amount = paymentList[_hash].balance;
        paymentList[_hash].balance = 0;
        emit LogClaimed(msg.sender, _hash, amount);
        msg.sender.transfer(amount);
    }

    function withdrawContractFunds() public onlyOwner {
        uint amount = contractBalance;
        contractBalance = 0;
        msg.sender.transfer(amount);
        emit LogWithdrawContractFunds(msg.sender, amount);
    }
}