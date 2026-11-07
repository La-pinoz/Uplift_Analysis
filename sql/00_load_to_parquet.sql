-- Convert the raw competition files to typed Parquet.
-- Paths are relative to the project root.
--
-- Loaded: clients, purchases, products, uplift_train.
-- uplift_test.csv is only read for row-count and overlap checks (01_data_validation.sql).
-- check_queries.tsv and uplift_sample_submission.csv are not part of the workflow.
--
-- auto_detect = false makes a type or column-count mismatch fail instead of being guessed.
-- Columns bind by position and names are not compared, so the audit notebook checks each
-- file's header line before running this script.

COPY (
    SELECT *
    FROM read_csv(
        'data/raw/clients.csv',
        header = true,
        auto_detect = false,
        columns = {
            'client_id': 'VARCHAR',
            'first_issue_date': 'TIMESTAMP',
            'first_redeem_date': 'TIMESTAMP',
            'age': 'INTEGER',
            'gender': 'VARCHAR'
        }
    )
) TO 'data/processed/clients.parquet' (FORMAT parquet, COMPRESSION zstd);

COPY (
    SELECT *
    FROM read_csv(
        'data/raw/uplift_train.csv',
        header = true,
        auto_detect = false,
        columns = {
            'client_id': 'VARCHAR',
            'treatment_flg': 'TINYINT',
            'target': 'TINYINT'
        }
    )
) TO 'data/processed/uplift_train.parquet' (FORMAT parquet, COMPRESSION zstd);

COPY (
    SELECT *
    FROM read_csv(
        'data/raw/products.csv',
        header = true,
        auto_detect = false,
        columns = {
            'product_id': 'VARCHAR',
            'level_1': 'VARCHAR',
            'level_2': 'VARCHAR',
            'level_3': 'VARCHAR',
            'level_4': 'VARCHAR',
            'segment_id': 'DOUBLE',
            'brand_id': 'VARCHAR',
            'vendor_id': 'VARCHAR',
            'netto': 'DOUBLE',
            'is_own_trademark': 'TINYINT',
            'is_alcohol': 'TINYINT'
        }
    )
) TO 'data/processed/products.parquet' (FORMAT parquet, COMPRESSION zstd);

COPY (
    SELECT *
    FROM read_csv(
        'data/raw/purchases.csv',
        header = true,
        auto_detect = false,
        columns = {
            'client_id': 'VARCHAR',
            'transaction_id': 'VARCHAR',
            'transaction_datetime': 'TIMESTAMP',
            'regular_points_received': 'DOUBLE',
            'express_points_received': 'DOUBLE',
            'regular_points_spent': 'DOUBLE',
            'express_points_spent': 'DOUBLE',
            'purchase_sum': 'DOUBLE',
            'store_id': 'VARCHAR',
            'product_id': 'VARCHAR',
            'product_quantity': 'DOUBLE',
            'trn_sum_from_iss': 'DOUBLE',
            'trn_sum_from_red': 'DOUBLE'
        }
    )
) TO 'data/processed/purchases.parquet' (FORMAT parquet, COMPRESSION zstd);
