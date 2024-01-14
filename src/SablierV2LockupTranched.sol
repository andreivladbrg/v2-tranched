// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23;

import { ISablierV2LockupTranched } from "./interfaces/ISablierV2LockupTranched.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { UD60x18 } from "@prb/math/src/UD60x18.sol";

import { SablierV2Lockup } from "@sablier/v2-core/src/abstracts/SablierV2Lockup.sol";
import { ISablierV2Comptroller } from "@sablier/v2-core/src/interfaces/ISablierV2Comptroller.sol";
import { ISablierV2Lockup } from "@sablier/v2-core/src/interfaces/ISablierV2Lockup.sol";
import { ISablierV2NFTDescriptor } from "@sablier/v2-core/src/interfaces/ISablierV2NFTDescriptor.sol";
import { ISablierV2LockupRecipient } from "@sablier/v2-core/src/interfaces/hooks/ISablierV2LockupRecipient.sol";
import { Errors } from "@sablier/v2-core/src/libraries/Errors.sol";
import { Helpers } from "@sablier/v2-core/src/libraries/Helpers.sol";
import { Lockup } from "@sablier/v2-core/src/types/DataTypes.sol";

/// @title SablierV2LockupTranched
/// @notice See the documentation in {ISablierV2LockupTranched}.
contract SablierV2LockupTranched is
    SablierV2Lockup, // 14 inherited components
    ISablierV2LockupTranched // 5 inherited components
{
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////////////////
                                  PRIVATE STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    uint256 public immutable MAX_TRANCHE_COUNT;

    /// @dev Sablier V2 Lockup Tranched streams mapped by unsigned integers.
    mapping(uint256 id => Stream stream) private _streams;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Emits a {TransferAdmin} event.
    /// @param initialAdmin The address of the initial contract admin.
    /// @param initialComptroller The address of the initial comptroller.
    /// @param initialNFTDescriptor The address of the initial NFT descriptor.
    /// @param maxTrancheCount The maximum number of tranches allowed per stream.
    constructor(
        address initialAdmin,
        ISablierV2Comptroller initialComptroller,
        ISablierV2NFTDescriptor initialNFTDescriptor,
        uint256 maxTrancheCount
    )
        ERC721("Sablier V2 Lockup Tranched NFT", "SAB-V2-LOCKUP-LIN")
        SablierV2Lockup(initialAdmin, initialComptroller, initialNFTDescriptor)
    {
        nextStreamId = 1;
        MAX_TRANCHE_COUNT = maxTrancheCount;
    }

    /*//////////////////////////////////////////////////////////////////////////
                           USER-FACING CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierV2Lockup
    function getAsset(uint256 streamId) external view override notNull(streamId) returns (IERC20 asset) {
        asset = _streams[streamId].asset;
    }

    /// @inheritdoc ISablierV2Lockup
    function getDepositedAmount(uint256 streamId)
        external
        view
        override
        notNull(streamId)
        returns (uint128 depositedAmount)
    {
        depositedAmount = _streams[streamId].amounts.deposited;
    }

    /// @inheritdoc ISablierV2Lockup
    function getEndTime(uint256 streamId) external view override notNull(streamId) returns (uint40 endTime) {
        endTime = _streams[streamId].endTime;
    }

    /// @inheritdoc ISablierV2Lockup
    function getRefundedAmount(uint256 streamId)
        external
        view
        override
        notNull(streamId)
        returns (uint128 refundedAmount)
    {
        refundedAmount = _streams[streamId].amounts.refunded;
    }

    /// @inheritdoc ISablierV2Lockup
    function getSender(uint256 streamId) external view override notNull(streamId) returns (address sender) {
        sender = _streams[streamId].sender;
    }

    /// @inheritdoc ISablierV2Lockup
    function getStartTime(uint256 streamId) external view override notNull(streamId) returns (uint40 startTime) {
        startTime = _streams[streamId].startTime;
    }

    function getStream(uint256 streamId) external view override notNull(streamId) returns (Stream memory stream) {
        stream = _streams[streamId];

        // Settled streams cannot be canceled.
        if (_statusOf(streamId) == Lockup.Status.SETTLED) {
            stream.isCancelable = false;
        }
    }

    function getTranches(uint256 streamId) external view returns (Tranche[] memory tranches) {
        tranches = _streams[streamId].tranches;
    }

    /// @inheritdoc ISablierV2Lockup
    function getWithdrawnAmount(uint256 streamId)
        external
        view
        override
        notNull(streamId)
        returns (uint128 withdrawnAmount)
    {
        withdrawnAmount = _streams[streamId].amounts.withdrawn;
    }

    /// @inheritdoc ISablierV2Lockup
    function isCancelable(uint256 streamId) external view override notNull(streamId) returns (bool result) {
        if (_statusOf(streamId) != Lockup.Status.SETTLED) {
            result = _streams[streamId].isCancelable;
        }
    }

    /// @inheritdoc SablierV2Lockup
    function isTransferable(uint256 streamId)
        public
        view
        override(ISablierV2Lockup, SablierV2Lockup)
        notNull(streamId)
        returns (bool result)
    {
        result = _streams[streamId].isTransferable;
    }

    /// @inheritdoc ISablierV2Lockup
    function isDepleted(uint256 streamId)
        public
        view
        override(ISablierV2Lockup, SablierV2Lockup)
        notNull(streamId)
        returns (bool result)
    {
        result = _streams[streamId].isDepleted;
    }

    /// @inheritdoc ISablierV2Lockup
    function isStream(uint256 streamId) public view override(ISablierV2Lockup, SablierV2Lockup) returns (bool result) {
        result = _streams[streamId].isStream;
    }

    /// @inheritdoc ISablierV2Lockup
    function refundableAmountOf(uint256 streamId)
        external
        view
        override
        notNull(streamId)
        returns (uint128 refundableAmount)
    {
        // These checks are needed because {_calculateStreamedAmount} does not look up the stream's status. Note that
        // checking for `isCancelable` also checks if the stream `wasCanceled` thanks to the protocol invariant that
        // canceled streams are not cancelable anymore.
        if (_streams[streamId].isCancelable && !_streams[streamId].isDepleted) {
            refundableAmount = _streams[streamId].amounts.deposited - _calculateStreamedAmount(streamId);
        }
        // Otherwise, the result is implicitly zero.
    }

    /// @inheritdoc ISablierV2Lockup
    function statusOf(uint256 streamId) external view override notNull(streamId) returns (Lockup.Status status) {
        status = _statusOf(streamId);
    }

    /// @inheritdoc ISablierV2LockupTranched
    function streamedAmountOf(uint256 streamId)
        public
        view
        override(ISablierV2Lockup, ISablierV2LockupTranched)
        notNull(streamId)
        returns (uint128 streamedAmount)
    {
        streamedAmount = _streamedAmountOf(streamId);
    }

    /// @inheritdoc ISablierV2Lockup
    function wasCanceled(uint256 streamId)
        public
        view
        override(ISablierV2Lockup, SablierV2Lockup)
        notNull(streamId)
        returns (bool result)
    {
        result = _streams[streamId].wasCanceled;
    }

    /*//////////////////////////////////////////////////////////////////////////
                         USER-FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierV2LockupTranched
    function createWithMilestones(CreateWithMilestones calldata params)
        external
        override
        noDelegateCall
        returns (uint256 streamId)
    {
        // Checks, Effects and Interactions: create the stream.
        streamId = _createWithMilestones(params);
    }

    /*//////////////////////////////////////////////////////////////////////////
                           INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Calculates the streamed amount without looking up the stream's status.
    function _calculateStreamedAmount(uint256 streamId) internal view returns (uint128) {
        uint40 currentTime = uint40(block.timestamp);

        // If the start time is in the future, return zero.
        if (_streams[streamId].startTime >= currentTime) {
            return 0;
        }

        // If the end time is not in the future, return the deposited amount.
        uint40 endTime = _streams[streamId].endTime;
        if (endTime <= currentTime) {
            return _streams[streamId].amounts.deposited;
        }

        Tranche[] memory tranches = _streams[streamId].tranches;

        // Sum the amounts in all tranches that precede the current time.
        uint128 streamedAmount;
        uint40 currentTrancheMilestone = tranches[0].milestone;
        uint256 index = 0;
        while (currentTrancheMilestone < currentTime) {
            streamedAmount += tranches[index].amount;
            index += 1;
            currentTrancheMilestone = tranches[index].milestone;
        }

        return streamedAmount;
    }

    /// @inheritdoc SablierV2Lockup
    function _isCallerStreamSender(uint256 streamId) internal view override returns (bool) {
        return msg.sender == _streams[streamId].sender;
    }

    /// @inheritdoc SablierV2Lockup
    function _statusOf(uint256 streamId) internal view override returns (Lockup.Status) {
        if (_streams[streamId].isDepleted) {
            return Lockup.Status.DEPLETED;
        } else if (_streams[streamId].wasCanceled) {
            return Lockup.Status.CANCELED;
        }

        if (block.timestamp < _streams[streamId].startTime) {
            return Lockup.Status.PENDING;
        }

        if (_calculateStreamedAmount(streamId) < _streams[streamId].amounts.deposited) {
            return Lockup.Status.STREAMING;
        } else {
            return Lockup.Status.SETTLED;
        }
    }

    /// @dev See the documentation for the user-facing functions that call this internal function.
    function _streamedAmountOf(uint256 streamId) internal view returns (uint128) {
        Lockup.Amounts memory amounts = _streams[streamId].amounts;

        if (_streams[streamId].isDepleted) {
            return amounts.withdrawn;
        } else if (_streams[streamId].wasCanceled) {
            return amounts.deposited - amounts.refunded;
        }

        return _calculateStreamedAmount(streamId);
    }

    /// @dev See the documentation for the user-facing functions that call this internal function.
    function _withdrawableAmountOf(uint256 streamId) internal view override returns (uint128) {
        return _streamedAmountOf(streamId) - _streams[streamId].amounts.withdrawn;
    }

    /*//////////////////////////////////////////////////////////////////////////
                           INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev See the documentation for the user-facing functions that call this internal function.
    function _cancel(uint256 streamId) internal override {
        // Calculate the streamed amount.
        uint128 streamedAmount = _calculateStreamedAmount(streamId);

        // Retrieve the amounts from storage.
        Lockup.Amounts memory amounts = _streams[streamId].amounts;

        // Checks: the stream is not settled.
        if (streamedAmount >= amounts.deposited) {
            revert Errors.SablierV2Lockup_StreamSettled(streamId);
        }

        // Checks: the stream is cancelable.
        if (!_streams[streamId].isCancelable) {
            revert Errors.SablierV2Lockup_StreamNotCancelable(streamId);
        }

        // Calculate the sender's and the recipient's amount.
        uint128 senderAmount = amounts.deposited - streamedAmount;
        uint128 recipientAmount = streamedAmount - amounts.withdrawn;

        // Effects: mark the stream as canceled.
        _streams[streamId].wasCanceled = true;

        // Effects: make the stream not cancelable anymore, because a stream can only be canceled once.
        _streams[streamId].isCancelable = false;

        // Effects: If there are no assets left for the recipient to withdraw, mark the stream as depleted.
        if (recipientAmount == 0) {
            _streams[streamId].isDepleted = true;
        }

        // Effects: set the refunded amount.
        _streams[streamId].amounts.refunded = senderAmount;

        // Retrieve the sender and the recipient from storage.
        address sender = _streams[streamId].sender;
        address recipient = _ownerOf(streamId);

        // Retrieve the ERC-20 asset from storage.
        IERC20 asset = _streams[streamId].asset;

        // Interactions: refund the sender.
        asset.safeTransfer({ to: sender, value: senderAmount });

        // Log the cancellation.
        emit ISablierV2Lockup.CancelLockupStream(streamId, sender, recipient, asset, senderAmount, recipientAmount);

        // Emits an ERC-4906 event to trigger an update of the NFT metadata.
        emit MetadataUpdate({ _tokenId: streamId });

        // Interactions: if the recipient is a contract, try to invoke the cancel hook on the recipient without
        // reverting if the hook is not implemented, and without bubbling up any potential revert.
        if (recipient.code.length > 0) {
            try ISablierV2LockupRecipient(recipient).onStreamCanceled({
                streamId: streamId,
                sender: sender,
                senderAmount: senderAmount,
                recipientAmount: recipientAmount
            }) { } catch { }
        }
    }

    /// @dev See the documentation for the user-facing functions that call this internal function.
    function _createWithMilestones(CreateWithMilestones memory params) internal returns (uint256 streamId) {
        // Safe Interactions: query the protocol fee. This is safe because it's a known Sablier contract that does
        // not call other unknown contracts.
        UD60x18 protocolFee = comptroller.protocolFees(params.asset);

        // Checks: check the fees and calculate the fee amounts.
        Lockup.CreateAmounts memory createAmounts =
            Helpers.checkAndCalculateFees(params.totalAmount, protocolFee, params.broker.fee, MAX_FEE);

        // Checks: validate the user-provided parameters.
        checkCreateWithMilestones(createAmounts.deposit, params.tranches, MAX_TRANCHE_COUNT, params.startTime);

        // Load the stream id in a variable.
        streamId = nextStreamId;

        // Effects: create the stream.
        Stream storage stream = _streams[streamId];
        stream.amounts.deposited = createAmounts.deposit;
        stream.asset = params.asset;
        stream.isCancelable = params.cancelable;
        stream.isTransferable = params.transferable;
        stream.isStream = true;
        stream.sender = params.sender;

        unchecked {
            // The tranche count cannot be zero at this point.
            uint256 trancheCount = params.tranches.length;
            stream.endTime = params.tranches[trancheCount - 1].milestone;
            stream.startTime = params.startTime;

            // Effects: store the tranches. Since Solidity lacks a syntax for copying arrays directly from
            // memory to storage, a manual approach is necessary. See https://github.com/ethereum/solidity/issues/12783.
            for (uint256 i = 0; i < trancheCount; ++i) {
                stream.tranches.push(params.tranches[i]);
            }

            // Effects: bump the next stream id and record the protocol fee.
            // Using unchecked arithmetic because these calculations cannot realistically overflow, ever.
            nextStreamId = streamId + 1;
            protocolRevenues[params.asset] = protocolRevenues[params.asset] + createAmounts.protocolFee;
        }

        // Effects: mint the NFT to the recipient.
        _mint({ to: params.recipient, tokenId: streamId });

        // Interactions: transfer the deposit and the protocol fee.
        // Using unchecked arithmetic because the deposit and the protocol fee are bounded by the total amount.
        unchecked {
            params.asset.safeTransferFrom({
                from: msg.sender,
                to: address(this),
                value: createAmounts.deposit + createAmounts.protocolFee
            });
        }

        // Interactions: pay the broker fee, if not zero.
        if (createAmounts.brokerFee > 0) {
            params.asset.safeTransferFrom({ from: msg.sender, to: params.broker.account, value: createAmounts.brokerFee });
        }

        // Log the newly created stream.
        emit ISablierV2LockupTranched.CreateLockupTranchedStream({
            streamId: streamId,
            funder: msg.sender,
            sender: params.sender,
            recipient: params.recipient,
            amounts: createAmounts,
            asset: params.asset,
            cancelable: params.cancelable,
            transferable: params.transferable,
            tranches: params.tranches,
            broker: params.broker.account
        });
    }

    /// @dev Checks the parameters of the {SablierV2LockupTranched-_createWithMilestones} function.
    function checkCreateWithMilestones(
        uint128 depositAmount,
        Tranche[] memory tranches,
        uint256 maxTrancheCount,
        uint40 startTime
    )
        internal
        view
    {
        // Checks: the deposit amount is not zero.
        if (depositAmount == 0) {
            revert Errors.SablierV2Lockup_DepositAmountZero();
        }

        // Checks: the tranche count is not zero.
        uint256 trancheCount = tranches.length;
        if (trancheCount == 0) {
            revert SablierV2LockupTranched_TrancheCountZero();
        }

        // Checks: the tranche count is not greater than the maximum allowed.
        if (trancheCount > maxTrancheCount) {
            revert SablierV2LockupTranched_TrancheCountTooHigh(trancheCount);
        }

        // Checks: requirements of tranches variables.
        _checkTranches(tranches, depositAmount, startTime);
    }

    function _checkTranches(Tranche[] memory tranches, uint128 depositAmount, uint40 startTime) private view {
        // Checks: the start time is strictly less than the first tranche milestone.
        if (startTime >= tranches[0].milestone) {
            revert SablierV2LockupTranched_StartTimeNotLessThanFirstTrancheMilestone(startTime, tranches[0].milestone);
        }

        // Pre-declare the variables needed in the for loop.
        uint128 trancheAmountsSum;
        uint40 currentMilestone;
        uint40 previousMilestone;

        // Iterate over the tranches to:
        //
        // 1. Calculate the sum of all tranche amounts.
        // 2. Check that the milestones are ordered.
        uint256 count = tranches.length;
        for (uint256 index = 0; index < count; ++index) {
            // Add the current tranche amount to the sum.
            trancheAmountsSum += tranches[index].amount;

            // Checks: the current milestone is strictly greater than the previous milestone.
            currentMilestone = tranches[index].milestone;
            if (currentMilestone <= previousMilestone) {
                revert SablierV2LockupTranched_TrancheMilestonesNotOrdered(index, previousMilestone, currentMilestone);
            }

            // Make the current milestone the previous milestone of the next loop iteration.
            previousMilestone = currentMilestone;
        }

        // Checks: the last milestone is in the future.
        // When the loop exits, the current milestone is the last milestone, i.e. the stream's end time.
        uint40 currentTime = uint40(block.timestamp);
        if (currentTime >= currentMilestone) {
            revert Errors.SablierV2Lockup_EndTimeNotInTheFuture(currentTime, currentMilestone);
        }

        // Checks: the deposit amount is equal to the tranche amounts sum.
        if (depositAmount != trancheAmountsSum) {
            revert SablierV2LockupTranched_DepositAmountNotEqualToTrancheAmountsSum(depositAmount, trancheAmountsSum);
        }
    }

    /// @dev See the documentation for the user-facing functions that call this internal function.
    function _renounce(uint256 streamId) internal override {
        // Checks: the stream is cancelable.
        if (!_streams[streamId].isCancelable) {
            revert Errors.SablierV2Lockup_StreamNotCancelable(streamId);
        }

        // Effects: renounce the stream by making it not cancelable.
        _streams[streamId].isCancelable = false;
    }

    /// @dev See the documentation for the user-facing functions that call this internal function.
    function _withdraw(uint256 streamId, address to, uint128 amount) internal override {
        // Effects: update the withdrawn amount.
        _streams[streamId].amounts.withdrawn = _streams[streamId].amounts.withdrawn + amount;

        // Retrieve the amounts from storage.
        Lockup.Amounts memory amounts = _streams[streamId].amounts;

        // Using ">=" instead of "==" for additional safety reasons. In the event of an unforeseen increase in the
        // withdrawn amount, the stream will still be marked as depleted.
        if (amounts.withdrawn >= amounts.deposited - amounts.refunded) {
            // Effects: mark the stream as depleted.
            _streams[streamId].isDepleted = true;

            // Effects: make the stream not cancelable anymore, because a depleted stream cannot be canceled.
            _streams[streamId].isCancelable = false;
        }

        // Retrieve the ERC-20 asset from storage.
        IERC20 asset = _streams[streamId].asset;

        // Interactions: perform the ERC-20 transfer.
        asset.safeTransfer({ to: to, value: amount });

        // Log the withdrawal.
        emit ISablierV2Lockup.WithdrawFromLockupStream(streamId, to, asset, amount);
    }
}
