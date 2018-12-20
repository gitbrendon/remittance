pragma solidity 0.5;

import "./Pausable.sol";

contract Remittance is Pausable {
    uint private bobBalance;
    address private exchanger;
    bytes32 private passHash;

    event LogDeposit(address sender, uint amount, address recipient, address exchanger, bytes32 passwordHash);
    event LogWithdrawal(address recipient, address exchanger, uint amount);

    constructor() public {
    }

    function createHash(bytes32 pass1, bytes32 pass2) private pure returns (bytes32 _passHash) {
        return keccak256(abi.encodePacked(pass1, pass2));
    }

    function doHashesMatch(bytes32 recipientPass, bytes32 exchangerPass, bytes32 _passHash) private pure returns (bool matches) {
        return (_passHash == createHash(recipientPass, exchangerPass));
    }

    function deposit(address _recipient, address _exchanger, bytes32 hashOfTwoPasswords) 
        public 
        onlyOwner // remove for utility
        payable {

        require(msg.value > 0, "Must include value to transfer");
        require(_recipient != address(0), "Recipient address is missing");
        require(_exchanger != address(0), "Exchanger address is missing");
        
        exchanger = _exchanger;
        bobBalance = msg.value;
        passHash = hashOfTwoPasswords;
        emit LogDeposit(msg.sender, msg.value, _recipient, _exchanger, passHash);
    }

    function withdraw(address recipient, bytes32 password1, bytes32 password2) public {
        require (msg.sender == exchanger, "Transaction sender is not the specified exchanger");
        require (doHashesMatch(password1, password2, passHash), "Passwords do not match");
        
        uint amount = bobBalance;
        bobBalance = 0;
        emit LogWithdrawal(recipient, msg.sender, amount);
        msg.sender.transfer(amount);
    }
}