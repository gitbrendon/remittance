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

    event LogMaxDeadlineChanged(address indexed changer, uint newMaxDeadlineDays);
    event LogDeposit(address indexed sender, uint amount, address exchanger, bytes32 passwordHash);
    event LogWithdrawal(address indexed recipient, address indexed exchanger, bytes32 password, uint amount);
    event LogClaimed(address indexed claimer, bytes32 passwordHash, uint amount);

    constructor() public {
    }

    function setMaxDeadline(uint _maxDeadlineDays) public onlyOwner {
        maxDeadlineDays = _maxDeadlineDays;
        emit LogMaxDeadlineChanged(msg.sender, _maxDeadlineDays);
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

    function withdraw(bytes32 password, address recipient) public {
        bytes32 passHash = createHash(password, recipient);
        require (paymentList[passHash].balance > 0, "No balance found for this recipient and password");
        require (paymentList[passHash].exchanger == msg.sender, "Transaction sender is not the specified exchanger");
        
        uint amount = paymentList[passHash].balance;
        paymentList[passHash].balance = 0;
        emit LogWithdrawal(recipient, msg.sender, password, amount);
        msg.sender.transfer(amount);
    }

    function claim(bytes32 _hash) public {
        require(paymentList[_hash].balance > 0, "No balance found for this recipient and password");
        require(paymentList[_hash].payer == msg.sender, "Only payment sender can claim funds");
        require(paymentList[_hash].deadline > 0, "This payment does not have a deadline for recipient to withdraw funds");
        require(paymentList[_hash].deadline < now, "Deadline for recipient to withdraw funds has not yet passed");

        uint amount = paymentList[_hash].balance;
        paymentList[_hash].balance = 0;
        emit LogClaimed(msg.sender, _hash, amount);
        msg.sender.transfer(amount);
    }
}