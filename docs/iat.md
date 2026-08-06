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

### The Formula

```
D = (mean_RT_condition2 - mean_RT_condition1) / pooled_SD
```

- **mean_RT_condition1**: average response time across all trials where Category 1 and Attribute 1 shared a key
- **mean_RT_condition2**: average response time across all trials where Category 2 and Attribute 1 shared a key
- **pooled_SD**: standard deviation computed across all trials from both conditions combined

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
