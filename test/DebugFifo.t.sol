pragma solidity >=0.8.7 <0.9.0;
import {Test} from "forge-std/Test.sol";
import {LidoAaveGuard} from "../src/LidoAaveGuard.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";

contract DebugFifoTest is Test {
    address constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    LidoAaveGuard public guard;
    address owner = address(0x1);
    address user = address(0x2);

    function setUp() public {
        vm.etch(STETH, bytes("deadbeef"));
        vm.etch(AAVE_POOL, bytes("deadbeef"));
        guard = new LidoAaveGuard(owner);

        _mockForConfigureUser(user, type(uint256).max);
        vm.prank(user);
        guard.configureUser(STETH, address(0), 1e18);
    }

    function testFifoBehavior() public {
        // Enqueue mock 1: HF = 103
        vm.mockCall(
            AAVE_POOL,
            abi.encodeWithSelector(IPool.getUserAccountData.selector, user),
            abi.encode(uint256(100e18), uint256(95e18), uint256(5e18), uint256(8000), uint256(0), uint256(103e16))
        );

        (,,,, uint256 hf1,) = guard.getAccountData(user);
        emit log_named_uint("HF1", hf1);

        // Enqueue mock 2: HF = 140
        vm.mockCall(
            AAVE_POOL,
            abi.encodeWithSelector(IPool.getUserAccountData.selector, user),
            abi.encode(uint256(100e18), uint256(47e18), uint256(5e18), uint256(8000), uint256(0), uint256(140e16))
        );

        (,,,, uint256 hf2,) = guard.getAccountData(user);
        emit log_named_uint("HF2", hf2);

        assertEq(hf1, 103e16, "first call should read HF=103");
        assertEq(hf2, 140e16, "second call should read HF=140");
    }

    function _mockForConfigureUser(address userAddr, uint256 hf) internal {
        vm.mockCall(
            AAVE_POOL,
            abi.encodeWithSelector(IPool.getUserAccountData.selector, userAddr),
            abi.encode(uint256(100e18), uint256(0), uint256(50e18), uint256(8000), uint256(0), hf)
        );
    }
}
