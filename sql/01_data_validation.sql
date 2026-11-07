-- Data validation and experiment-audit queries for Phase 1.
-- Run after 00_load_to_parquet.sql. Paths are relative to the project root.
--
-- `customer_groups` deliberately has no `target` column. Every balance, leakage and
-- placebo query uses it, so those checks cannot read the outcome by accident. The only
-- use of `target` here is a count of null or invalid values, which reveals no rates.

CREATE OR REPLACE VIEW clients AS SELECT * FROM 'data/processed/clients.parquet';
CREATE OR REPLACE VIEW products AS SELECT * FROM 'data/processed/products.parquet';
CREATE OR REPLACE VIEW purchases AS SELECT * FROM 'data/processed/purchases.parquet';
CREATE OR REPLACE VIEW customer_groups AS
    SELECT client_id, treatment_flg FROM 'data/processed/uplift_train.parquet';
CREATE OR REPLACE VIEW uplift_test AS
    SELECT client_id
    FROM read_csv('data/raw/uplift_test.csv', header = true, auto_detect = false,
                  columns = {'client_id': 'VARCHAR'});


-- One row per transaction. The key is (client_id, transaction_id) because 28
-- transaction_id values are shared by two clients. min/max pairs test whether a
-- transaction-level field really holds one value across its product rows.
COPY (
    SELECT
        client_id,
        transaction_id,
        min(transaction_datetime) AS transaction_datetime,
        max(transaction_datetime) AS transaction_datetime_max,
        min(purchase_sum) AS purchase_sum,
        max(purchase_sum) AS purchase_sum_max,
        min(regular_points_received) AS regular_points_received,
        max(regular_points_received) AS regular_points_received_max,
        min(regular_points_spent) AS regular_points_spent,
        max(regular_points_spent) AS regular_points_spent_max,
        min(express_points_received) AS express_points_received,
        max(express_points_received) AS express_points_received_max,
        min(express_points_spent) AS express_points_spent,
        max(express_points_spent) AS express_points_spent_max,
        sum(trn_sum_from_iss) AS sum_from_iss,
        sum(coalesce(trn_sum_from_red, 0)) AS sum_from_red,
        count(trn_sum_from_red) AS n_red_rows,
        count(*) AS n_rows,
        sum((product_quantity = 0)::INT) AS n_zero_quantity_rows,
        sum((product_quantity < 0)::INT) AS n_negative_quantity_rows
    FROM purchases
    GROUP BY client_id, transaction_id
) TO 'data/processed/transactions.parquet' (FORMAT parquet, COMPRESSION zstd);

CREATE OR REPLACE VIEW transactions AS SELECT * FROM 'data/processed/transactions.parquet';


-- Data quality checks. A non-null `expected` is a hard expectation; a null one is a
-- measurement to report.
CREATE OR REPLACE TABLE data_quality AS
WITH checks(check_group, check_name, value, expected) AS (
    SELECT 'Row counts', 'clients rows', (SELECT count(*) FROM clients)::DOUBLE, 400162::DOUBLE
    UNION ALL SELECT 'Row counts', 'purchases rows', (SELECT count(*) FROM purchases), 45786568
    UNION ALL SELECT 'Row counts', 'uplift_train rows', (SELECT count(*) FROM customer_groups), 200039
    UNION ALL SELECT 'Row counts', 'uplift_test rows', (SELECT count(*) FROM uplift_test), 200123
    UNION ALL SELECT 'Row counts', 'products rows', (SELECT count(*) FROM products), NULL

    -- Comparisons below ignore nulls, so required fields are checked for nulls explicitly.
    UNION ALL SELECT 'Required fields', 'treatment_flg null or outside 0 and 1', (
        SELECT count(*) FROM 'data/processed/uplift_train.parquet'
        WHERE treatment_flg IS NULL OR treatment_flg NOT IN (0, 1)), 0
    UNION ALL SELECT 'Required fields', 'target null or outside 0 and 1', (
        SELECT count(*) FROM 'data/processed/uplift_train.parquet'
        WHERE target IS NULL OR target NOT IN (0, 1)), 0
    UNION ALL SELECT 'Required fields', 'clients with a null required field', (
        SELECT count(*) FROM clients
        WHERE client_id IS NULL OR first_issue_date IS NULL OR age IS NULL OR gender IS NULL), 0
    UNION ALL SELECT 'Required fields', 'purchase rows with a null required field', (
        SELECT count(*) FROM purchases
        WHERE transaction_datetime IS NULL OR purchase_sum IS NULL OR product_id IS NULL
           OR product_quantity IS NULL OR trn_sum_from_iss IS NULL
           OR regular_points_received IS NULL OR regular_points_spent IS NULL
           OR express_points_received IS NULL OR express_points_spent IS NULL), 0

    UNION ALL SELECT 'Keys', 'duplicate client_id in clients',
        (SELECT count(*) - count(DISTINCT client_id) FROM clients), 0
    UNION ALL SELECT 'Keys', 'duplicate client_id in uplift_train',
        (SELECT count(*) - count(DISTINCT client_id) FROM customer_groups), 0
    UNION ALL SELECT 'Keys', 'duplicate client_id in uplift_test',
        (SELECT count(*) - count(DISTINCT client_id) FROM uplift_test), 0
    UNION ALL SELECT 'Keys', 'duplicate product_id in products',
        (SELECT count(*) - count(DISTINCT product_id) FROM products), 0
    UNION ALL SELECT 'Keys', 'null client_id or transaction_id in purchases',
        (SELECT count(*) FROM purchases WHERE client_id IS NULL OR transaction_id IS NULL), 0
    UNION ALL SELECT 'Keys', 'distinct (client_id, transaction_id)', (SELECT count(*) FROM transactions), NULL
    UNION ALL SELECT 'Keys', 'distinct transaction_id',
        (SELECT count(DISTINCT transaction_id) FROM transactions), NULL
    UNION ALL SELECT 'Keys', 'transaction_id values shared by more than one client', (
        SELECT count(*) FROM (
            SELECT transaction_id FROM transactions GROUP BY 1 HAVING count(*) > 1)), NULL
    UNION ALL SELECT 'Keys', 'duplicate product within a transaction', (
        SELECT count(*) FROM (
            SELECT client_id, transaction_id, product_id FROM purchases
            GROUP BY 1, 2, 3 HAVING count(*) > 1)), 0

    UNION ALL SELECT 'Joins', 'uplift_train and uplift_test overlap',
        (SELECT count(*) FROM customer_groups JOIN uplift_test USING (client_id)), 0
    UNION ALL SELECT 'Joins', 'uplift_train clients missing from clients',
        (SELECT count(*) FROM customer_groups ANTI JOIN clients USING (client_id)), 0
    UNION ALL SELECT 'Joins', 'uplift_test clients missing from clients',
        (SELECT count(*) FROM uplift_test ANTI JOIN clients USING (client_id)), 0
    UNION ALL SELECT 'Joins', 'clients in neither uplift_train nor uplift_test', (
        SELECT count(*) FROM clients
        WHERE client_id NOT IN (SELECT client_id FROM customer_groups)
          AND client_id NOT IN (SELECT client_id FROM uplift_test)), 0
    UNION ALL SELECT 'Joins', 'uplift_train clients with no purchases', (
        SELECT count(*) FROM customer_groups
        ANTI JOIN (SELECT DISTINCT client_id FROM transactions) USING (client_id)), 0
    UNION ALL SELECT 'Joins', 'purchase clients missing from clients', (
        SELECT count(*) FROM (SELECT DISTINCT client_id FROM transactions)
        ANTI JOIN clients USING (client_id)), 0
    UNION ALL SELECT 'Joins', 'purchase rows with a product missing from products',
        (SELECT count(*) FROM purchases ANTI JOIN products USING (product_id)), NULL

    UNION ALL SELECT 'Transaction fields', 'transactions with more than one purchase_sum',
        (SELECT count(*) FROM transactions WHERE purchase_sum <> purchase_sum_max), 0
    UNION ALL SELECT 'Transaction fields', 'transactions with more than one timestamp',
        (SELECT count(*) FROM transactions WHERE transaction_datetime <> transaction_datetime_max), 0
    UNION ALL SELECT 'Transaction fields', 'transactions with more than one value in a points field', (
        SELECT count(*) FROM transactions
        WHERE regular_points_received <> regular_points_received_max
           OR regular_points_spent <> regular_points_spent_max
           OR express_points_received <> express_points_received_max
           OR express_points_spent <> express_points_spent_max), 0
    UNION ALL SELECT 'Transaction fields', 'multi-row transactions',
        (SELECT count(*) FROM transactions WHERE n_rows > 1), NULL

    UNION ALL SELECT 'Invalid values', 'clients with age outside 14-100',
        (SELECT count(*) FROM clients WHERE age NOT BETWEEN 14 AND 100), NULL
    UNION ALL SELECT 'Invalid values', 'uplift_train clients with age outside 14-100', (
        SELECT count(*) FROM clients JOIN customer_groups USING (client_id)
        WHERE age NOT BETWEEN 14 AND 100), NULL
    UNION ALL SELECT 'Invalid values', 'minimum age', (SELECT min(age) FROM clients), NULL
    UNION ALL SELECT 'Invalid values', 'maximum age', (SELECT max(age) FROM clients), NULL
    UNION ALL SELECT 'Invalid values', 'gender outside M, F, U',
        (SELECT count(*) FROM clients WHERE gender NOT IN ('M', 'F', 'U')), 0
    UNION ALL SELECT 'Invalid values', 'first_redeem_date before first_issue_date',
        (SELECT count(*) FROM clients WHERE first_redeem_date < first_issue_date), NULL
    UNION ALL SELECT 'Invalid values', 'negative purchase_sum',
        (SELECT count(*) FROM transactions WHERE purchase_sum < 0), 0
    UNION ALL SELECT 'Invalid values', 'transactions with purchase_sum of zero',
        (SELECT count(*) FROM transactions WHERE purchase_sum = 0), NULL
    UNION ALL SELECT 'Invalid values', 'purchase rows with zero quantity',
        (SELECT sum(n_zero_quantity_rows) FROM transactions), NULL
    UNION ALL SELECT 'Invalid values', 'transactions with a zero-quantity row',
        (SELECT count(*) FROM transactions WHERE n_zero_quantity_rows > 0), NULL
    UNION ALL SELECT 'Invalid values', 'purchase rows with negative quantity',
        (SELECT sum(n_negative_quantity_rows) FROM transactions), 0
    UNION ALL SELECT 'Invalid values', 'transactions with negative points received', (
        SELECT count(*) FROM transactions
        WHERE regular_points_received < 0 OR express_points_received < 0), NULL
    UNION ALL SELECT 'Invalid values', 'transactions with positive points spent', (
        SELECT count(*) FROM transactions
        WHERE regular_points_spent > 0 OR express_points_spent > 0), NULL
    UNION ALL SELECT 'Invalid values', 'transactions dated on or after the primary cutoff',
        (SELECT count(*) FROM transactions WHERE transaction_datetime >= TIMESTAMP '2019-03-19 00:00:00'), 0
)
SELECT
    check_group,
    check_name,
    value,
    expected,
    CASE
        WHEN expected IS NULL THEN 'REPORT'
        WHEN value = expected THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM checks;


-- Missing values by column.
CREATE OR REPLACE TABLE data_quality_missing AS
SELECT 'clients' AS source, column_name, n_missing, (SELECT count(*) FROM clients) AS n_rows
FROM (UNPIVOT (SELECT count(*) - count(COLUMNS(*)) AS "\0" FROM clients)
      ON COLUMNS(*) INTO NAME column_name VALUE n_missing)
UNION ALL
SELECT 'purchases', column_name, n_missing, (SELECT count(*) FROM purchases)
FROM (UNPIVOT (SELECT count(*) - count(COLUMNS(*)) AS "\0" FROM purchases)
      ON COLUMNS(*) INTO NAME column_name VALUE n_missing)
UNION ALL
SELECT 'products', column_name, n_missing, (SELECT count(*) FROM products)
FROM (UNPIVOT (SELECT count(*) - count(COLUMNS(*)) AS "\0" FROM products)
      ON COLUMNS(*) INTO NAME column_name VALUE n_missing)
UNION ALL
SELECT 'uplift_train', column_name, n_missing, (SELECT count(*) FROM customer_groups)
FROM (UNPIVOT (SELECT count(*) - count(COLUMNS(*)) AS "\0" FROM customer_groups)
      ON COLUMNS(*) INTO NAME column_name VALUE n_missing);


-- Date ranges for every date column.
CREATE OR REPLACE TABLE data_quality_dates AS
SELECT 'first_issue_date' AS date_column, min(first_issue_date) AS earliest, max(first_issue_date) AS latest FROM clients
UNION ALL SELECT 'first_redeem_date', min(first_redeem_date), max(first_redeem_date) FROM clients
UNION ALL SELECT 'transaction_datetime', min(transaction_datetime), max(transaction_datetime) FROM transactions;


-- Reconciling purchase_sum with the product-level amounts. The mismatch is documented,
-- not repaired: purchase_sum stays the only monetary measure.
CREATE OR REPLACE TABLE amount_reconciliation AS
SELECT
    n_red_rows > 0 AS has_sum_from_red,
    regular_points_spent <> 0 OR express_points_spent <> 0 AS points_spent,
    count(*) AS n_transactions,
    avg((abs(purchase_sum - sum_from_iss - sum_from_red) < 1)::INT) AS share_within_1_iss_plus_red,
    avg((abs(purchase_sum - sum_from_iss) < 1)::INT) AS share_within_1_iss_only,
    median(purchase_sum - sum_from_iss - sum_from_red) AS median_gap,
    avg(purchase_sum - sum_from_iss - sum_from_red) AS mean_gap,
    sum(purchase_sum) AS total_purchase_sum,
    sum(sum_from_iss) AS total_sum_from_iss,
    sum(sum_from_red) AS total_sum_from_red
FROM transactions
GROUP BY 1, 2
ORDER BY 1, 2;


-- One row per labelled customer at a given cutoff. No customer is ever dropped.
-- Customers without a purchase before the cutoff keep a row: counts and spend are 0 and
-- recency is null. A card issued after the cutoff gives a null tenure.
CREATE OR REPLACE MACRO baseline_customers(cutoff) AS TABLE
WITH txn AS (
    SELECT
        client_id,
        count(*) AS transaction_count,
        sum(purchase_sum) AS total_spend,
        max(transaction_datetime) AS last_transaction,
        min(transaction_datetime) AS first_transaction
    FROM transactions
    WHERE transaction_datetime < cutoff
    GROUP BY client_id
)
SELECT
    g.client_id,
    g.treatment_flg,
    CASE WHEN c.age BETWEEN 14 AND 100 THEN c.age END AS age,
    (c.age IS NULL OR c.age NOT BETWEEN 14 AND 100)::INT AS age_invalid_flg,
    c.gender,
    CASE WHEN c.first_issue_date < cutoff THEN date_sub('day', c.first_issue_date, cutoff) END
        AS days_since_first_issue,
    coalesce(t.first_transaction < c.first_issue_date, false)::INT AS pre_issue_purchase_flg,
    coalesce(t.transaction_count, 0) AS transaction_count,
    coalesce(t.total_spend, 0) AS total_spend,
    date_sub('day', t.last_transaction, cutoff) AS days_since_last_purchase
FROM customer_groups AS g
JOIN clients AS c USING (client_id)
LEFT JOIN txn AS t USING (client_id)
ORDER BY g.client_id;


-- Daily purchase activity by recorded SMS communication status.
CREATE OR REPLACE TABLE daily_activity AS
SELECT
    t.transaction_datetime::DATE AS activity_date,
    g.treatment_flg,
    count(*) AS n_transactions,
    count(DISTINCT t.client_id) AS n_active_customers
FROM transactions AS t
JOIN customer_groups AS g USING (client_id)
GROUP BY 1, 2
ORDER BY 1, 2;


-- first_redeem_date is supporting evidence only and never a model feature.
CREATE OR REPLACE MACRO first_redeem_by_group(cutoff) AS TABLE
SELECT
    g.treatment_flg,
    count(*) AS n_customers,
    sum((c.first_redeem_date IS NULL)::INT) AS n_missing,
    sum(coalesce(c.first_redeem_date >= cutoff, false)::INT) AS n_after_cutoff,
    max(c.first_redeem_date) AS latest
FROM customer_groups AS g
JOIN clients AS c USING (client_id)
GROUP BY 1
ORDER BY 1;

CREATE OR REPLACE TABLE first_redeem_daily AS
SELECT
    c.first_redeem_date::DATE AS redeem_date,
    g.treatment_flg,
    count(*) AS n_customers
FROM customer_groups AS g
JOIN clients AS c USING (client_id)
WHERE c.first_redeem_date IS NOT NULL
GROUP BY 1, 2
ORDER BY 1, 2;


-- Any-purchase indicator in a window of [window_start, window_end), for the placebo test.
CREATE OR REPLACE MACRO placebo_rates(window_start, window_end) AS TABLE
WITH buyers AS (
    SELECT DISTINCT client_id
    FROM transactions
    WHERE transaction_datetime >= window_start AND transaction_datetime < window_end
)
SELECT
    g.treatment_flg,
    count(*) AS n_customers,
    count(b.client_id) AS n_purchasers
FROM customer_groups AS g
LEFT JOIN buyers AS b USING (client_id)
GROUP BY 1
ORDER BY 1;


-- Points by customer in a window of [window_start, window_end). One value per transaction.
CREATE OR REPLACE MACRO customer_points(window_start, window_end) AS TABLE
WITH txn AS (
    SELECT
        client_id,
        count(*) AS n_transactions,
        max((express_points_received <> 0)::INT) AS any_express_received,
        max((express_points_spent <> 0)::INT) AS any_express_spent,
        max((regular_points_received <> 0)::INT) AS any_regular_received,
        max((regular_points_spent <> 0)::INT) AS any_regular_spent,
        sum(express_points_received) AS express_received,
        sum(-express_points_spent) AS express_spent,
        sum(regular_points_received) AS regular_received,
        sum(-regular_points_spent) AS regular_spent
    FROM transactions
    WHERE transaction_datetime >= window_start AND transaction_datetime < window_end
    GROUP BY client_id
)
SELECT
    g.client_id,
    g.treatment_flg,
    coalesce(t.any_express_received, 0) AS any_express_received,
    coalesce(t.any_express_spent, 0) AS any_express_spent,
    coalesce(t.any_regular_received, 0) AS any_regular_received,
    coalesce(t.any_regular_spent, 0) AS any_regular_spent,
    coalesce(t.express_received, 0) AS express_received,
    coalesce(t.express_spent, 0) AS express_spent,
    coalesce(t.regular_received, 0) AS regular_received,
    coalesce(t.regular_spent, 0) AS regular_spent
FROM customer_groups AS g
LEFT JOIN txn AS t USING (client_id)
ORDER BY g.client_id;


-- Weekly share of transactions with express points, by group.
CREATE OR REPLACE TABLE express_points_weekly AS
SELECT
    date_trunc('week', t.transaction_datetime)::DATE AS week_start,
    g.treatment_flg,
    count(*) AS n_transactions,
    avg((t.express_points_received <> 0)::INT) AS share_received,
    avg((t.express_points_spent <> 0)::INT) AS share_spent
FROM transactions AS t
JOIN customer_groups AS g USING (client_id)
GROUP BY 1, 2
ORDER BY 1, 2;
