pragma solidity 0.5;

import "./Pausable.sol";
import "./SafeMath.sol";

contract Remittance is Pausable {
    using SafeMath for uint256;

    struct Payment {
        uint balance;
        address payer;
        uint deadline;
        uint txFee;
    }
    mapping(bytes32 => Payment) paymentList;
    uint public maxDeadlineSeconds; // if this value is 0, deadline cannot be set by payer
    uint public transactionFee;
    mapping(address => uint) public contractBalance;

    event LogMaxDeadlineChanged(address indexed changer, uint newMaxDeadlineSeconds);
    event LogTransactionFeeChanged(address indexed changer, uint newTransactionFee);
    event LogWithdrawContractFunds(address indexed admin, uint amount);
    event LogDeposit(address indexed sender, uint amount, bytes32 passwordHash);
    event LogWithdrawal(address indexed exchanger, bytes32 password, uint amount, uint transactionFee);
    event LogClaimed(address indexed claimer, bytes32 passwordHash, uint amount);

    constructor() public {
        transactionFee = 3 finney; // 1,690,000 (gas) * 2 (gas price) = 3,380,000 gwe = 3.38 finney to deploy contract
    }

    function setMaxDeadline(uint _maxDeadlineSeconds) public onlyOwner {
        maxDeadlineSeconds = _maxDeadlineSeconds;
        emit LogMaxDeadlineChanged(msg.sender, _maxDeadlineSeconds);
    }

    function setTransactionFee(uint _transactionFee) public onlyOwner {
        transactionFee = _transactionFee;
        emit LogTransactionFeeChanged(msg.sender, _transactionFee);
    }

    function getDeadlineTimestamp(uint _seconds) private view returns(uint timestamp) {
        require(maxDeadlineSeconds >= _seconds, "Deadline is too far in the future");
        
        return (maxDeadlineSeconds > 0) ? now + _seconds : 0;
    }

    function createHash(bytes32 password, address exchanger) public view returns (bytes32 _passHash) {
        return keccak256(abi.encodePacked(password, exchanger, this)); // include contract address as salt
    }

    function deposit(bytes32 hashOfPasswordAndExchanger, uint secondsUntilDeadline)
        public
        onlyIfRunning
        payable {

        require(msg.value > 0, "Must include value to transfer");
        require(paymentList[hashOfPasswordAndExchanger].payer == address(0), "This hash has already been used");
        
        paymentList[hashOfPasswordAndExchanger].payer = msg.sender;
        paymentList[hashOfPasswordAndExchanger].balance = msg.value;
        paymentList[hashOfPasswordAndExchanger].deadline = getDeadlineTimestamp(secondsUntilDeadline);
        // No tx fee applied if msg.value < txFee
        paymentList[hashOfPasswordAndExchanger].txFee = (msg.value > transactionFee) ? transactionFee : 0;
        emit LogDeposit(msg.sender, msg.value, hashOfPasswordAndExchanger);
    }

    function withdraw(bytes32 password) public onlyIfRunning {
        bytes32 passHash = createHash(password, msg.sender);
        require (paymentList[passHash].balance > 0, "No balance found for this exchanger and password");
        
        uint amount = paymentList[passHash].balance;
        // take tx fee on withdrawal
        amount -= paymentList[passHash].txFee;
        contractBalance[super.getOwner()] = contractBalance[super.getOwner()].add(paymentList[passHash].txFee);

        paymentList[passHash].balance = 0;
        emit LogWithdrawal(msg.sender, password, amount, paymentList[passHash].txFee);
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

    function withdrawContractFunds() public {
        require(contractBalance[msg.sender] > 0, "No funds to withdraw");

        uint amount = contractBalance[msg.sender];
        contractBalance[msg.sender] = 0;
        emit LogWithdrawContractFunds(msg.sender, amount);
        msg.sender.transfer(amount);
    }
}