/*
Copyright (c) 2020, BitVerk
*/

pragma solidity ^0.4.26;

import "./plat_string.sol";
import "./plat_math.sol";

// ----------------------------------------------------------------------------
// ERC Token Standard #20 Interface
// https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
// ----------------------------------------------------------------------------
contract ERC20Interface {
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function decimals() external view returns (uint256);
    function balanceOf(address _owner) external view returns (uint balance);
    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    function transfer(address to, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);
    function totalSupply() external view returns (uint);
    function mint(address _to, uint _amount) external;
    function burn(address _to, uint _amount) external;
}

contract Owned {
    address public owner_;
    address public newOwner_;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    constructor() public {
        owner_ = msg.sender;
    }

    function checkOwner(address _account) internal view { 
        require(_account == owner_); 
    }

    function transferOwnership(address _newOwner) external {
        checkOwner(msg.sender);
        newOwner_ = _newOwner;
    }

    function acceptOwnership() external {
        require(msg.sender == newOwner_);
        emit OwnershipTransferred(owner_, newOwner_);
        owner_ = newOwner_;
        newOwner_ = address(0);
    }
}

contract Delegated is Owned {
    using SafeMath for uint;

    mapping (address => uint) internal priorities_;
    event EmergencyTransferERC20Token(address indexed tokenAddress, uint tokens);

    constructor() public {
        priorities_[msg.sender] = 1;
        priorities_[address(this)] = 1;
    }

    // This unnamed function is called whenever someone tries to send ether to it
    function() external payable { 
        revert();
    }

    function kill() public {
        checkDelegate(msg.sender, 1);
        selfdestruct(owner_); 
    }

    function checkDelegate(address _adr, uint _priority) internal view {
        require(priorities_[_adr] > 0 && priorities_[_adr] <= _priority);
    }

    function setDelegate(address _adr, uint _priority) public {
        checkDelegate(msg.sender, 1);
        if (_adr != address(this)) {
            priorities_[_adr] = _priority;
        }        
    }
    
    function isDelegate(address _adr, uint _priority) public view returns (bool)  {
        return (priorities_[_adr] > 0 && priorities_[_adr] <= _priority);
    }

    // ------------------------------------------------------------------------
    // Owner can transfer out any accidentally sent ERC20 tokens
    // ------------------------------------------------------------------------
    function transferAnyERC20Token(address tokenAddress, uint tokens) public returns (bool success) {
        checkOwner(msg.sender);
        if (tokenAddress == address(0)) {
            bool ret = msg.sender.call.value(tokens)("");
            require(ret);
        } else {
            return ERC20Interface(tokenAddress).transfer(msg.sender, tokens);
        }
        emit EmergencyTransferERC20Token(tokenAddress, tokens);
    }  
}
