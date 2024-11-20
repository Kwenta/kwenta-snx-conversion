// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Bootstrap} from "test/utils/Bootstrap.sol";
import {IConversion} from "src/interfaces/IConversion.sol";

contract ConversionTest is Bootstrap {
    function setUp() public {
        initializeLocal();
        /// @dev warp ahead of the vesting start time to simulate deployment conditions
        vm.warp(VESTING_START_TIME + 1 weeks);
    }

    function testConversionRateFixed17to1() public {}

    function testLockAndConvert() public {
        KWENTA.mint(TEST_USER_1, TEST_AMOUNT);
        uint256 owedSNXBefore = conversion.owedSNX(TEST_USER_1);
        uint256 userKWENTABefore = KWENTA.balanceOf(TEST_USER_1);
        uint256 contractKWENTABefore = KWENTA.balanceOf(address(conversion));
        assertEq(owedSNXBefore, 0);
        assertEq(userKWENTABefore, TEST_AMOUNT);
        assertEq(contractKWENTABefore, 0);

        vm.startPrank(TEST_USER_1);
        KWENTA.approve(address(conversion), TEST_AMOUNT);
        conversion.lockAndConvert();
        vm.stopPrank();

        uint256 owedSNXAfter = conversion.owedSNX(TEST_USER_1);
        uint256 userKWENTAAfter = KWENTA.balanceOf(TEST_USER_1);
        uint256 contractKWENTAAfter = KWENTA.balanceOf(address(conversion));
        assertEq(owedSNXAfter, CONVERTED_SNX_AMOUNT);
        assertEq(userKWENTAAfter, 0);
        assertEq(contractKWENTAAfter, TEST_AMOUNT);
    }

    function testLockAndConvertEmit() public {
        KWENTA.mint(TEST_USER_1, TEST_AMOUNT);
        vm.startPrank(TEST_USER_1);
        KWENTA.approve(address(conversion), TEST_AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit KWENTALocked(TEST_USER_1, TEST_AMOUNT);
        conversion.lockAndConvert();
        vm.stopPrank();
    }

    function testLockAndConvertInsufficientKWENTA() public {
        uint256 balance = KWENTA.balanceOf(TEST_USER_2);
        assertEq(balance, 0);

        vm.startPrank(TEST_USER_2);
        KWENTA.approve(address(conversion), TEST_AMOUNT);
        vm.expectRevert(IConversion.InsufficientKWENTA.selector);
        conversion.lockAndConvert();
        vm.stopPrank();
    }

    function testVestableAmountBeforeCliff() public {
        basicLock();

        uint256 vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(VESTING_START_TIME + VESTING_CLIFF_DURATION);
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(block.timestamp + 1);
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertGt(vestableAmount, 0);
    }

    function testVestableAmountLinear() public {
        basicLock();

        vm.warp(VESTING_START_TIME + VESTING_CLIFF_DURATION);
        uint256 vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(block.timestamp + 1);
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT / LINEAR_VESTING_DURATION);

        vm.warp(
            VESTING_START_TIME + VESTING_CLIFF_DURATION
                + LINEAR_VESTING_DURATION / 3
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT / 3);

        vm.warp(
            VESTING_START_TIME + VESTING_CLIFF_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT / 2);

        vm.warp(
            VESTING_START_TIME + VESTING_CLIFF_DURATION
                + LINEAR_VESTING_DURATION
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT);
    }

    function testVestableAmountLinearFuzz(uint64 amount) public {
        basicLock();

        vm.warp(VESTING_START_TIME + VESTING_CLIFF_DURATION);
        uint256 vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(block.timestamp + amount);
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        if (amount > LINEAR_VESTING_DURATION) {
            assertEq(vestableAmount, CONVERTED_SNX_AMOUNT);
        } else {
            assertEq(
                vestableAmount,
                CONVERTED_SNX_AMOUNT * amount / LINEAR_VESTING_DURATION
            );
        }
    }

    function testVestableAmountVest() public {
        basicLock();

        vm.warp(VESTING_START_TIME + VESTING_CLIFF_DURATION);
        uint256 vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(
            VESTING_START_TIME + VESTING_CLIFF_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT / 2);

        vm.prank(TEST_USER_1);
        conversion.vest(TEST_USER_1);

        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(
            VESTING_START_TIME + VESTING_CLIFF_DURATION
                + LINEAR_VESTING_DURATION
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT / 2);
    }

    function testVestableAmountLockMore() public {
        basicLock();

        vm.warp(VESTING_START_TIME + VESTING_CLIFF_DURATION);
        uint256 vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(
            VESTING_START_TIME + VESTING_CLIFF_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT / 2);

        basicLock();
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT);

        vm.warp(
            VESTING_START_TIME + VESTING_CLIFF_DURATION
                + LINEAR_VESTING_DURATION
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT * 2);
    }

    function testVestableAmountLockMoreAndVest() public {
        basicLock();

        vm.warp(VESTING_START_TIME + VESTING_CLIFF_DURATION);
        uint256 vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(
            VESTING_START_TIME + VESTING_CLIFF_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT / 2);

        basicLock();
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT);

        vm.prank(TEST_USER_1);
        conversion.vest(TEST_USER_1);

        vm.warp(
            VESTING_START_TIME + VESTING_CLIFF_DURATION
                + LINEAR_VESTING_DURATION
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT);
    }

    function testVest() public {
        basicLock();

        uint256 userSNXBefore = SNX.balanceOf(TEST_USER_1);
        uint256 contractSNXBefore = SNX.balanceOf(address(conversion));
        uint256 claimedSNXBefore = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXBefore, 0);
        assertEq(contractSNXBefore, MINT_AMOUNT);
        assertEq(claimedSNXBefore, 0);

        vm.warp(
            VESTING_START_TIME + VESTING_CLIFF_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vm.prank(TEST_USER_1);
        conversion.vest(TEST_USER_1);

        uint256 userSNXAfter = SNX.balanceOf(TEST_USER_1);
        uint256 contractSNXAfter = SNX.balanceOf(address(conversion));
        uint256 claimedSNXAfter = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXAfter, CONVERTED_SNX_AMOUNT / 2);
        assertEq(contractSNXAfter, MINT_AMOUNT - (CONVERTED_SNX_AMOUNT / 2));
        assertEq(claimedSNXAfter, CONVERTED_SNX_AMOUNT / 2);

        vm.warp(
            VESTING_START_TIME + VESTING_CLIFF_DURATION
                + LINEAR_VESTING_DURATION
        );
        vm.prank(TEST_USER_1);
        conversion.vest(TEST_USER_1);

        uint256 userSNXFinal = SNX.balanceOf(TEST_USER_1);
        uint256 contractSNXFinal = SNX.balanceOf(address(conversion));
        uint256 claimedSNXFinal = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXFinal, CONVERTED_SNX_AMOUNT);
        assertEq(contractSNXFinal, MINT_AMOUNT - CONVERTED_SNX_AMOUNT);
        assertEq(claimedSNXFinal, CONVERTED_SNX_AMOUNT);
    }

    function testVestBasic() public {
        basicLock();

        uint256 userSNXBefore = SNX.balanceOf(TEST_USER_1);
        uint256 contractSNXBefore = SNX.balanceOf(address(conversion));
        uint256 claimedSNXBefore = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXBefore, 0);
        assertEq(contractSNXBefore, MINT_AMOUNT);
        assertEq(claimedSNXBefore, 0);

        vm.warp(
            VESTING_START_TIME + VESTING_CLIFF_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vm.prank(TEST_USER_1);
        conversion.vest();

        uint256 userSNXAfter = SNX.balanceOf(TEST_USER_1);
        uint256 contractSNXAfter = SNX.balanceOf(address(conversion));
        uint256 claimedSNXAfter = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXAfter, CONVERTED_SNX_AMOUNT / 2);
        assertEq(contractSNXAfter, MINT_AMOUNT - (CONVERTED_SNX_AMOUNT / 2));
        assertEq(claimedSNXAfter, CONVERTED_SNX_AMOUNT / 2);

        vm.warp(
            VESTING_START_TIME + VESTING_CLIFF_DURATION
                + LINEAR_VESTING_DURATION
        );
        vm.prank(TEST_USER_1);
        conversion.vest();

        uint256 userSNXFinal = SNX.balanceOf(TEST_USER_1);
        uint256 contractSNXFinal = SNX.balanceOf(address(conversion));
        uint256 claimedSNXFinal = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXFinal, CONVERTED_SNX_AMOUNT);
        assertEq(contractSNXFinal, MINT_AMOUNT - CONVERTED_SNX_AMOUNT);
        assertEq(claimedSNXFinal, CONVERTED_SNX_AMOUNT);
    }

    function testVestAfterWithdraw() public {
        basicLock();

        uint256 userSNXBefore = SNX.balanceOf(TEST_USER_1);
        uint256 contractSNXBefore = SNX.balanceOf(address(conversion));
        uint256 claimedSNXBefore = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXBefore, 0);
        assertEq(contractSNXBefore, MINT_AMOUNT);
        assertEq(claimedSNXBefore, 0);

        vm.warp(
            VESTING_START_TIME + VESTING_CLIFF_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vm.prank(TEST_USER_1);
        conversion.vest();

        uint256 userSNXAfter = SNX.balanceOf(TEST_USER_1);
        uint256 contractSNXAfter = SNX.balanceOf(address(conversion));
        uint256 claimedSNXAfter = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXAfter, CONVERTED_SNX_AMOUNT / 2);
        assertEq(contractSNXAfter, MINT_AMOUNT - (CONVERTED_SNX_AMOUNT / 2));
        assertEq(claimedSNXAfter, CONVERTED_SNX_AMOUNT / 2);

        // withdraw

        uint256 contractSNXBeforeWithdraw = SNX.balanceOf(address(conversion));
        uint256 ownerSNXBeforeWithdraw = SNX.balanceOf(TEST_OWNER);
        assertEq(
            contractSNXBeforeWithdraw, MINT_AMOUNT - (CONVERTED_SNX_AMOUNT / 2)
        );
        assertEq(ownerSNXBeforeWithdraw, 0);

        vm.warp(VESTING_START_TIME + WITHDRAW_START);
        vm.prank(TEST_OWNER);
        conversion.withdrawSNX();
        vm.prank(TEST_USER_1);
        vm.expectRevert();
        conversion.vest();

        uint256 userSNXFinal = SNX.balanceOf(TEST_USER_1);
        uint256 contractSNXFinal = SNX.balanceOf(address(conversion));
        uint256 claimedSNXFinal = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXFinal, CONVERTED_SNX_AMOUNT / 2);
        assertEq(contractSNXFinal, 0);
        assertEq(claimedSNXFinal, CONVERTED_SNX_AMOUNT / 2);

        uint256 contractSNXAfterWithdraw = SNX.balanceOf(address(conversion));
        uint256 ownerSNXAfterWithdraw = SNX.balanceOf(TEST_OWNER);
        assertEq(contractSNXAfterWithdraw, 0);
        assertEq(ownerSNXAfterWithdraw, MINT_AMOUNT - CONVERTED_SNX_AMOUNT / 2);
    }

    function testVestEmit() public {
        basicLock();

        vm.warp(
            VESTING_START_TIME + VESTING_CLIFF_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vm.prank(TEST_USER_1);
        vm.expectEmit(true, true, true, true);
        emit SNXVested(TEST_USER_1, TEST_USER_1, CONVERTED_SNX_AMOUNT / 2);
        conversion.vest(TEST_USER_1);
    }

    function testWithdrawSNX() public {
        uint256 contractSNXBefore = SNX.balanceOf(address(conversion));
        uint256 ownerSNXBefore = SNX.balanceOf(TEST_OWNER);
        assertEq(contractSNXBefore, MINT_AMOUNT);
        assertEq(ownerSNXBefore, 0);

        vm.warp(VESTING_START_TIME + WITHDRAW_START);
        vm.prank(TEST_OWNER);
        conversion.withdrawSNX();

        uint256 contractSNXAfter = SNX.balanceOf(address(conversion));
        uint256 ownerSNXAfter = SNX.balanceOf(TEST_OWNER);
        assertEq(contractSNXAfter, 0);
        assertEq(ownerSNXAfter, MINT_AMOUNT);
    }

    function testWithdrawSNXOnlyOwner() public {
        vm.prank(TEST_USER_1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)", TEST_USER_1
            )
        );
        conversion.withdrawSNX();
    }

    function testWithdrawSNXWithdrawalStartTimeNotReached() public {
        vm.warp(VESTING_START_TIME + WITHDRAW_START - 1);
        vm.prank(TEST_OWNER);
        vm.expectRevert(IConversion.WithdrawalStartTimeNotReached.selector);
        conversion.withdrawSNX();

        vm.warp(block.timestamp + 1);
        vm.prank(TEST_OWNER);
        conversion.withdrawSNX();
    }

    function testWithdrawSNXWithdrawalStartTimeNotReachedFuzz(uint128 amount)
        public
    {
        vm.warp(VESTING_START_TIME + amount);
        if (amount < WITHDRAW_START) {
            vm.prank(TEST_OWNER);
            vm.expectRevert(IConversion.WithdrawalStartTimeNotReached.selector);
            conversion.withdrawSNX();
        } else {
            vm.prank(TEST_OWNER);
            conversion.withdrawSNX();
        }
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function basicLock() public {
        KWENTA.mint(TEST_USER_1, TEST_AMOUNT);
        vm.startPrank(TEST_USER_1);
        KWENTA.approve(address(conversion), TEST_AMOUNT);
        conversion.lockAndConvert();
        vm.stopPrank();
    }
}
