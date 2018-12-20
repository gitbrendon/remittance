pragma solidity 0.5;

contract Owned {
    address private owner;

    event LogOwnerChanged(address indexed previousOwner, address newOwner);

    constructor() public {
        owner = msg.sender;
    }

    function getOwner() public view returns(address) {
        return owner;
    }

    function changeOwner(address newOwner) public {
        require(msg.sender == owner, "Must be contract owner");
        emit LogOwnerChanged(owner, newOwner);
        owner = newOwner;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Must be contract owner");
        _;
    }
}

contract Pausable is Owned {
    bool private isRunning;

    event LogContractPaused(address sender);
    event LogContractResumed(address sender);

    constructor() public {
        isRunning = true;
    }

    modifier onlyIfRunning() {
        require(isRunning, "Contract must be running");
        _;
    }

    function pauseContract() public onlyOwner {
        isRunning = false;
        emit LogContractPaused(msg.sender);
    }

    function resumeContract() public onlyOwner {
        isRunning = true;
        emit LogContractResumed(msg.sender);
    }
}

contract Remittance is Pausable {
    uint private bobBalance;
    bytes32 private passHash;

    event LogDeposit(address sender, uint amount, address recipient, bytes32 passHash1);
    event LogWithdrawal(address recipient, address exchanger, uint amount);

    constructor() public {
    }

    function createHash(bytes32 pass1, bytes32 pass2) private pure returns (bytes32 _passHash) {
        return keccak256(abi.encodePacked(pass1, pass2));
    }

    // Hash matching function allows password parameters to be passed in either order
    function doHashesMatch(bytes32 pass1, bytes32 pass2, bytes32 _passHash) private pure returns (bool matches) {
        return (_passHash == createHash(pass1, pass2) ||
            _passHash == createHash(pass2, pass1));
    }

    function deposit(address recipient, bytes32 password1, bytes32 password2) 
        public 
        onlyOwner // remove for utility
        payable {

        require(msg.value > 0, "Must include value to transfer");
        
        bobBalance = msg.value;
        passHash = createHash(password1, password2);
        emit LogDeposit(msg.sender, msg.value, recipient, passHash);
    }

    function withdraw(address recipient, bytes32 password1, bytes32 password2) public {
        require (doHashesMatch(password1, password2, passHash), "Passwords do not match");
        
        uint amount = bobBalance;
        bobBalance = 0;
        msg.sender.transfer(amount);
        emit LogWithdrawal(recipient, msg.sender, amount);
    }
}