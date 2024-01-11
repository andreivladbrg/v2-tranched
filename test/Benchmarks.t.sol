// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23;

import { LockupDynamic } from "@sablier/v2-core/src/types/DataTypes.sol";
import { ISablierV2LockupTranched } from "src/interfaces/ISablierV2LockupTranched.sol";

import { console2 } from "forge-std/src/console2.sol";

import { Base_Test } from "./Base.t.sol";

contract Benchmarks is Base_Test {
    // Note: we start from the second stream (index = 1), because the first stream will consume more gas the second
    // stream, even if they both have a single segment/tranche. The first stream ever created   involves writing
    // multiple zero slots to non-zero values. This is we start from an index of 1.

    function test_LockupDynamic_CreateWithMilestones_GasTests() external {
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

    function test_LockupTranched_CreateWithMilestones_GasTests() external {
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
            console2.log("Gas used for createWithMilestones: ", gasUsed, " with  length: ", trancheCounts[i]);
        }
    }
}
