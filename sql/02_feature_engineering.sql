-- Pre-treatment customer features for Phase 2. Run after 01_data_validation.sql, which
-- builds transactions.parquet. Paths are relative to the project root.
--
-- `customer_groups` deliberately has no `target` column, so this file cannot read the
-- outcome. Definitions are in outputs/tables/data_dictionary.md.

CREATE OR REPLACE VIEW clients AS SELECT * FROM 'data/processed/clients.parquet';
CREATE OR REPLACE VIEW purchases AS SELECT * FROM 'data/processed/purchases.parquet';
CREATE OR REPLACE VIEW transactions AS SELECT * FROM 'data/processed/transactions.parquet';
CREATE OR REPLACE VIEW customer_groups AS
    SELECT client_id, treatment_flg FROM 'data/processed/uplift_train.parquet';


-- One row per labelled customer at a given cutoff. No customer is ever dropped.
-- Windows of N days cover [cutoff - N days, cutoff). `transactions` holds one row per
-- (client_id, transaction_id), so purchase_sum and the points fields are counted once.
CREATE OR REPLACE MACRO customer_features(cutoff) AS TABLE
WITH txn AS (
    SELECT
        client_id,
        min(transaction_datetime) AS first_transaction,
        max(transaction_datetime) AS last_transaction,
        count(*) AS txn_count_hist,
        count(*) FILTER (WHERE transaction_datetime >= cutoff - INTERVAL 7 DAY) AS txn_count_7d,
        count(*) FILTER (WHERE transaction_datetime >= cutoff - INTERVAL 14 DAY) AS txn_count_14d,
        count(*) FILTER (WHERE transaction_datetime >= cutoff - INTERVAL 30 DAY) AS txn_count_30d,
        count(*) FILTER (WHERE transaction_datetime >= cutoff - INTERVAL 60 DAY) AS txn_count_60d,
        count(*) FILTER (WHERE transaction_datetime >= cutoff - INTERVAL 90 DAY) AS txn_count_90d,
        count(*) FILTER (
            WHERE transaction_datetime >= cutoff - INTERVAL 60 DAY
              AND transaction_datetime < cutoff - INTERVAL 30 DAY
        ) AS txn_count_previous_30d,
        count(DISTINCT transaction_datetime::DATE) AS active_days_hist,
        date_diff('day', min(transaction_datetime)::DATE, max(transaction_datetime)::DATE)::DOUBLE
            / nullif(count(DISTINCT transaction_datetime::DATE) - 1, 0) AS avg_gap_days,
        sum(purchase_sum) AS spend_hist,
        coalesce(sum(purchase_sum) FILTER (WHERE transaction_datetime >= cutoff - INTERVAL 30 DAY), 0) AS spend_30d,
        coalesce(sum(purchase_sum) FILTER (WHERE transaction_datetime >= cutoff - INTERVAL 60 DAY), 0) AS spend_60d,
        coalesce(sum(purchase_sum) FILTER (WHERE transaction_datetime >= cutoff - INTERVAL 90 DAY), 0) AS spend_90d,
        coalesce(sum(purchase_sum) FILTER (
            WHERE transaction_datetime >= cutoff - INTERVAL 60 DAY
              AND transaction_datetime < cutoff - INTERVAL 30 DAY
        ), 0) AS spend_previous_30d,
        avg(purchase_sum) AS avg_basket_value,
        max(purchase_sum) AS max_basket_value,
        stddev_samp(purchase_sum) AS std_basket_value,
        avg(n_rows) AS avg_lines_per_basket,
        avg((isodow(transaction_datetime) IN (6, 7))::INT) AS weekend_txn_share,
        avg((hour(transaction_datetime) BETWEEN 5 AND 9)::INT) AS txn_share_05_09,
        avg((hour(transaction_datetime) BETWEEN 10 AND 13)::INT) AS txn_share_10_13,
        avg((hour(transaction_datetime) BETWEEN 14 AND 19)::INT) AS txn_share_14_19,
        sum(regular_points_received) AS regular_points_received_hist,
        0 - sum(regular_points_spent) AS regular_points_spent_hist,
        sum(express_points_received) AS express_points_received_hist,
        0 - sum(express_points_spent) AS express_points_spent_hist,
        0 - coalesce(sum(regular_points_spent) FILTER (WHERE transaction_datetime >= cutoff - INTERVAL 30 DAY), 0)
            AS regular_points_spent_30d,
        0 - coalesce(sum(express_points_spent) FILTER (WHERE transaction_datetime >= cutoff - INTERVAL 30 DAY), 0)
            AS express_points_spent_30d
    FROM transactions
    SEMI JOIN customer_groups USING (client_id)
    WHERE transaction_datetime < cutoff
    GROUP BY client_id
),
product_rows AS (
    SELECT
        client_id,
        count(DISTINCT product_id) AS distinct_products_hist,
        count(DISTINCT store_id) AS distinct_stores_hist
    FROM purchases
    SEMI JOIN customer_groups USING (client_id)
    WHERE transaction_datetime < cutoff
    GROUP BY client_id
)
SELECT
    g.client_id,

    -- Recency
    date_sub('day', t.last_transaction, cutoff) AS days_since_last_purchase,
    date_sub('day', t.first_transaction, cutoff) AS days_since_first_observed_purchase,

    -- Frequency
    coalesce(t.txn_count_hist, 0) AS txn_count_hist,
    coalesce(t.txn_count_7d, 0) AS txn_count_7d,
    coalesce(t.txn_count_14d, 0) AS txn_count_14d,
    coalesce(t.txn_count_30d, 0) AS txn_count_30d,
    coalesce(t.txn_count_60d, 0) AS txn_count_60d,
    coalesce(t.txn_count_90d, 0) AS txn_count_90d,
    coalesce(t.active_days_hist, 0) AS active_days_hist,
    t.avg_gap_days,

    -- Monetary
    coalesce(t.spend_hist, 0) AS spend_hist,
    coalesce(t.spend_30d, 0) AS spend_30d,
    coalesce(t.spend_60d, 0) AS spend_60d,
    coalesce(t.spend_90d, 0) AS spend_90d,
    t.avg_basket_value,
    t.max_basket_value,
    t.std_basket_value,

    -- Trend
    ln((coalesce(t.txn_count_30d, 0) + 1.0) / (coalesce(t.txn_count_previous_30d, 0) + 1.0)) AS txn_trend_30d,
    ln((coalesce(t.spend_30d, 0) + 1.0) / (coalesce(t.spend_previous_30d, 0) + 1.0)) AS spend_trend_30d,

    -- Basket
    t.avg_lines_per_basket,
    coalesce(p.distinct_products_hist, 0) AS distinct_products_hist,
    coalesce(p.distinct_stores_hist, 0) AS distinct_stores_hist,

    -- Timing
    t.weekend_txn_share,
    t.txn_share_05_09,
    t.txn_share_10_13,
    t.txn_share_14_19,

    -- Loyalty
    coalesce(t.regular_points_received_hist, 0) AS regular_points_received_hist,
    coalesce(t.regular_points_spent_hist, 0) AS regular_points_spent_hist,
    coalesce(t.express_points_received_hist, 0) AS express_points_received_hist,
    coalesce(t.express_points_spent_hist, 0) AS express_points_spent_hist,
    coalesce(t.regular_points_spent_30d, 0) AS regular_points_spent_30d,
    coalesce(t.express_points_spent_30d, 0) AS express_points_spent_30d,

    -- Client. Age and the pre-issue flag use the same rules as baseline_customers in
    -- 01_data_validation.sql. The flag compares timestamps, not dates.
    CASE WHEN c.age BETWEEN 14 AND 100 THEN c.age END AS age,
    (c.age IS NULL OR c.age NOT BETWEEN 14 AND 100)::INT AS age_invalid_flg,
    (c.gender = 'F')::INT AS gender_f,
    (c.gender = 'M')::INT AS gender_m,
    (c.gender = 'U')::INT AS gender_u,
    CASE WHEN c.first_issue_date < cutoff THEN date_sub('day', c.first_issue_date, cutoff) END
        AS days_since_first_issue,
    coalesce(t.first_transaction < c.first_issue_date, false)::INT AS pre_issue_purchase_flg
FROM customer_groups AS g
JOIN clients AS c USING (client_id)
LEFT JOIN txn AS t USING (client_id)
LEFT JOIN product_rows AS p USING (client_id)
ORDER BY g.client_id;
