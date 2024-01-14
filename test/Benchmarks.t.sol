// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23;

import { LockupDynamic } from "@sablier/v2-core/src/types/DataTypes.sol";
import { ISablierV2LockupTranched } from "src/interfaces/ISablierV2LockupTranched.sol";

import { console2 } from "forge-std/src/console2.sol";

import { Base_Test } from "./Base.t.sol";

contract Benchmarks is Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                  CREATE FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    // Note: we start from the second stream (index = 1), because the first stream will consume more gas the second
    // stream, even if they both have a single segment/tranche. The first stream ever created involves writing
    // multiple zero slots to non-zero values. This is we start from an index of 1.

    function test_CreateWithMilestones_LockupDynamic_GasTests() external {
        uint8[9] memory segmentCounts = [1, 4, 8, 12, 24, 48, 72, 96, 120];
        uint256[] memory beforeGas = new uint256[](segmentCounts.length);
        uint256[] memory afterGas = new uint256[](segmentCounts.length);

        LockupDynamic.CreateWithMilestones memory params;
        for (uint256 i = 0; i < segmentCounts.length; ++i) {
            params = getDynamicParams(segmentCounts[i]);
            beforeGas[i] = gasleft();
            lockupDynamic.createWithMilestones(params);
            afterGas[i] = gasleft();
        }

        for (uint256 i = 1; i < segmentCounts.length; ++i) {
            uint256 gasUsed = beforeGas[i] - afterGas[i];
            console2.log("Gas used for createWithMilestones: ", gasUsed, " with segments length: ", segmentCounts[i]);
        }
    }

    function test_CreateWithMilestones2_LockupDynamic_GasTests() external {
        uint8[9] memory segmentCounts = [1, 2, 4, 6, 12, 24, 36, 48, 60];
        uint256[] memory beforeGas = new uint256[](segmentCounts.length);
        uint256[] memory afterGas = new uint256[](segmentCounts.length);

        LockupDynamic.CreateWithMilestones memory params;
        for (uint256 i = 0; i < segmentCounts.length; ++i) {
            params = getDynamicParams(segmentCounts[i]);
            beforeGas[i] = gasleft();
            lockupDynamic.createWithMilestones(params);
            afterGas[i] = gasleft();
        }

        for (uint256 i = 1; i < segmentCounts.length; ++i) {
            uint256 gasUsed = beforeGas[i] - afterGas[i];
            console2.log("Gas used for createWithMilestones: ", gasUsed, " with segments length: ", segmentCounts[i]);
        }
    }

    function test_CreateWithMilestones_LockupTranched_GasTests() external {
        uint8[9] memory trancheCounts = [1, 2, 4, 6, 12, 24, 36, 48, 60];
        uint256[] memory beforeGas = new uint256[](trancheCounts.length);
        uint256[] memory afterGas = new uint256[](trancheCounts.length);

        ISablierV2LockupTranched.CreateWithMilestones memory params;
        for (uint256 i = 0; i < trancheCounts.length; ++i) {
            params = getTranchedParams(trancheCounts[i]);
            beforeGas[i] = gasleft();
            lockupTranched.createWithMilestones(params);
            afterGas[i] = gasleft();
        }

        for (uint256 i = 1; i < trancheCounts.length; ++i) {
            uint256 gasUsed = beforeGas[i] - afterGas[i];
            console2.log("Gas used for createWithMilestones: ", gasUsed, " with tranches length: ", trancheCounts[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                 WITHDRAW FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function test_Withdraw_LockupDynamic_GasTests() external {
        uint8[9] memory segmentCounts = [4, 4, 8, 12, 24, 48, 72, 96, 120];

        uint256[] memory streamIds = new uint256[](segmentCounts.length);

        LockupDynamic.CreateWithMilestones memory params;
        for (uint256 i = 0; i < segmentCounts.length; ++i) {
            params = getDynamicParams(segmentCounts[i]);
            streamIds[i] = lockupDynamic.createWithMilestones(params);
        }

        uint256[] memory beforeGas = new uint256[](segmentCounts.length);
        uint256[] memory afterGas = new uint256[](segmentCounts.length);

        uint40 warpTime;
        uint128 withdrawAmount;
        for (uint256 i = 0; i < segmentCounts.length; ++i) {
            // 10 seconds before the end time to calculate the streamed amount for the last segment
            warpTime = lockupDynamic.getEndTime(streamIds[i]) - 10;
            vm.warp(warpTime);

            withdrawAmount = lockupDynamic.withdrawableAmountOf(streamIds[i]);

            beforeGas[i] = gasleft();
            lockupDynamic.withdraw(streamIds[i], recipient, withdrawAmount);
            afterGas[i] = gasleft();
        }

        for (uint256 i = 1; i < segmentCounts.length; ++i) {
            uint256 gasUsed = beforeGas[i] - afterGas[i];
            console2.log("Gas used for withdraw: ", gasUsed, " with segments length: ", segmentCounts[i]);
        }
    }

    function test_Withdraw2_LockupDynamic_GasTests() external {
        uint8[9] memory segmentCounts = [2, 2, 4, 6, 12, 24, 36, 48, 60];

        uint256[] memory streamIds = new uint256[](segmentCounts.length);

        LockupDynamic.CreateWithMilestones memory params;
        for (uint256 i = 0; i < segmentCounts.length; ++i) {
            params = getDynamicParams(segmentCounts[i]);
            streamIds[i] = lockupDynamic.createWithMilestones(params);
        }

        uint256[] memory beforeGas = new uint256[](segmentCounts.length);
        uint256[] memory afterGas = new uint256[](segmentCounts.length);

        uint40 warpTime;
        uint128 withdrawAmount;
        for (uint256 i = 0; i < segmentCounts.length; ++i) {
            // 10 seconds before the end time to calculate the streamed amount for the last segment
            warpTime = lockupDynamic.getEndTime(streamIds[i]) - 10;
            vm.warp(warpTime);

            withdrawAmount = lockupDynamic.withdrawableAmountOf(streamIds[i]);

            beforeGas[i] = gasleft();
            lockupDynamic.withdraw(streamIds[i], recipient, withdrawAmount);
            afterGas[i] = gasleft();
        }

        for (uint256 i = 1; i < segmentCounts.length; ++i) {
            uint256 gasUsed = beforeGas[i] - afterGas[i];
            console2.log("Gas used for withdraw: ", gasUsed, " with segments length: ", segmentCounts[i]);
        }
    }

    function test_Withdraw_LockupTranched_GasTests() external {
        uint8[9] memory trancheCounts = [2, 2, 4, 6, 12, 24, 36, 48, 60];

        uint256[] memory streamIds = new uint256[](trancheCounts.length);

        ISablierV2LockupTranched.CreateWithMilestones memory params;
        for (uint256 i = 0; i < trancheCounts.length; ++i) {
            params = getTranchedParams(trancheCounts[i]);
            streamIds[i] = lockupTranched.createWithMilestones(params);
        }

        uint256[] memory beforeGas = new uint256[](trancheCounts.length);
        uint256[] memory afterGas = new uint256[](trancheCounts.length);

        uint40 warpTime;
        uint128 withdrawAmount;
        for (uint256 i = 0; i < trancheCounts.length; ++i) {
            // 10 seconds before the end time to calculate the streamed amount for the last tranche
            warpTime = lockupTranched.getEndTime(streamIds[i]) - 10;
            vm.warp(warpTime);

            withdrawAmount = lockupTranched.withdrawableAmountOf(streamIds[i]);

            beforeGas[i] = gasleft();
            lockupTranched.withdraw(streamIds[i], recipient, withdrawAmount);
            afterGas[i] = gasleft();
        }

        for (uint256 i = 1; i < trancheCounts.length; ++i) {
            uint256 gasUsed = beforeGas[i] - afterGas[i];
            console2.log("Gas used for withdraw: ", gasUsed, " with tranches length: ", trancheCounts[i]);
        }
    }
}
