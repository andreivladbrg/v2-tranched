## About

A POC for `SablierV2LockupTranched` contract and a benchmark.

See [here](https://github.com/sablier-labs/v2-core/issues/787) for more details.

## Problem

The problem with `SablierV2LockupDynamic` is that it needs to have two segments for one unlock, see how is the unlock in
steps curve [from docs](https://docs.sablier.com/concepts/protocol/stream-types#unlock-in-steps) is implemented
[here](https://github.com/sablier-labs/examples/blob/b66f5c816b2573fe2325a9e62d4b25c3ce84787b/v2/core/LockupDynamicCurvesCreator.sol#L82-L123).

For `SablierV2LockupTranched`, the above example, it would be implemented like this:

```solidity
    uint256 trancheSize = 10;
    tranches = new Tranche[](trancheSize);

    uint128 unlockAmount = totalAmount / trancheSize;
    uint40 stepDuration = 10 days;

    for (uint256 i = 0; i < trancheSize; ++i) {
        tranches[i] = Tranche({ amount: unlockAmount, milestone: uint40(block.timestamp) + stepDuration });
        stepDuration += 10 days;
    }
```

**Note** that the tranche size in this case is half, leading to fewer storage variables and less arrays traversed when
calculating the withdrawable amount.

## Benchmark

For the benchmarks, I have considered the following number of unlocks: _2, 4, 6, 12, 24, 36, 48, 60_. These numbers are
intended to reflect real-world scenarios (can be viewed as months).

If we were to compare the gas for the same length of segments/tranches, the difference would not be significant.
However, as mentioned above, `LockupTranched` uses half the number of tranches for the same number of unlocks compared
to `LockupDynamic, so it is indeed more efficient.

### Gas Improvements Per Unlock

| Number of Unlocks | Improvement in createWithMilestone | Improvement in withdraw |
| ----------------- | ---------------------------------- | ----------------------- |
| 2                 | 51,247                             | 14,508                  |
| 4                 | 101,482                            | 15,453                  |
| 6                 | 151,725                            | 16,400                  |
| 12                | 302,502                            | 19,242                  |
| 24                | 604,561                            | 24,950                  |
| 36                | 907,599                            | 30,689                  |
| 48                | 1,210,982                          | 36,460                  |
| 60                | 1,515,272                          | 42,261                  |

### Gas Improvements Per Segments/Tranches

| Number of Segments/Tranches | Improvement in createWithMilestone | Improvement in withdraw |
| --------------------------- | ---------------------------------- | ----------------------- |
| 2                           | 2,122                              | 13,367                  |
| 4                           | 3,211                              | 13,169                  |
| 6                           | 4,302                              | 12,973                  |
| 12                          | 7,604                              | 12,382                  |
| 24                          | 14,221                             | 11,204                  |
| 36                          | 20,924                             | 10,028                  |
| 48                          | 27,736                             | 8,858                   |
| 60                          | 34,686                             | 7,691                   |

#### Full Tables

You can also run this command to generate the benchmark:

```bash
forge test -vv
```

| LockupDynamic: createWithMilestone |           | LockupTranched: createWithMilestone |           |
| ---------------------------------- | --------- | ----------------------------------- | --------- |
| Segments Length                    | Gas       | Tranches Length                     | Gas       |
| 2                                  | 182,675   | 2                                   | 180,553   |
| 4                                  | 231,800   | 4                                   | 228,589   |
| 6                                  | 280,932   | 6                                   | 276,630   |
| 8                                  | 330,071   |                                     |           |
| 12                                 | 428,355   | 12                                  | 420,751   |
| 24                                 | 723,253   | 24                                  | 709,032   |
| 36                                 | 1,018,316 | 36                                  | 997,392   |
| 48                                 | 1,313,593 | 48                                  | 1,285,857 |
| 60                                 | 1,609,134 | 60                                  | 1,574,448 |
| 72                                 | 1,904,991 |                                     |           |
| 96                                 | 2,496,839 |                                     |           |
| 120                                | 3,089,720 |                                     |           |

**Note:** the withdrawable amount was calculated for the last segment/tranche.

| LockupDynamic: withdraw |        | LockupTranched: withdraw |        |
| ----------------------- | ------ | ------------------------ | ------ |
| Segments Length         | Gas    | Tranches Length          | Gas    |
| 2                       | 27,669 | 2                        | 14,302 |
| 4                       | 28,810 | 4                        | 15,641 |
| 6                       | 29,952 | 6                        | 16,979 |
| 8                       | 31,094 |                          |        |
| 12                      | 33,379 | 12                       | 20,997 |
| 24                      | 40,239 | 24                       | 29,035 |
| 36                      | 47,107 | 36                       | 37,079 |
| 48                      | 53,985 | 48                       | 45,127 |
| 60                      | 60,872 | 60                       | 53,181 |
| 72                      | 67,768 |                          |        |
| 96                      | 81,587 |                          |        |
| 120                     | 95,442 |                          |        |
