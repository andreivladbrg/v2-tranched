// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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

    IERC20 public constant dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    SablierV2Comptroller internal comptroller = SablierV2Comptroller(0xC3Be6BffAeab7B297c03383B4254aa3Af2b9a5BA);
    SablierV2NFTDescriptor internal nftDescriptor = SablierV2NFTDescriptor(0x23eD5DA55AF4286c0dE55fAcb414dEE2e317F4CB);
    SablierV2LockupDynamic internal lockupDynamic = SablierV2LockupDynamic(0x7CC7e125d83A581ff438608490Cc0f7bDff79127);

    SablierV2LockupTranched internal lockupTranched;

    function setUp() public {
        // Fork Ethereum Mainnet
        vm.createSelectFork({ urlOrAlias: "mainnet" });

        lockupTranched = new SablierV2LockupTranched(admin, comptroller, nftDescriptor, 300);

        admin = payable(makeAddr("admin"));
        sender = payable(makeAddr("sender"));
        recipient = payable(makeAddr("recipient"));

        vm.deal({ account: sender, newBalance: 1 ether });
        deal({ token: address(dai), to: sender, give: 1_000_000e18 });

        vm.startPrank({ msgSender: sender });
        dai.approve({ spender: address(lockupDynamic), amount: UINT256_MAX });
        dai.approve({ spender: address(lockupTranched), amount: UINT256_MAX });
    }

    function _now() internal view returns (uint40) {
        return uint40(block.timestamp);
    }

    uint40 internal cliffDuration = 2500 seconds;

    /*//////////////////////////////////////////////////////////////////////////
                                      TRANCHES
    //////////////////////////////////////////////////////////////////////////*/

    function getTranches(uint256 count) internal view returns (SablierV2LockupTranched.Tranche[] memory) {
        SablierV2LockupTranched.Tranche[] memory _tranches = new SablierV2LockupTranched.Tranche[](count);
        for (uint40 i = 0; i < count; ++i) {
            _tranches[i] = tranche();
            _tranches[i].milestone += i;
        }
        return _tranches;
    }

    function tranche() internal view returns (ISablierV2LockupTranched.Tranche memory) {
        ISablierV2LockupTranched.Tranche memory _tranche =
            ISablierV2LockupTranched.Tranche({ amount: 10e18, milestone: _now() + cliffDuration });
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
        for (uint40 i = 0; i < count; ++i) {
            _segments[i] = segment();
            _segments[i].milestone += i;
        }
        return _segments;
    }

    function segment() internal view returns (LockupDynamic.Segment memory) {
        return
            LockupDynamic.Segment({ amount: 10e18, exponent: UD2x18.wrap(3.14e18), milestone: _now() + cliffDuration });
    }
}
