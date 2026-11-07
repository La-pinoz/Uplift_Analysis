# Data Understanding: X5 RetailHero

Research notes on the raw dataset, gathered on 2026-11-07 before Phase 1 implementation.

## How to read these notes

Each finding is labelled by where it comes from:

- **Measured:** calculated directly from the raw files.
- **Documented:** stated in competition or library documentation.
- **Inferred:** a reasonable reading of the evidence, not an established fact.

These numbers come from one-off exploratory queries, not the project pipeline. Phase 1 still needs to reproduce them from `sql/` and `notebooks/`.

The queries used `treatment_flg` but never `target`, so no response rate or treatment effect has been measured.

## Summary

- Row counts, keys and joins are clean, and the treatment split is close to 50/50.
- `purchases.csv` ends on 2019-03-18. A sharp rise in first redemptions among treated customers starts around 2019-03-21, which suggests the campaign started about then.
- `first_redeem_date` runs to 2019-11-20, so it contains information from after the campaign.
- `transaction_id` is not unique on its own. The transaction key is `(client_id, transaction_id)`.
- The product-level amount fields do not add up to `purchase_sum`.
- Every labelled customer has a purchase on or after 2019-02-24. This may reflect an eligibility rule, but none is documented.
- The sources checked do not document randomisation, the campaign date or the outcome window.

## Files

| File | Size (bytes) | Contents | Rows (measured) |
|---|---:|---|---:|
| `clients.csv` | 21,736,219 | `client_id`, `first_issue_date`, `first_redeem_date`, `age`, `gender` | 400,162 |
| `purchases.csv` | 4,463,775,504 | One row per product in a transaction, with transaction and points fields | 45,786,568 |
| `products.csv` | 3,890,339 | Category levels, segment, brand, vendor, `netto`, own-brand and alcohol flags | Not counted |
| `uplift_train.csv` | 3,000,616 | `client_id`, `treatment_flg`, `target` | 200,039 |
| `uplift_test.csv` | 2,201,363 | `client_id` | 200,123 |
| `uplift_sample_submission.csv` | 6,057,851 | `client_id`, `uplift` | Not counted |
| `check_queries.tsv` | 842,576 | JSON query records with a customer's history and next purchase | 101 |

`purchases.csv` columns: `client_id`, `transaction_id`, `transaction_datetime`, `regular_points_received`, `express_points_received`, `regular_points_spent`, `express_points_spent`, `purchase_sum`, `store_id`, `product_id`, `product_quantity`, `trn_sum_from_iss`, `trn_sum_from_red`.

### `check_queries.tsv`

- It has 101 rows, and all 101 customers are in `uplift_train.csv`.
- Query times run from 2019-03-01 05:59:27 to 2019-03-16 16:13:08.
- The "next purchase" dates run from 2019-03-02 10:05:38 to 2019-03-18 12:48:40, so they fall inside the purchase history.
- The ODS.ai data page does not list this file.

## Keys and joins (measured)

| Check | Result |
|---|---|
| `clients.csv` unique `client_id` | 400,162 of 400,162 |
| `uplift_train.csv` unique `client_id` | 200,039 of 200,039 |
| Train and test overlap | 0 |
| Train plus test | 400,162, equal to the client count |
| Train customers missing from `clients.csv` | 0 |
| Train customers with no purchase rows | 0 |
| Clients appearing in `purchases.csv` | 400,162 |
| Null `client_id` or `transaction_id` in purchases | 0 |

## Date ranges (measured)

| Field | Earliest | Latest |
|---|---|---|
| `first_issue_date` | 2017-04-04 18:24:18 | 2019-03-15 21:50:56 |
| `first_redeem_date` | 2017-04-11 09:42:20 | 2019-11-20 01:14:10 |
| `transaction_datetime` | 2018-11-21 | 2019-03-18 |

## Customer fields (measured)

Across all 400,162 clients:

| Check | Result |
|---|---|
| `age` range | -7491 to 1901 |
| `age` outside 14-100 | 1,779 |
| Null `first_redeem_date` | 35,469 |
| `first_redeem_date` before `first_issue_date` | 536 |
| Gender `U` | 185,706 |
| Gender `F` | 147,649 |
| Gender `M` | 66,807 |

## Transactions and amounts (measured)

### Transaction key

| Check | Result |
|---|---|
| Distinct `transaction_id` | 8,045,201 |
| Distinct `(client_id, transaction_id)` | 8,045,229 |
| `transaction_id` values shared by more than one client | 28 |
| Multi-row transactions, by `transaction_id` | 6,977,737 |
| Composite keys with more than one `purchase_sum` | 0 |
| Composite keys with more than one timestamp | 0 |
| A product repeated within a composite key | 0 |

`purchase_sum` repeats across the product rows of a transaction, so summing raw rows would double count spend. It holds a single value per composite key.

### Invalid and unusual values

| Check | Result |
|---|---|
| Negative `purchase_sum` | 0 rows |
| Null `purchase_sum` | 0 rows |
| Transactions with `purchase_sum` of 0 | 567 |
| Rows with `product_quantity` of 0 or less | 2,707,278 |
| Transactions with a negative quantity | 0 |
| Transactions with a zero quantity | 1,829,319 |
| Null `trn_sum_from_iss` | 0 rows |
| Null `trn_sum_from_red` | 42,743,212 rows |

The reason for zero quantities is not documented.

### Reconciling `purchase_sum` with product-level amounts

Totals are in the dataset's own units. No currency was confirmed.

| `trn_sum_from_red` present | Points spent | Transactions | Within 1 unit: `iss + red` | Within 1 unit: `iss` only | Median gap | Mean gap | Total `purchase_sum` | Total `iss` | Total `red` |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| No | No | 7,538,988 | 57.20% | 57.20% | -0.14 | 6.00 | 3,208,352,308 | 3,163,100,727 | 0 |
| No | Yes | 5 | 0.00% | 0.00% | 30.00 | 29.80 | 1,193 | 1,044 | 0 |
| Yes | No | 1,644 | 0.06% | 53.47% | -192.50 | -321.60 | 542,982 | 535,324 | 536,361 |
| Yes | Yes | 504,592 | 2.15% | 1.30% | -228.01 | -393.90 | 235,497,358 | 201,142,353 | 233,114,475 |

The gap is `purchase_sum - (iss + red)`.

- Without redemptions, total `iss` is about 1.4% below total `purchase_sum`.
- With redemptions, `iss + red` totals about 434M against about 235M of `purchase_sum`. The two amount fields are therefore not additive in those transactions.
- `trn_sum_from_red` totals close to `purchase_sum` in the main redemption group. What each field means is not documented.

## Treatment groups (measured)

| Group | Customers | Share |
|---|---:|---:|
| Treated | 99,981 | 49.98% |
| Control | 100,058 | 50.02% |

A test against an expected 50/50 split gives z of about 0.17 and p of about 0.86.

### Early comparisons

These are exploratory and do not replace the Phase 1 balance table. The standardised mean differences (SMD) are approximate.

| Measure | Treated | Control | Approx. SMD |
|---|---:|---:|---:|
| Mean transactions per customer | 20.19 | 20.06 | Not calculated |
| Median transactions per customer | 15 | 15 | Not calculated |
| Mean days since last purchase | 5.83 | 5.83 | Not calculated |
| Transactions before `first_issue_date` | 11.55% | 11.97% | 0.013 |
| Issued on or after 2019-02-18 | 2.03% | 2.17% | 0.010 |
| First purchase before 2018-12-01 | 56.14% | 55.78% | Not calculated |
| First purchase on or after 2019-03-01 | 2.88% | 3.04% | Not calculated |

Recent card issues by month:

| Month | Treated | Control |
|---|---:|---:|
| 2018-11 | 3,441 | 3,401 |
| 2018-12 | 4,093 | 4,197 |
| 2019-01 | 2,768 | 2,888 |
| 2019-02 | 2,626 | 2,716 |
| 2019-03 | 1,049 | 1,138 |

## Campaign timing

### `first_redeem_date`

| Group | Customers | Null share | Share of non-null dates after 2019-03-18 | Latest date |
|---|---:|---:|---:|---|
| Treated | 99,981 | 8.44% | 12.55% | 2019-11-20 01:14:10 |
| Control | 100,058 | 9.10% | 12.22% | 2019-11-19 21:25:41 |

Monthly first redemptions:

| Month | Treated | Control |
|---|---:|---:|
| 2019-01 | 3,904 | 3,858 |
| 2019-02 | 4,594 | 4,666 |
| 2019-03 | 6,807 | 4,876 |
| 2019-04 | 2,107 | 2,687 |
| 2019-05 | 1,618 | 1,983 |
| 2019-06 | 1,260 | 1,533 |
| 2019-07 | 1,095 | 1,273 |
| 2019-08 | 600 | 678 |
| 2019-09 | 530 | 629 |
| 2019-10 | 486 | 580 |
| 2019-11 | 290 | 340 |

Daily first redemptions around the rise:

| Date | Treated | Control |
|---|---:|---:|
| 2019-03-15 | 186 | 171 |
| 2019-03-16 | 127 | 142 |
| 2019-03-17 | 97 | 117 |
| 2019-03-18 | 89 | 96 |
| 2019-03-19 | 105 | 100 |
| 2019-03-20 | 88 | 98 |
| 2019-03-21 | 295 | 89 |
| 2019-03-22 | 991 | 103 |
| 2019-03-23 | 761 | 97 |
| 2019-03-24 | 414 | 82 |
| 2019-03-25 | 119 | 79 |
| 2019-03-26 | 136 | 93 |
| 2019-03-27 | 115 | 106 |
| 2019-03-28 | 117 | 109 |

From 2019-03-01 to 2019-03-20, the two groups show no comparable gap on any day. After the spike, control counts are higher on most days from 2019-03-29.

**Inferred:** the campaign started around 2019-03-21, about three days after the purchase history ends. No source checked gives the date.

The date also behaves differently from purchase-based redemption:

- Among train customers whose `first_redeem_date` falls inside the purchase history (36,484), the exact-match rate with the timestamp of their first points-spending transaction rounds to 0.00% in both groups.
- About 0.4% of those customers have no points spending in the history.
- No train customer with a null `first_redeem_date` has points spending in the history.

### Daily transactions near the end of the history

This table covers train customers. The ratio is treated divided by control.

| Date | Treated | Control | Ratio |
|---|---:|---:|---:|
| 2019-02-11 | 19,159 | 19,096 | 1.0033 |
| 2019-02-12 | 18,619 | 18,508 | 1.0060 |
| 2019-02-13 | 18,745 | 18,335 | 1.0224 |
| 2019-02-14 | 19,251 | 19,253 | 0.9999 |
| 2019-02-15 | 20,353 | 20,134 | 1.0109 |
| 2019-02-16 | 19,315 | 19,039 | 1.0145 |
| 2019-02-17 | 17,539 | 17,296 | 1.0140 |
| 2019-02-18 | 19,578 | 19,354 | 1.0116 |
| 2019-02-19 | 19,015 | 18,904 | 1.0059 |
| 2019-02-20 | 19,215 | 19,234 | 0.9990 |
| 2019-02-21 | 19,697 | 19,958 | 0.9869 |
| 2019-02-22 | 21,398 | 21,137 | 1.0123 |
| 2019-02-23 | 19,456 | 19,079 | 1.0198 |
| 2019-02-24 | 16,449 | 16,272 | 1.0109 |
| 2019-02-25 | 21,641 | 21,401 | 1.0112 |
| 2019-02-26 | 20,001 | 19,612 | 1.0198 |
| 2019-02-27 | 22,372 | 22,276 | 1.0043 |
| 2019-02-28 | 21,260 | 21,416 | 0.9927 |
| 2019-03-01 | 22,517 | 22,255 | 1.0118 |
| 2019-03-02 | 21,660 | 21,255 | 1.0191 |
| 2019-03-03 | 19,516 | 19,394 | 1.0063 |
| 2019-03-04 | 21,572 | 21,810 | 0.9891 |
| 2019-03-05 | 21,560 | 21,449 | 1.0052 |
| 2019-03-06 | 21,558 | 21,575 | 0.9992 |
| 2019-03-07 | 25,428 | 25,753 | 0.9874 |
| 2019-03-08 | 22,341 | 22,703 | 0.9841 |
| 2019-03-09 | 19,881 | 19,630 | 1.0128 |
| 2019-03-10 | 18,997 | 18,997 | 1.0000 |
| 2019-03-11 | 22,096 | 22,508 | 0.9817 |
| 2019-03-12 | 18,962 | 18,969 | 0.9996 |
| 2019-03-13 | 18,920 | 18,792 | 1.0068 |
| 2019-03-14 | 21,156 | 20,972 | 1.0088 |
| 2019-03-15 | 22,099 | 22,392 | 0.9869 |
| 2019-03-16 | 19,075 | 19,018 | 1.0030 |
| 2019-03-17 | 17,233 | 17,305 | 0.9958 |
| 2019-03-18 | 20,286 | 19,975 | 1.0156 |

No formal divergence test has been run. Across these 36 days the ratio stays between 0.9817 and 1.0224, with no clear break at the end.

## Purchase activity boundary (measured)

Each customer's most recent purchase:

| Measure | Treated | Control |
|---|---:|---:|
| Customers | 99,981 | 100,058 |
| Earliest last purchase | 2019-02-25 00:02:04 | 2019-02-24 21:27:32 |
| Latest last purchase | 2019-03-18 23:19:28 | 2019-03-18 22:59:56 |
| Last purchase before 2019-02-18 | 0 | 0 |
| Last purchase before 2019-03-01 | 5,524 | 5,569 |
| Last purchase before 2019-03-11 | 32,377 | 32,393 |

Train customers by the week of their last purchase:

| Week starting | Customers |
|---|---:|
| 2019-02-18 | 1 |
| 2019-02-25 | 22,412 |
| 2019-03-04 | 42,357 |
| 2019-03-11 | 99,996 |
| 2019-03-18 | 35,273 |

Only one train customer's last purchase falls in the week of 2019-02-18, and it is late on 2019-02-24. The next week has 22,412 customers.

**Inferred:** the labelled customers may have been limited to those with a recent purchase. No source documents such a rule.

First purchases in the data run from 2018-11-21 to 2019-03-15.

## Pre-campaign purchase comparison (exploratory)

This tests the plan's original placebo window, using any purchase from 2019-02-18 up to but not including 2019-03-04.

| Group | Customers | Rate |
|---|---:|---:|
| Treated | 99,981 | 83.54% |
| Control | 100,058 | 83.34% |

The difference is +0.20 points, with an approximate 95% interval of -0.13 to +0.52 points.

This window overlaps the activity boundary above. Because every train customer has a purchase on or after 2019-02-24, a customer with no purchase in the window must have purchased after it. An alternative window ending on 2019-02-23 has not been measured.

## Express points (exploratory)

Counted once per transaction on train customers. "Last 35 days" means from 35 days before the latest transaction.

| Period | Group | Transactions | Express points received | Express points spent |
|---|---|---:|---:|---:|
| Earlier | Treated | 1,309,415 | 0.140% | 1.070% |
| Earlier | Control | 1,300,813 | 0.136% | 1.091% |
| Last 35 days | Treated | 708,761 | 0.009% | 1.232% |
| Last 35 days | Control | 705,960 | 0.008% | 1.223% |

The groups look similar. Express points received fall sharply in the last 35 days in both groups, and the reason is unknown. The field's meaning and any link to earlier campaigns are also undocumented.

## Documentation review

The search is closed. The ODS.ai and scikit-uplift text below came from web fetches that return a summary of the page, so check the exact wording on the source page before quoting it.

| Source | What it establishes | What it does not establish |
|---|---|---|
| [ODS.ai competition page](https://ods.ai/competitions/x5-retailhero-uplift-modeling) | The communication is an SMS: "Predict how much the purchase probability could increase as a result of sending an advertising SMS." Competition dates shown are December 17, 2019 to February 22, 2020. | Random assignment, control group design, campaign date, outcome window |
| [ODS.ai data page](https://ods.ai/competitions/x5-retailhero-uplift-modeling/data) | `purchases.csv` is "clients' purchase history prior to communication". `treatment_flg` "indicates if there was a communication". `target` "shows if there was a purchase afterward". | Random assignment, send date, outcome window |
| [scikit-uplift `fetch_x5` docs](https://www.uplift-modeling.com/en/latest/api/datasets/fetch_x5.html) | Source is X5 Retail Group at the RetailHero hackathon in winter 2019. Treatment ratio .5 and response ratio .62. Row counts match the measured values. | Random assignment, campaign date, outcome window |
| Web searches | A search summary said the mailing was randomised, but it could not be traced to organiser material, so it does not count as evidence. Other people's repositories also appeared; their results were not used. | Any organiser statement on assignment |

**Not checked:** the 596 MB organiser archive `retailhero-uplift.zip`, which the data page describes as containing the data and a baseline solution.

## Status of the plan's claims

| Claim in `PROJECT_PLAN.md` | Status | Evidence |
|---|---|---|
| Row counts | Confirmed | 400,162 clients, 45,786,568 purchase rows, 200,039 train customers |
| Treatment ratio of about 50% | Confirmed | 49.98% treated |
| Response rate of about 62% | Documented, not measured | scikit-uplift lists .62; `target` was not queried |
| `first_redeem_date` extends to about November 2019 | Confirmed | Latest is 2019-11-20 |
| `first_issue_date` ends in about March 2019 | Confirmed | Latest is 2019-03-15 |
| `purchase_sum` repeats across product rows | Confirmed | Single value per composite key across multi-row transactions |
| Purchase history ends before the campaign | Documented and supported, campaign date inferred | ODS.ai wording, history ends 2019-03-18, redemption rise starts 2019-03-21 |
| How and when the outcome window was defined | Not documented | `target` is only described as a purchase afterward |
| How treatment was assigned | Not documented | No organiser source found |
| Age contains invalid values | Confirmed | 1,779 outside 14-100, range -7491 to 1901 |

## Questions the data cannot answer

- Was treatment randomly assigned?
- Does `treatment_flg` record assignment or successful delivery?
- What was the exact campaign date?
- When does the outcome window start and end? It cannot be recomputed because purchases stop on 2019-03-18.
- Was there a formal eligibility rule behind the activity boundary?
- What do `trn_sum_from_iss`, `trn_sum_from_red`, zero quantities and express points represent exactly?

## Not yet measured

- Purchase rates by group and any treatment effect
- The full balance table
- The placebo window ending 2019-02-23
- The seven-day cutoff sensitivity check
- A formal test of express points by group
- A detailed profile of `products.csv`
