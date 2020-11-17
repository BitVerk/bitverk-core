/*
Copyright (c) 2020, BitVerk
*/

pragma solidity ^0.4.26;

import "./object.sol";

contract SysBase is Object {
    mapping(bytes32 => address) internal moduleAdrs_;
    bool internal halted_ = false;

    address[] internal blockedUsers_;
    mapping(address => bool) internal userBlockStatus_;
    mapping(address => uint256) internal userIndice_;

    uint32 debugStep_ = 0;

    constructor(bytes32 _name) public Object(_name) {
    }

    function setSysGms() internal;

    function setDebugStep (uint32 _step) external {
        checkDelegate(msg.sender, 1);
        debugStep_ = _step;
    }

    function getDebugStep () internal view returns (uint32) {
        return debugStep_;
    }
    
    ///////////////////////
    function setHalted(bool _tag) external {
        checkDelegate(msg.sender, 1);
        halted_ = _tag;
        if (halted_) {
            addLog("Halted true", true);
        } else {
            addLog("Halted false", true);
        }        
    }

    function setUserBlockStatus(address _user, bool _blockTag) external {
        checkDelegate(msg.sender, 1);
        if (_blockTag == true && userBlockStatus_[_user] == false) {
            userBlockStatus_[_user] = true;
            userIndice_[_user] = blockedUsers_.length;
            blockedUsers_.push(_user);
        } else if (_blockTag == false && userBlockStatus_[_user] == true) {
            userBlockStatus_[_user] = false;
            uint256 idx = userIndice_[_user];
            uint256 lastIdx = blockedUsers_.length - 1;
            address lastUser = blockedUsers_[lastIdx];
            userIndice_[lastUser] = idx;
            blockedUsers_[idx] = lastUser;
            blockedUsers_.length --;
        } else {
            revert();
        }
    }

    function numBlockedUsers() external view returns (uint256) {
        return blockedUsers_.length;
    }
    
    function getBlockedUserByIndex(uint256 _idx) external view returns (address) {
        require(_idx < blockedUsers_.length);
        return blockedUsers_[_idx];
    }
    
    function getUserBlockedStatus(address _user) external view returns (bool) {
        return userBlockStatus_[_user];
    }

    ////////////////////////
    function isUserBlocked(address _user) internal view returns (bool) {
        return userBlockStatus_[_user];
    }
    
    function isHalted() internal view returns (bool) {
        return halted_;
    }    

    function getModule(bytes32 _name) internal view returns (address) {
        address adr = moduleAdrs_[_name];
        return adr;
    }

    ///////////////////////
    function configureSingleMudule(bytes32 _tag, address _adr) external {
        checkDelegate(msg.sender, 1);

        moduleAdrs_[_tag] =  _adr;
        if (_adr  != address(0)) {
            setDelegate(_adr,  1);
        } 
        addLog("configureSingleMudule", true);
        setSysGms();
    }  

    function configureMudules(bytes32[] _tags, address[] _adrs) external {
        checkDelegate(msg.sender, 1);
        require(_tags.length == _adrs.length);

        for (uint i = 0; i < _adrs.length; ++i) {
            moduleAdrs_[_tags[i]] =  _adrs[i];
            if (_adrs[i]  != address(0)) {
                setDelegate(_adrs[i],  1);
            } 
        }
        addLog("configureMudules", true);
        setSysGms();
    }
}
