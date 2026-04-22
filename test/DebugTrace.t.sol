// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {LidoAaveGuard} from "../src/LidoAaveGuard.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Debug test — isolated to find why checkAndDeleverage returns success=false
contract DebugTraceTest is Test {
    address constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    LidoAaveGuard public guard;
    address owner = address(0x1);
    address user = address(0x2);

    function setUp() public {
        console2.log("setUp: start");
        vm.etch(STETH, bytes("deadbeef"));
        vm.etch(AAVE_POOL, bytes("deadbeef"));
        
        guard = new LidoAaveGuard(owner);
        console2.log("setUp: deployed guard");

        // configureUser reads pool
        _mockForConfigureUser(user, type(uint256).max);
        vm.prank(user);
        guard.configureUser(STETH, address(0), 1e18);

        vm.warp(block.timestamp + 400);
        console2.log("setUp: done");
    }

    // ── STEP TESTS ───────────────────────────────────────────────────────────

    function test_step1_directPoolCall() public view {
        (, , , , , uint256 f) = IPool(AAVE_POOL).getUserAccountData(user);
        console2.log("[step1] direct pool HF:", f);
        assertEq(f, 103e16);
    }

    /// @dev This test uses a FRESH guard (not the setUp's guard)
    function test_step2_freshGuard() public {
        // Deploy fresh inside this test — does it revert?
        console2.log("about to deploy fresh guard...");
        LidoAaveGuard fresh = new LidoAaveGuard(owner);
        console2.log("fresh guard deployed");
        
        assertTrue(address(fresh) != address(0), "guard should be non-zero");
    }

    function test_step3_getHealthFactor() public {
        _enqueueMock(user, 100e18, 97e18, 2e18, 8000, 103e16);

        uint256 hf = guard.getHealthFactor(user);
        console2.log("[step3] getHealthFactor:", hf);
        assertEq(hf, 103e16);
    }

    function test_step4_threshold() public pure {
        // Can't call non-view in pure... just a note: threshold = 105e16
        assertTrue(true); // placeholder for static check
    }

    /// @dev The main test - full flow with proper mocks from setUp guard
    function test_step5_fullCheckAndDeleverage() public {
        uint256 repayAmt = (uint256(97e18) + 1) / 2;

        console2.log("Seeding 5 HF=103e16 mocks...");
        for (uint i; i < 5; i++) {
            _enqueueMock(user, 100e18, 97e18, 2e18, 8000, 103e16);
        }
        console2.log("Done seeding");

        // Repay mock
        vm.mockCall(
            AAVE_POOL,
            abi.encodeWithSelector(IPool.repay.selector, STETH, repayAmt, 0, user),
            abi.encode(repayAmt)
        );
        _enqueueMock(user, 51e18, 48e18, 3e18, 8000, uint256(133e16));
        vm.mockCall(
            AAVE_POOL,
            abi.encodeWithSelector(IPool.withdraw.selector, STETH, repayAmt, user),
            abi.encode(repayAmt)
        );
        vm.mockCall(STETH, abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(90e18));

        console2.log("Calling checkAndDeleverage...");
        (bool success, uint256 hf) = guard.checkAndDeleverage(user);
        console2.log("[step5] success:", success ? 1 : 0);
        console2.log("[step5] hf returned:", hf);

        assertTrue(success, "checkAndDeleverage should succeed for HF=1.03");
    }

    /// @dev Test checkAndDeleverage WITHOUT setUp guard's configureUser side-effects
    function test_step6_isolatedCheck() public {
        address freshUser = makeAddr("freshUser");
        
        // Deploy fresh guard just for this user
        LidoAaveGuard g2 = new LidoAaveGuard(owner);
        console2.log("g2 deployed");

        _mockForConfigureUser(freshUser, type(uint256).max);
        vm.prank(freshUser);
        g2.configureUser(STETH, address(0), 1e18);
        console2.log("freshUser configured");
        vm.warp(block.timestamp + 400);

        // Seed one HF=103 mock for entry check
        _enqueueMock(freshUser, 100e18, 97e18, 2e18, 8000, 103e16);

        (bool success, uint256 hf) = g2.checkAndDeleverage(freshUser);
        console2.log("[step6] success:", success ? 1 : 0);
        
        assertTrue(success && hf == 103e16);
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    function _mockForConfigureUser(address userAddr, uint256 hf) internal {
        vm.mockCall(
            AAVE_POOL,
            abi.encodeWithSelector(IPool.getUserAccountData.selector, userAddr),
            abi.encode(uint256(100e18), uint256(0), uint256(50e18), uint256(8000), uint256(0), hf)
        );
    }

    function _enqueueMock(
        address userAddr,
        uint256 totalCollateralETH,
        uint256 totalDebtETH,
        uint256 availableBorrowsETH,
        uint256 liquidationThreshold,
        uint256 healthFactor
    ) internal {
        vm.mockCall(
            AAVE_POOL,
            abi.encodeWithSelector(IPool.getUserAccountData.selector, userAddr),
            abi.encode(totalCollateralETH, totalDebtETH, availableBorrowsETH, liquidationThreshold, uint256(0), healthFactor)
        );
    }
}