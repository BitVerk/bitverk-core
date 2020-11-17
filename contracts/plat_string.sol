/*
Copyright (c) 2020, BitVerk
*/

pragma solidity ^0.4.26;

library PlatString {
    function append(string memory _a, string memory _b, string memory _c, string memory _d, string memory _e) internal pure returns (string memory){
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        bytes memory _bc = bytes(_c);
        bytes memory _bd = bytes(_d);
        bytes memory _be = bytes(_e);
        string memory abcde = new string(_ba.length + _bb.length + _bc.length + _bd.length + _be.length);
        bytes memory babcde = bytes(abcde);
        uint i;
        uint k = 0;
        for (i = 0; i < _ba.length; i++) babcde[k++] = _ba[i];
        for (i = 0; i < _bb.length; i++) babcde[k++] = _bb[i];
        for (i = 0; i < _bc.length; i++) babcde[k++] = _bc[i];
        for (i = 0; i < _bd.length; i++) babcde[k++] = _bd[i];
        for (i = 0; i < _be.length; i++) babcde[k++] = _be[i];
        return string(babcde);
    }

    function append(string memory _a, string memory _b, string memory _c, string memory _d) internal pure returns (string memory) {
        return append(_a, _b, _c, _d, "");
    }

    function append(string memory _a, string memory _b, string memory _c) internal pure returns (string memory) {
        return append(_a, _b, _c, "", "");
    }

    function append(string memory _a, string memory _b) internal pure returns (string memory) {
        return append(_a, _b, "", "", "");
    }

    function append(bytes32 _a, bytes32 _b, bytes32 _c) internal pure returns (string memory) {
        return append(bytes32ToString(_a), bytes32ToString(_b), bytes32ToString(_c), "", "");
    }

    function append(bytes32 _a, bytes32 _b) internal pure returns (string memory) {
        return append(bytes32ToString(_a), bytes32ToString(_b), "", "", "");
    }

    function tobytes32(string memory _str, uint _offset) internal pure returns (bytes32) {
        bytes32 out;
        bytes memory str = bytes(_str);
        uint len = str.length;

        if (len  > 32 ) len = 32;

        for (uint i = 0; i < len; ++i) {
            out |= bytes32(str[_offset + i] & 0xFF) >> (i * 8);
        }

        return out;
    }

    function tobytes32(string memory _str) internal pure returns (bytes32) {
        bytes32 out;
        bytes memory str = bytes(_str);
        uint len = str.length;

        if (len  > 32 ) len = 32;

        for (uint i = 0; i < len; ++i) {
            out |= bytes32(str[i] & 0xFF) >> (i * 8);
        }

        return out;
    }

    function bytes32ToString(bytes32 x) internal pure returns (string memory) {
        bytes memory bytesString = new bytes(32);
        uint charCount = 0;
        uint j;
        for (j = 0; j < 32; j++) {
            byte char = byte(bytes32(uint(x) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (j = 0; j < charCount; j++) {
            bytesStringTrimmed[j] = bytesString[j];
        }
        return string(bytesStringTrimmed);
    }

    function addressToString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            byte b = byte(uint8(uint(x) / (2**(8*(19 - i)))));
            byte hi = byte(uint8(b) / 16);
            byte lo = byte(uint8(b) - 16 * uint8(hi));

            if (uint8(hi) < 10) s[2*i] = byte(uint8(hi) + 0x30);
            else s[2*i] = byte(uint8(hi) + 0x57);

            if (uint8(lo)  < 10) s[2*i+1] = byte(uint8(lo) + 0x30);
            else s[2*i+1] = byte(uint8(lo) + 0x57);     
        }
        return string(s);
    }

    function isEmpty(string memory str) internal pure returns (bool) {
        bytes memory temp = bytes(str); // Uses memory
        if (temp.length == 0) {
            return true;
        } else {
            return false;
        }
    }

    function stringToUint(string memory s) internal pure returns (uint) {
        bytes memory b = bytes(s);
        uint i;
        uint result = 0;
        for (i = 0; i < b.length; i++) {
            uint8 c = uint8(b[i]);
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
        return result;
    }

    // Original file at 
    // https://github.com/oraclize/ethereum-api/blob/master/oraclizeAPI_0.5.sol
    // function uint2str(uint i) internal pure returns (string);
    function uintToString(uint i) internal pure returns (string memory) {
        if (i == 0) return "0";
        
        uint j = i;
        uint len;
        while (j != 0){
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len - 1;
        while (i != 0){
            bstr[k--] = byte(uint8(48 + i % 10));
            i /= 10;
        }
        return string(bstr);
    }
}
