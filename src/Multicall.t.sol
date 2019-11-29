pragma solidity >=0.5.0;
pragma experimental ABIEncoderV2;

import "ds-test/test.sol";
import "./Multicall.sol";

contract Store {
    uint256 internal val;
    function set(uint256 _val) public { val = _val; }
    function get() public view returns (uint256) { return val; }
    function getAnd10() public view returns (uint256, uint256) { return (val, 10); }
    function getAdd(uint256 _val) public view returns (uint256) { return val + _val; }
    function getFailing(uint256 _val) public view returns (uint256) {
      require(false);
      return val + _val;
    } 
}


// We inherit from Multicall rather than deploy an instance because solidity
// can't return dynamically sized byte arrays from external contracts
contract MulticallTest is DSTest, Multicall {

    Store public storeA;
    Store public storeB;

    function setUp() public {
        storeA = new Store();
        storeB = new Store();
    }

    function test_store_basic_sanity() public {
        assertEq(storeA.get(), 0);
        storeA.set(100);
        assertEq(storeA.get(), 100);
        storeA.set(0);
        assertEq(storeA.get(), 0);
    }

    function test_single_call_single_return_no_args() public {
        storeA.set(123);

        Call[] memory _calls = new Call[](1);
        _calls[0].target = address(storeA);
        _calls[0].callData = abi.encodeWithSignature("get()");

        (,, Return[] memory _returnData) = aggregate(_calls, true);

        bytes memory _word = _returnData[0].data;
        bool _success = _returnData[0].success;
        uint256 _returnVal;
        assembly { _returnVal := mload(add(0x20, _word)) }

        assertEq(_returnVal, 123);
        assert(_success);
    }

    function test_multi_call_single_return_no_args() public {
        storeA.set(123);
        storeB.set(321);

        Call[] memory _calls = new Call[](2);
        _calls[0].target = address(storeA);
        _calls[0].callData = abi.encodeWithSignature("get()");
        _calls[1].target = address(storeB);
        _calls[1].callData = abi.encodeWithSignature("get()");

        (,, Return[] memory _returnData) = aggregate(_calls, true);

        bool _successA = _returnData[0].success;
        bool _successB = _returnData[1].success;
        bytes memory _wordA = _returnData[0].data;
        bytes memory _wordB = _returnData[1].data;
        uint256 _returnValA;
        uint256 _returnValB;
        assembly { _returnValA := mload(add(0x20, _wordA)) }
        assembly { _returnValB := mload(add(0x20, _wordB)) }

        assertEq(_returnValA, 123);
        assertEq(_returnValB, 321);
        assert(_successA);
        assert(_successB);
    }

    function test_single_call_single_return_single_arg() public {
        storeA.set(123);

        Call[] memory _calls = new Call[](1);
        _calls[0].target = address(storeA);
        _calls[0].callData = abi.encodeWithSignature("getAdd(uint256)", 1);

        (,, Return[] memory _returnData) = aggregate(_calls, true);

        bytes memory _word = _returnData[0].data;
        bool _success = _returnData[0].success;
        uint256 _returnVal;
        assembly { _returnVal := mload(add(0x20, _word)) }

        assertEq(_returnVal, 124);
        assert(_success);
    }

    function test_multi_call_single_return_single_arg() public {
        storeA.set(123);
        storeB.set(321);

        Call[] memory _calls = new Call[](2);
        _calls[0].target = address(storeA);
        _calls[0].callData = abi.encodeWithSignature("getAdd(uint256)", 1);
        _calls[1].target = address(storeB);
        _calls[1].callData = abi.encodeWithSignature("getAdd(uint256)", 1);

        (,, Return[] memory _returnData) = aggregate(_calls, true);

        bool _successA = _returnData[0].success;
        bool _successB = _returnData[1].success;
        bytes memory _wordA = _returnData[0].data;
        bytes memory _wordB = _returnData[1].data;
        uint256 _returnValA;
        uint256 _returnValB;
        assembly { _returnValA := mload(add(0x20, _wordA)) }
        assembly { _returnValB := mload(add(0x20, _wordB)) }

        assertEq(_returnValA, 124);
        assertEq(_returnValB, 322);
        assert(_successA);
        assert(_successB);
    }

    function test_single_call_multi_return_no_args() public {
        storeA.set(123);

        Call[] memory _calls = new Call[](1);
        _calls[0].target = address(storeA);
        _calls[0].callData = abi.encodeWithSignature("getAnd10()");

        (,, Return[] memory _returnData) = aggregate(_calls, true);

        bool _success = _returnData[0].success;
        bytes memory _words = _returnData[0].data;
        uint256 _returnValA1;
        uint256 _returnValA2;
        assembly { _returnValA1 := mload(add(0x20, _words)) }
        assembly { _returnValA2 := mload(add(0x40, _words)) }

        assertEq(_returnValA1, 123);
        assertEq(_returnValA2, 10);
        assert(_success);
    }

    function testFail_single_call_with_failure_in_strict_mode() public {
        storeA.set(123);

        Call[] memory _calls = new Call[](1);
        _calls[0].target = address(storeA);
        _calls[0].callData = abi.encodeWithSignature("getFailing()");

        aggregate(_calls, true);
    }

    function test_single_call_with_failure() public {
        storeA.set(123);

        Call[] memory _calls = new Call[](1);
        _calls[0].target = address(storeA);
        _calls[0].callData = abi.encodeWithSignature("getFailing()");

        (,, Return[] memory _returnData) = aggregate(_calls, false);

        bool _success = _returnData[0].success;
        bytes memory _words = _returnData[0].data;

        assert(_success == false);
        assertEq0(_words, "");
    }

    function test_multi_call_with_one_failure() public {
        storeA.set(123);
        storeB.set(123);

        Call[] memory _calls = new Call[](2);
        _calls[0].target = address(storeA);
        _calls[0].callData = abi.encodeWithSignature("getFailing()");
        _calls[1].target = address(storeB);
        _calls[1].callData = abi.encodeWithSignature("getAdd(uint256)", 1);

        (,, Return[] memory _returnData) = aggregate(_calls, false);

        bool _successA = _returnData[0].success;
        bytes memory _wordA = _returnData[0].data;

        bool _successB = _returnData[1].success;
        bytes memory _wordB = _returnData[1].data;
        uint256 _returnValB;
        assembly { _returnValB := mload(add(0x20, _wordB)) }

        assert(_successA == false);
        assert(_successB);
        assertEq0(_wordA, "");
        assertEq(_returnValB, 124);
    }

    function test_helpers() public {
        bytes32 blockHash = getBlockHash(510);
        bytes32 lastBlockHash = getLastBlockHash();
        uint256 timestamp = getCurrentBlockTimestamp();
        uint256 difficulty = getCurrentBlockDifficulty();
        uint256 gaslimit = getCurrentBlockGasLimit();
        address coinbase = getCurrentBlockCoinbase();
        uint256 balance = getEthBalance(address(this));

        assertEq(blockHash, blockhash(510));
        assertEq(lastBlockHash, blockhash(block.number - 1));
        assertEq(timestamp, block.timestamp);
        assertEq(difficulty, block.difficulty);
        assertEq(gaslimit, block.gaslimit);
        assertEq(coinbase, block.coinbase);
        assertEq(balance, address(this).balance);
    }
}
