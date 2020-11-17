/*
Copyright (c) 2020, BitVerk
*/

pragma solidity ^0.4.26;

import "./delegate.sol";

contract Recorder {
    function addLog(string _log, bool _newLine) external;
}

contract RandomGenerator {
    function randomNumber(uint256 _min, uint256 _max, uint256 _extra1, uint256 _extra2) external view returns (uint256);
}

contract Object is Delegated {
    bytes32 private name_ = "null";
    address public logRecorder_ = address(0);
    address public randomGenerator_ = address(0);

    // Constructor
    constructor(bytes32 _name) public { 
        name_ = _name;
    }

    function setRandomGenerator(address _adr) external {
        checkDelegate(msg.sender, 1);
        require(_adr != address(0));
        require(randomGenerator_ != _adr);

        randomGenerator_ = _adr;        
    }    

    function objName() external view returns (bytes32) { 
        return name_;
    }

    function setLogRecorder(address _rocorderAdr) external {
        checkDelegate(msg.sender, 1);
        logRecorder_ = _rocorderAdr;
    }

    function addLog(string _log, bool _newLine) internal {
        if (logRecorder_ != address(0)) {
            Recorder(logRecorder_).addLog(_log, _newLine);
        }
    }

    function randomView(uint256 _min, uint256 _max, uint256 _extra1, uint256 _extra2) internal view returns (uint256) {
        require(_min < _max);
        if (randomGenerator_ == address(0)) {
            // uint ret = uint(keccak256(abi.encodePacked(now, msg.sender, blockhash(block.number - 1), _extra1, _extra2 )))%(_max - _min);
            uint ret = uint(keccak256(abi.encodePacked(now, msg.sender, blockhash(block.number - 1), _extra1, _extra2 ))) % (_max - _min);
            return ret.add(_min);
        } else {
            return RandomGenerator(randomGenerator_).randomNumber(_min, _max, _extra1, _extra2);
        }
    }
}
