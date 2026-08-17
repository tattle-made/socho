# Implicit Association Test (IAT)

The IAT measures the strength of automatic associations between concepts — for example, between a social group and a positive or negative attribute. It does this by measuring how quickly people respond when two concepts share the same key, compared to when they are on opposite keys.

## Block Structure

A standard 7-block IAT runs participants through the following sequence:

| Block | Type | Description |
|---|---|---|
| 1 | Practice | Category sorting only (e.g. Branded Food / Organic Food) |
| 2 | Practice | Attribute sorting only (e.g. Pleasant / Unpleasant) |
| 3 | Combined Practice | Category + Attribute paired together (compatible mapping) |
| 4 | Combined Test | Same pairing, more trials, faster pace |
| 5 | Practice | Category sorting with sides reversed |
| 6 | Combined Practice | Category + Attribute with reversed mapping |
| 7 | Combined Test | Same reversed pairing, more trials, faster pace |

Socho randomises whether a participant sees the compatible or incompatible pairing first (counterbalancing), so half of participants get blocks 3–4 before blocks 6–7, and half get the reverse order.

## Scoring: The D-Score

The IAT does not report raw response times. Instead, it computes a **D-score** — a standardised difference score that tells you how much faster (or slower) someone responded in one combined condition versus the other.

### The pseudo code based on paper and the R implementation
Input: trial latencies and correctness for Blocks 3, 4, 6, 7

1. Remove any trial with latency > 10,000 ms.
2. If using the recommended variant, remove any trial with latency < 400 ms.
3. For each block, compute:
   - mean latency of correct responses
   - standard deviation of correct-response latencies
4. Replace each error latency with:
   - block mean(correct latencies) + 600 ms
   OR
   - block mean(correct latencies) + 2 * block SD(correct latencies)
   OR, in the Web IAT procedure, just keep the error latency because it already includes a built-in penalty.
5. For each block, average the resulting latencies.
6. Compute:
   - difference1 = mean(Block 6) - mean(Block 3)
   - difference2 = mean(Block 7) - mean(Block 4)
7. Divide each difference by its associated pooled SD:
   - quotient1 = difference1 / SDpooled(Blocks 3 and 6)
   - quotient2 = difference2 / SDpooled(Blocks 4 and 7)
8. D score = average(quotient1, quotient2)

After consultation with Hansika, step 4 has been left out of the implementation.

### The Formula used

The D-score is computed as the average of two intermediate scores — one from the practice combined blocks, one from the test combined blocks:

```
sd1    = SD of all trials in combined1_practice + combined2_practice
sd2    = SD of all trials in combined1_test + combined2_test

D1     = (mean_RT_combined2_practice - mean_RT_combined1_practice) / sd1
D2     = (mean_RT_combined2_test     - mean_RT_combined1_test)     / sd2

D      = (D1 + D2) / 2
```

- **combined1** refers to the block where Category 1 and Attribute 1 share a key
- **combined2** refers to the block where Category 2 and Attribute 1 share a key
- **sd1** is pooled across both practice combined blocks; **sd2** is pooled across both test combined blocks
- Pairing practice-with-practice and test-with-test for the SD (rather than pooling everything together) is what distinguishes the Greenwald 2003 D-score from simpler difference-score approaches

### Which Trials Are Included

Socho follows the **D3 algorithm** from Greenwald, Nosek & Banaji (2003):

- **Both practice and test combined blocks are included** (blocks 3, 4, 6, and 7). Including the practice combined blocks gives a larger sample and is the standard approach. Only the single-category practice blocks (1, 2, 5) are excluded, since those blocks do not involve the combined categorisation task.
- **Both correct and incorrect trials are included**. Error trials are not thrown away — their actual response time is used as-is. This reflects that a slow error still carries information about how hard the pairing felt.
- **Trials with RT < 400 ms are excluded**. Responses faster than 400 milliseconds are too fast to be genuine categorisations and are treated as noise.
- **Trials with RT > 10,000 ms are excluded**. Very long response times usually mean the participant was distracted.

### Interpreting the D-Score

A **positive D-score** means the participant was faster when Category 1 and Attribute 1 shared a key — suggesting a stronger automatic association between them.

A **negative D-score** means the participant was faster in the other pairing — suggesting a stronger association between Category 2 and Attribute 1.

A score near zero suggests no strong automatic preference in either direction.

General benchmarks (Greenwald et al. 2003):

| D-score | Interpretation |
|---|---|
| < 0.15 | Little to no association |
| 0.15 – 0.35 | Slight association |
| 0.35 – 0.65 | Moderate association |
| > 0.65 | Strong association |

### Reference

Greenwald, A. G., Nosek, B. A., & Banaji, M. R. (2003). Understanding and using the Implicit Association Test: I. An improved scoring algorithm. *Journal of Personality and Social Psychology, 85*(2), 197–216.


## Debugging IAT Data produced by Socho
If you run an IAT test in preview mode (?preview=true) at the last screen you will see your D score and a json file will be downloaded. This script can be used to explore the IAT data in more details.

We have 2 scripts for it - elixir and javascript. These can be invoked from the root folder as `elixir scripts/iat_score.exs scripts/files/iat_debug.json` or `node scripts/iat_score.js scripts/files/iat_6.json`