# Customer Feature Dictionary

One row per labelled customer (200,039), with `client_id` and 39 features. No customer is dropped. The files hold no treatment, outcome or split columns.

| File | Cutoff (exclusive) | History used | Use |
|---|---|---|---|
| `data/processed/customer_features.parquet` | **Primary:** `transaction_datetime < 2019-03-19 00:00` | 118 calendar days, from 2018-11-21 to 2019-03-18 | Modelling and checks |
| `data/processed/customer_features_sensitivity.parquet` | **Sensitivity:** `transaction_datetime < 2019-03-12 00:00` | 111 calendar days, from 2018-11-21 to 2019-03-11 | Balance and treatment-prediction checks only, never training |

## Rules for every feature

- **Windows:** a window of N days covers `[cutoff - N days, cutoff)`.
- **Day counts:** complete 24-hour days before the cutoff. A purchase 14 hours before the cutoff counts as 0.
- **Transactions:** one per `(client_id, transaction_id)`, because 28 `transaction_id` values are shared by two clients.
- **Transaction-level fields:** `purchase_sum` and all four points fields repeat across a transaction's product rows, so one value per transaction is used. The notebook asserts that they are constant within a transaction.
- **Money:** `purchase_sum` is the only monetary measure.
- **Missing values:** undefined stays null, with no imputation, caps or logs in the table.

## Limits named in the table

- **History limit:** the data starts on 2018-11-21, so `_hist` means the available history: 118 days at the primary cutoff and 111 at the sensitivity cutoff. These are not lifetime values. For 50.4% of customers the first recorded purchase falls in about the first eight days of the data.
- **Activity pattern:** every labelled customer has a purchase on or after 2019-02-24. At the primary cutoff, `days_since_last_purchase` therefore cannot exceed 22, and the 30-, 60- and 90-day transaction counts and spend can never be zero. The pattern falls after the sensitivity cutoff, where the longest recency is 109 days, so differences between the two tables are partly mechanical.
- **Upward bias:** every labelled customer has a purchase on or after 2019-02-24, which falls in the last 30 days at the primary cutoff, while the previous 30 days can be empty. A positive trend therefore does not by itself mean a customer's activity grew.
- **Clock caveat:** recorded hours peak at 09:00 and 14:00, with 0.16% of transactions from 20:00 to 23:59. The clock may be shifted and no documentation settles it, so hour bands are not local times of day. Hours from 20:00 to 04:59 (0.6% of transactions) are the implied remainder.

## Features

**Status:** "Core" features have no open question. "Cleared in Phase 1; inclusion set by the treatment-check rule" features passed the Phase 1 points checks, and whether they enter the Phase 3 model is decided only by the inclusion rule in `reports/decisions.md`. The result is recorded in that log, and this label does not change.

| Feature | Group | Definition | If undefined or empty | Limit | Status |
|---|---|---|---|---|---|
| `days_since_last_purchase` | Recency | Days from the last transaction to the cutoff | Null | Activity pattern | Core |
| `days_since_first_observed_purchase` | Recency | Days from the first recorded transaction to the cutoff. Not customer age | Null | History limit | Core |
| `txn_count_hist` | Frequency | Transactions in the history | 0 | History limit | Core |
| `txn_count_7d` | Frequency | Transactions in the last 7 days | 0 | None | Core |
| `txn_count_14d` | Frequency | Transactions in the last 14 days | 0 | None | Core |
| `txn_count_30d` | Frequency | Transactions in the last 30 days | 0 | Activity pattern | Core |
| `txn_count_60d` | Frequency | Transactions in the last 60 days | 0 | Activity pattern | Core |
| `txn_count_90d` | Frequency | Transactions in the last 90 days | 0 | Activity pattern | Core |
| `active_days_hist` | Frequency | Distinct purchase dates | 0 | History limit | Core |
| `avg_gap_days` | Frequency | `(last active date - first active date) / (active_days_hist - 1)`, using calendar dates | Null if under 2 active days | History limit | Core |
| `spend_hist` | Monetary | Sum of `purchase_sum` | 0 | History limit | Core |
| `spend_30d` | Monetary | Sum of `purchase_sum` in the last 30 days | 0 | Activity pattern | Core |
| `spend_60d` | Monetary | Sum of `purchase_sum` in the last 60 days | 0 | Activity pattern | Core |
| `spend_90d` | Monetary | Sum of `purchase_sum` in the last 90 days | 0 | Activity pattern | Core |
| `avg_basket_value` | Monetary | Mean `purchase_sum` per transaction, including zero-sum transactions | Null | History limit | Core |
| `max_basket_value` | Monetary | Largest `purchase_sum` | Null | History limit | Core |
| `std_basket_value` | Monetary | Sample standard deviation of `purchase_sum` | Null if under 2 transactions | History limit | Core |
| `txn_trend_30d` | Trend | `ln((transactions in last 30 days + 1) / (transactions in the 30 days before that + 1))` | 0 if both periods are empty | Upward bias | Core |
| `spend_trend_30d` | Trend | `ln((spend in last 30 days + 1) / (spend in the 30 days before that + 1))` | 0 if both periods are empty | Upward bias | Core |
| `avg_lines_per_basket` | Basket | Mean product rows per transaction, including zero-quantity rows. A product never repeats within a transaction, so this also equals unique products per basket | Null | History limit | Core |
| `distinct_products_hist` | Basket | Distinct `product_id` values | 0 | History limit | Core |
| `distinct_stores_hist` | Basket | Distinct `store_id` values | 0 | History limit | Core |
| `weekend_txn_share` | Timing | Share of transactions on a recorded Saturday or Sunday | Null | History limit, clock caveat | Core |
| `txn_share_05_09` | Timing | Share of transactions with a recorded hour from 05:00 to 09:59 | Null | History limit, clock caveat | Core |
| `txn_share_10_13` | Timing | Share of transactions with a recorded hour from 10:00 to 13:59 | Null | History limit, clock caveat | Core |
| `txn_share_14_19` | Timing | Share of transactions with a recorded hour from 14:00 to 19:59 | Null | History limit, clock caveat | Core |
| `regular_points_received_hist` | Loyalty | Sum of `regular_points_received`, one value per transaction | 0 | History limit | Core |
| `regular_points_spent_hist` | Loyalty | Sum of `regular_points_spent`, one value per transaction, shown as positive | 0 | History limit | Core |
| `express_points_received_hist` | Loyalty | Sum of `express_points_received`, one value per transaction | 0 | History limit | Cleared in Phase 1; inclusion set by the treatment-check rule |
| `express_points_spent_hist` | Loyalty | Sum of `express_points_spent`, one value per transaction, shown as positive | 0 | History limit | Cleared in Phase 1; inclusion set by the treatment-check rule |
| `regular_points_spent_30d` | Loyalty | Sum of `regular_points_spent` in the last 30 days, shown as positive | 0 | None | Core |
| `express_points_spent_30d` | Loyalty | Sum of `express_points_spent` in the last 30 days, shown as positive | 0 | None | Cleared in Phase 1; inclusion set by the treatment-check rule |
| `age` | Client | Age, when from 14 to 100 inclusive. Same rule as Phase 1 | Null if invalid | None | Core |
| `age_invalid_flg` | Client | 1 if age is outside 14 to 100. Same rule as Phase 1 | Never null | None | Core |
| `gender_f` | Client | 1 if recorded gender is F | Never null | None | Core |
| `gender_m` | Client | 1 if recorded gender is M | Never null | None | Core |
| `gender_u` | Client | 1 if recorded gender is U | Never null | None | Core |
| `days_since_first_issue` | Client | Days from `first_issue_date` to the cutoff | Null if the card was issued on or after the cutoff | None | Core |
| `pre_issue_purchase_flg` | Client | 1 if the first transaction before the cutoff has an earlier timestamp than `first_issue_date` | 0 if no transactions | See below | Core |

## How `pre_issue_purchase_flg` works

The flag compares **timestamps, not dates**:

| First transaction | Flag |
|---|---|
| On an earlier date than card issue | 1 |
| On the issue date, before the issue time | 1 |
| On the issue date, at or after the issue time | 0 |
| After the issue date | 0 |

**Read it with care:** 23,515 of the 23,532 customers flagged at the primary cutoff bought on the issue date itself, and only 17 bought on an earlier date. Just 5 customers have a same-day first purchase at or after the issue time. So the flag mostly marks a first purchase recorded shortly before the issue time on the same day, not shopping long before the card existed. The likely reason, a card recorded as issued after the sale that created it, is an inference.

## How the sensitivity table differs

All windows are measured from the sensitivity cutoff, and each customer's values follow from the same definitions.

| Field | At the sensitivity cutoff |
|---|---|
| `age`, `age_invalid_flg`, `gender_*` | Identical to the primary table |
| `days_since_first_issue` | Exactly 7 days lower than the primary table. Null for the 154 cards issued from 2019-03-12 to 2019-03-18 |
| `pre_issue_purchase_flg` | Recalculated from the first transaction before this cutoff |

**The 753 customers with no purchase before 2019-03-12:**

| Fields | Value |
|---|---|
| All counts, spend, points, `active_days_hist`, `distinct_*`, both trend features and `pre_issue_purchase_flg` | 0 |
| Recency, `avg_gap_days`, basket value, `avg_lines_per_basket` and timing shares | Null |
