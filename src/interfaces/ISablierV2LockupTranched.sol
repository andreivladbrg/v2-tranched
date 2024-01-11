// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISablierV2Lockup} from "@sablier/v2-core/src/interfaces/ISablierV2Lockup.sol";
import {Broker, Lockup} from "@sablier/v2-core/src/types/DataTypes.sol";

/// @title ISablierV2LockupTranched
/// @notice Creates and manages Lockup streams with dynamic streaming functions.
interface ISablierV2LockupTranched is ISablierV2Lockup {
    /*//////////////////////////////////////////////////////////////////////////
                                       ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    error SablierV2LockupTranched_TrancheCountZero();
    error SablierV2LockupTranched_TrancheCountTooHigh(uint256);
    error SablierV2LockupTranched_StartTimeNotLessThanFirstTrancheMilestone(uint40, uint40);
    error SablierV2LockupTranched_TrancheMilestonesNotOrdered(uint256, uint40, uint40);
    error SablierV2LockupTranched_DepositAmountNotEqualToTrancheAmountsSum(uint128, uint128);

    /*//////////////////////////////////////////////////////////////////////////
                                       TYPES
    //////////////////////////////////////////////////////////////////////////*/

    struct Tranche {
        uint128 amount;
        uint40 milestone;
    }

    struct Stream {
        // slot 0
        address sender;
        uint40 startTime;
        uint40 endTime;
        bool isCancelable;
        bool wasCanceled;
        // slot 1
        IERC20 asset;
        bool isDepleted;
        bool isStream;
        bool isTransferable;
        // slot 2 and 3
        Lockup.Amounts amounts;
        // slots [4..n]
        Tranche[] tranches;
    }

    struct CreateWithMilestones {
        address sender;
        uint40 startTime;
        bool cancelable;
        bool transferable;
        address recipient;
        uint128 totalAmount;
        IERC20 asset;
        Broker broker;
        Tranche[] tranches;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                       EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a stream is created.
    /// @param streamId The id of the newly created stream.
    /// @param funder The address which has funded the stream.
    /// @param sender The address from which to stream the assets, who will have the ability to cancel the stream.
    /// @param recipient The address toward which to stream the assets.
    /// @param amounts Struct containing (i) the deposit amount, (ii) the protocol fee amount, and (iii) the
    /// broker fee amount, all denoted in units of the asset's decimals.
    /// @param asset The contract address of the ERC-20 asset used for streaming.
    /// @param cancelable Boolean indicating whether the stream will be cancelable or not.
    /// @param transferable Boolean indicating whether the stream NFT is transferable or not.
    /// @param tranches The tranches the protocol uses to compose the custom unlocked amounts.
    /// @param broker The address of the broker who has helped create the stream, e.g. a front-end website.
    event CreateLockupTranchedStream(
        uint256 streamId,
        address funder,
        address indexed sender,
        address indexed recipient,
        Lockup.CreateAmounts amounts,
        IERC20 indexed asset,
        bool cancelable,
        bool transferable,
        Tranche[] tranches,
        address broker
    );

    /*//////////////////////////////////////////////////////////////////////////
                                 CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice The maximum number of tranches allowed in a stream.
    /// @dev This is initialized at construction time and cannot be changed later.
    function MAX_TRANCHE_COUNT() external view returns (uint256);

    /// @notice Retrieves the tranches the protocol uses to compose the custom unlocked amounts.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The stream id for the query.
    function getTranches(uint256 streamId) external view returns (Tranche[] memory tranches);

    /// @notice Retrieves the stream entity.
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The stream id for the query.
    function getStream(uint256 streamId) external view returns (Stream memory stream);

    /// @notice Calculates the amount streamed to the recipient, denoted in units of the asset's decimals.
    ///
    /// Upon cancellation of the stream, the amount streamed is calculated as the difference between the deposited
    /// amount and the refunded amount. Ultimately, when the stream becomes depleted, the streamed amount is equivalent
    /// to the total amount withdrawn.
    ///
    /// @dev Reverts if `streamId` references a null stream.
    /// @param streamId The stream id for the query.
    function streamedAmountOf(uint256 streamId) external view returns (uint128 streamedAmount);

    /*//////////////////////////////////////////////////////////////////////////
                               NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Creates a stream with the provided segment milestones, implying the end time from the last milestone.
    /// The stream is funded by `msg.sender` and is wrapped in an ERC-721 NFT.
    ///
    /// @dev Emits a {Transfer} and {CreateLockupTranchedStream} event.
    ///
    /// Notes:
    /// - As long as the segment milestones are arranged in ascending order, it is not an error for some
    /// of them to be in the past.
    ///
    /// Requirements:
    /// - Must not be delegate called.
    /// - `params.totalAmount` must be greater than zero.
    /// - If set, `params.broker.fee` must not be greater than `MAX_FEE`.
    /// - `params.segments` must have at least one segment, but not more than `MAX_SEGMENT_COUNT`.
    /// - `params.startTime` must be less than the first segment's milestone.
    /// - The segment milestones must be arranged in ascending order.
    /// - The last segment milestone (i.e. the stream's end time) must be in the future.
    /// - The sum of the segment amounts must equal the deposit amount.
    /// - `params.recipient` must not be the zero address.
    /// - `msg.sender` must have allowed this contract to spend at least `params.totalAmount` assets.
    ///
    /// @param params Struct encapsulating the function parameters, which are documented in {DataTypes}.
    /// @return streamId The id of the newly created stream.
    function createWithMilestones(CreateWithMilestones calldata params) external returns (uint256 streamId);
}
