pragma solidity 0.5;

import "./Pausable.sol";

contract Remittance is Pausable {
    struct Payment {
        uint balance;
        address exchanger;
        bool used;
    }
    mapping(bytes32 => Payment) paymentList;

    event LogDeposit(address sender, uint amount, address exchanger, bytes32 passwordHash);
    event LogWithdrawal(address recipient, address exchanger, uint amount);

    constructor() public {
    }

    function createHash(bytes32 password, address recipient) public pure returns (bytes32 _passHash) {
        return keccak256(abi.encodePacked(password, recipient));
    }

    function deposit(address _exchanger, bytes32 hashOfPasswordAndRecipient) 
        public
        payable {

        require(msg.value > 0, "Must include value to transfer");
        require(_exchanger != address(0), "Exchanger address is missing");
        require(!paymentList[hashOfPasswordAndRecipient].used, "This hash has already been used");
        
        paymentList[hashOfPasswordAndRecipient].exchanger = _exchanger;
        paymentList[hashOfPasswordAndRecipient].balance = msg.value;
        paymentList[hashOfPasswordAndRecipient].used = true; // this hash can't be used again
        emit LogDeposit(msg.sender, msg.value, _exchanger, hashOfPasswordAndRecipient);
    }

    function withdraw(bytes32 password, address recipient) public {
        bytes32 passHash = createHash(password, recipient);
        require (paymentList[passHash].balance > 0, "No balance found for this recipient and password");
        require (paymentList[passHash].exchanger == msg.sender, "Transaction sender is not the specified exchanger");
        
        uint amount = paymentList[passHash].balance;
        paymentList[passHash].balance = 0;
        emit LogWithdrawal(recipient, msg.sender, amount);
        msg.sender.transfer(amount);
    }
}