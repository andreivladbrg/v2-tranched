// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { UD2x18 } from "@prb/math/src/UD2x18.sol";
import { ud } from "@prb/math/src/UD60x18.sol";
import { SablierV2Comptroller } from "@sablier/v2-core/src/SablierV2Comptroller.sol";
import { SablierV2LockupDynamic } from "@sablier/v2-core/src/SablierV2LockupDynamic.sol";
import { Broker, LockupDynamic } from "@sablier/v2-core/src/types/DataTypes.sol";
import { SablierV2NFTDescriptor } from "@sablier/v2-core/src/SablierV2NFTDescriptor.sol";

import { SablierV2LockupTranched } from "src/SablierV2LockupTranched.sol";
import { ISablierV2LockupTranched } from "src/interfaces/ISablierV2LockupTranched.sol";

import { Test } from "forge-std/src/Test.sol";

abstract contract Base_Test is Test {
    address public admin;
    address public sender;
    address public recipient;

    SablierV2Comptroller internal comptroller;
    SablierV2NFTDescriptor internal nftDescriptor;

    ERC20 public dai;
    SablierV2LockupDynamic internal lockupDynamic;
    SablierV2LockupTranched internal lockupTranched;

    function setUp() public {
        admin = makeAddr("admin");
        sender = makeAddr("sender");
        recipient = makeAddr("recipient");

        dai = new ERC20("Dai Stablecoin", "DAI");

        comptroller = new SablierV2Comptroller(admin);
        nftDescriptor = new SablierV2NFTDescriptor();
        lockupDynamic = new SablierV2LockupDynamic(admin, comptroller, nftDescriptor, 300);
        lockupTranched = new SablierV2LockupTranched(admin, comptroller, nftDescriptor, 300);

        vm.deal({ account: sender, newBalance: 1 ether });
        deal({ token: address(dai), to: sender, give: 1_000_000e18 });

        vm.startPrank({ msgSender: sender });
        dai.approve({ spender: address(lockupDynamic), amount: UINT256_MAX });
        dai.approve({ spender: address(lockupTranched), amount: UINT256_MAX });
    }

    function _now() internal view returns (uint40) {
        return uint40(block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TRANCHES
    //////////////////////////////////////////////////////////////////////////*/

    function getTranches(uint256 count) internal view returns (SablierV2LockupTranched.Tranche[] memory) {
        SablierV2LockupTranched.Tranche[] memory _tranches = new SablierV2LockupTranched.Tranche[](count);

        uint40 stepDuration = 100 seconds;
        for (uint40 i = 0; i < count; ++i) {
            _tranches[i] = tranche();
            _tranches[i].milestone += stepDuration;
            stepDuration += 100; // increment it so that we will have tranches milestones in an ascending order
        }
        return _tranches;
    }

    function tranche() internal view returns (ISablierV2LockupTranched.Tranche memory) {
        ISablierV2LockupTranched.Tranche memory _tranche =
            ISablierV2LockupTranched.Tranche({ amount: 10e18, milestone: _now() });
        return _tranche;
    }

    function getTranchedParams(uint256 count)
        internal
        view
        returns (ISablierV2LockupTranched.CreateWithMilestones memory)
    {
        return ISablierV2LockupTranched.CreateWithMilestones({
            sender: sender,
            recipient: recipient,
            totalAmount: uint128(10e18 * count),
            asset: dai,
            cancelable: true,
            transferable: true,
            startTime: _now(),
            tranches: getTranches(count),
            broker: Broker({ account: address(0), fee: ud(0) })
        });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      SEGMENTS
    //////////////////////////////////////////////////////////////////////////*/

    function getDynamicParams(uint256 count) internal view returns (LockupDynamic.CreateWithMilestones memory) {
        return LockupDynamic.CreateWithMilestones({
            sender: sender,
            recipient: recipient,
            totalAmount: uint128(10e18 * count),
            asset: dai,
            cancelable: true,
            transferable: true,
            segments: getSegments(count),
            startTime: _now(),
            broker: Broker({ account: address(0), fee: ud(0) })
        });
    }

    function getSegments(uint256 count) internal view returns (LockupDynamic.Segment[] memory) {
        LockupDynamic.Segment[] memory _segments = new LockupDynamic.Segment[](count);
        uint40 stepDuration = 100 seconds;
        for (uint40 i = 0; i < count; ++i) {
            _segments[i] = segment();
            _segments[i].milestone += stepDuration;
            stepDuration += 100; // increment it so that we will have segments milestones in an ascending order
        }
        return _segments;
    }

    function segment() internal view returns (LockupDynamic.Segment memory) {
        return LockupDynamic.Segment({ amount: 10e18, exponent: UD2x18.wrap(3.14e18), milestone: _now() });
    }
}
