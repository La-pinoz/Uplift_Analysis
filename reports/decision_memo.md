# Decision memo: who should receive the SMS?

## 1. Recommendation

Rank customers by estimated uplift, the model's estimate of how much the SMS raises each customer's chance of buying. Then choose how many to contact from your cost-to-margin ratio (c/m): the cost of one SMS divided by the margin from one extra purchaser. We do not know that ratio, so the table covers three assumed values.

| c/m, Assumed | Who to contact | Net value per 100k customers, used to choose | Net value per 100k customers, held-back customers (holdout) | Note |
|---|---|---:|---:|---|
| 1% | Everyone | +2,323 (+1,857 to +2,782) | +2,324 (+1,319 to +3,274) | |
| 3% | Top 30% by estimated uplift | +862 (+580 to +1,119) | +524 (-17 to +1,049) | Close call with top 20%. Held-back customers favour top 10% |
| 5% | Top 10% by estimated uplift | +428 (+278 to +582) | +602 (+281 to +898) | Close call with top 20% |

Net value is extra purchasers minus SMS cost, counted in units of one purchaser's margin, per 100,000 customers in the base, with 95% ranges. Every row is **Assumed** (Measured extra purchasers, c/m as shown). For another ratio, use the [break-even chart](../outputs/figures/break_even_curve.png). Contact everyone below about 2.2%, the top 30% up to 3.4%, the top 20% up to 5.0%, the top 10% up to 7.0% and the top 5% up to 11.6%. Above that, contact no one.

## 2. Evidence

- The SMS raised the share of customers who purchased from 60.33% to 63.65%, a rise of 3.32 points (95% range +2.90 to +3.75), across 200,039 customers. **Measured.**
- At a 20% budget, targeting by estimated uplift produced about 1,010 more extra purchasers per 100k customers than targeting by purchase likelihood (95% range +510 to +1,467). **Measured (holdout).**
- Targeting by purchase likelihood did worse than contacting customers at random at every budget tested. At 20% it was 2.11 points lower (95% range -3.39 to -0.76). **Measured (holdout).** Likely buyers mostly buy anyway.
- Observed checks are consistent with random assignment, but randomisation is not documented. Causal claims depend on that assumption.

## 3. Measured results vs assumptions

| Item | Status |
|---|---|
| Campaign effect, strategy comparison, extra purchasers per 100k | Measured |
| Cost-to-margin ratios of 1%, 3% and 5% | Assumed, not researched |
| Net value and the recommended budget | Assumed: measured extra purchasers combined with an assumed ratio |
| Each customer's estimated uplift | Estimated from the model, used only to rank customers |

## 4. Limitations

- **Assignment:** randomisation is not documented, as stated above.
- **Outcome:** whether a customer purchased in an undocumented period after the SMS, not revenue or margin.
- **Not measured:** opt-outs, message fatigue and long-term effects.
- **Population:** this labelled customer group only.
- **Ranges:** they cover sampling noise in the evaluation, not retraining the model.
- **Costs:** the three ratios are assumptions.

## 5. Next step

Run a randomised test of "top K% by estimated uplift" against contacting everyone or random targeting, at the K your cost-to-margin ratio points to, with revenue tracked and a documented outcome window.

Method: [notebooks](../notebooks/) and the [decisions log](decisions.md).
