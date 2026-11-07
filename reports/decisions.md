# Decisions and Evidence Log

This log records the evidence behind the analysis and the choices fixed before results were seen. Where it differs from `PROJECT_PLAN.md`, this log takes precedence.

## Phase 1 status

**Complete.** The cutoff, excluded fields and allowed causal wording are recorded below.

## Project rules used here

These are quoted because the project plan is kept local and is not in this repository.

- **Protect the holdout:** "Create the split once with a fixed seed, stratified by treatment and target. Do not use holdout outcomes for feature, model or threshold decisions."
- **Allow pre-model checks on all labelled data:** "The treatment split, balance, leakage checks and overall ATE can use all 200k because they do not select a model."
- **Lock before the final test:** "Commit `reports/decisions.md` before opening holdout results."

## Allowed wording

| Topic | Wording to use |
|---|---|
| Assignment | Observed checks are consistent with random assignment, but randomisation is not documented. Causal claims depend on that assumption. |
| Overall result | Observed treatment-control difference by recorded SMS communication status |
| `target` | Purchase in an undocumented period after communication |
| Population | The labelled cohort only |

Balanced observed characteristics and a passing placebo test support the assignment wording. They do not prove randomisation.

Do not claim an intent-to-treat effect, a response window, or that the results represent all X5 customers.

## Evidence on treatment assignment

The documentation search is closed. Only official organiser or competition documentation counts as evidence of randomisation.

| Source | What it establishes | What it does not establish |
|---|---|---|
| [ODS.ai competition page](https://ods.ai/competitions/x5-retailhero-uplift-modeling) | The communication is an advertising SMS | Random assignment, control group design, campaign date, outcome window |
| [ODS.ai data page](https://ods.ai/competitions/x5-retailhero-uplift-modeling/data) | `purchases.csv` is described as purchase history prior to communication; `treatment_flg` as whether there was a communication; `target` as whether there was a purchase afterward | Random assignment, send date, outcome window |
| [scikit-uplift `fetch_x5` docs](https://www.uplift-modeling.com/en/latest/api/datasets/fetch_x5.html) (secondary) | Dataset source, row counts, treatment ratio of .5, response ratio of .62 | Random assignment, campaign date, outcome window |
| Web searches (secondary) | A search summary said the mailing was randomised, but it could not be traced to organiser material, so it is not counted | Any organiser statement on assignment |

**Not checked:** the 596 MB organiser archive `retailhero-uplift.zip`. "Not documented" therefore means not found in the sources above, and the archive could still describe assignment.

These descriptions came from web fetches that return page summaries. Check the source page before quoting them exactly.

## Unresolved assumptions

- **Assignment:** random assignment is assumed, not documented.
- **Assignment or delivery:** `treatment_flg` may record who was assigned or who was successfully messaged. Causal interpretation is conditional on the flag adequately representing the intervention.
- **Outcome window:** its start and end are undocumented, and purchases stop before it. It may include days before the send date.
- **Campaign date:** the rise in first redemptions among treated customers suggests about 2019-03-21. This is an inference.
- **Eligibility:** every labelled customer has a purchase on or after 2019-02-24. This is an observed fact. Any eligibility rule behind it is an inference.

## Locked decisions

| Topic | Decision |
|---|---|
| Feature cutoff | `transaction_datetime < 2019-03-19 00:00`, using all history through 2019-03-18. Treatment-control ratios cannot change it. |
| Cutoff sensitivity | Reported with `transaction_datetime < 2019-03-12 00:00`. It cannot set the primary cutoff. |
| `first_redeem_date` | Excluded from all model feature sets. Phase 1 supporting evidence only. |
| Transaction key | `(client_id, transaction_id)` |
| Monetary measure | `purchase_sum` only, one value per transaction. The product-level amount mismatch is documented, not repaired. |
| Customers | No customer in `uplift_train` is ever dropped. |
| Age | Values outside 14-100 become null, with `age_invalid_flg`. |
| Tenure | Days since `first_issue_date`, with `pre_issue_purchase_flg` for purchases before the issue date. |
| Unusual rows | Zero-quantity product rows and zero-sum transactions are kept. |
| Overall comparison | All 200,039 labelled customers: unpooled Wald 95% interval, two-sided pooled two-proportion z-test, delta-method 95% interval on the log risk ratio, stratified percentile bootstrap with 2,000 resamples and a fixed seed. No separate overall estimate on the holdout. |
| Split | Sorted by `client_id`, seed 42, stratified on treatment by target: 80% development, 20% holdout, five stratified folds within development. |
| Balance review | Review any standardised mean difference above 0.05 and treat any above 0.1 as a concern. These are rules of thumb. |
| Primary placebo | Any purchase from 2019-01-27 to 2019-02-23, which ends before the 2019-02-24 boundary. |
| Secondary placebo | Any purchase from 2019-02-18 to 2019-03-03, the plan's original window. |

**Split SHA-256:** `20d8b8e1ea2d348e6c8f83cf5a92cd421761fa612429d23efd8720279a66c223`

The hash covers the sorted customer IDs with their split and fold labels. The audit notebook stops if a rerun produces a different value.

## Audit results recorded before purchase rates were seen

All numbers are **Measured** from `notebooks/01_experiment_audit.ipynb`, and the tables are in `outputs/tables/`.

**How far the order can be trusted:** these conclusions were written before the purchase-rate section was first run. Version history cannot confirm this, because they were all first committed together, and the notebook now runs both in one pass.

**Added after purchase rates were seen:** code review led to a stricter points check (risk ratios with intervals), the missing-value counts at the sensitivity cutoff and more data validation checks. None of them changed a conclusion above or below.

| Check | Result | Conclusion |
|---|---|---|
| Sample ratio | 99,981 treated and 100,058 control (49.98% treated, p = 0.86) | No sample ratio problem against an expected 50/50 split |
| Balance, primary cutoff | Largest absolute standardised mean difference (SMD) is 0.0130 | All 12 variables are below the 0.05 review threshold |
| Balance, seven-day sensitivity | Largest absolute SMD is 0.0129 | All below 0.05, so the cutoff choice does not change the conclusion |
| Primary placebo (Jan 27 to Feb 23) | 87.52% treated, 87.48% control; difference +0.05 points, 95% CI -0.24 to +0.34 | No difference detected |
| Secondary placebo (Feb 18 to Mar 3) | 83.54% treated, 83.34% control; difference +0.20 points, 95% CI -0.13 to +0.52 | No difference detected; this window overlaps the 2019-02-24 boundary |
| Final seven days of activity | Treated-control rate ratio of 1.0030, against an earlier rolling range of 0.9950 to 1.0169 | No divergence at the end of the history |

**Small differences to keep in view:**

- Two primary variables fall outside the ±0.0088 range expected from a random split of this size: purchase before issue (-0.0130) and log total spend (+0.0095).
- At the seven-day sensitivity cutoff, those two (-0.0129 and +0.0108) and days since last purchase (+0.0121) fall outside it. Days since last purchase is missing there for customers with no earlier purchase: 362 treated and 391 control. Days since first issue is missing for cards issued after that cutoff: 74 treated and 80 control.
- Treated customers are slightly more active on most activity measures, and the rolling ratio sits above 1 for most of the history.
- These differences are small and the measures are correlated. They do not reach the review threshold, but balance on observed variables cannot rule out differences on unobserved ones.

**Allowed causal wording:** the checks pass and randomisation is not documented, so the middle tier applies: "Observed checks are consistent with random assignment, but randomisation is not documented. Causal claims depend on that assumption."

### `first_redeem_date`

| Group | Missing | After the cutoff (all customers) | After the cutoff (non-missing dates) |
|---|---:|---:|---:|
| Treated | 8.44% | 11.49% | 12.55% |
| Control | 9.10% | 11.10% | 12.22% |

The field runs to 2019-11-20, about eight months after the history ends. First redemptions among treated customers rise sharply from 2019-03-21 (295 treated, 89 control), peaking on 2019-03-22 (991 treated, 103 control). The field contains post-treatment information, so the exclusion from all model feature sets stands.

### `express_points_*`

| Window | Largest absolute express SMD | Largest absolute regular points SMD |
|---|---:|---:|
| Full history | 0.0052 | 0.0045 |
| Last 28 days | 0.0038 | 0.0024 |

SMD is a weak test for a rare field, so the "any points" measures also get a risk ratio with a 95% interval. A field passes only if every SMD is below 0.05 and every interval includes 1.

| Measure | Window | Treated customers | Control customers | Risk ratio (95% CI) |
|---|---|---:|---:|---:|
| Any express points received | Full history | 1,890 | 1,821 | 1.04 (0.97 to 1.11) |
| Any express points received | Last 28 days | 61 | 52 | 1.17 (0.81 to 1.70) |
| Any express points spent | Full history | 18,114 | 18,127 | 1.00 (0.98 to 1.02) |
| Any express points spent | Last 28 days | 6,705 | 6,623 | 1.01 (0.98 to 1.05) |

**Decision:** express points may be used in Phase 2 on values before the cutoff, because they pass both tests. Regular points passed the same tests.

**Limits:**

- **What passing means:** no treatment-related difference was detected. For recent express points received, the counts are too small to rule out a sizeable relative difference.
- **Rarity:** express points received arrive in bursts, and most weeks have almost none. 1.9% of customers received any in the full history and 0.06% in the last 28 days.
- **Meaning:** the field's meaning and any link to earlier campaigns remain undocumented.

## Overall treatment-control comparison

This is the observed treatment-control difference by recorded SMS communication status, across all 200,039 labelled customers. All values are **Measured**. The outcome is a purchase in an undocumented period after communication.

| Measure | Result |
|---|---:|
| Treated purchase rate | 63.65% (63,639 of 99,981) |
| Control purchase rate | 60.33% (60,363 of 100,058) |
| Absolute difference | +3.32 points |
| 95% CI, unpooled Wald | +2.90 to +3.75 points |
| 95% CI, stratified percentile bootstrap (2,000 resamples, seed 42) | +2.88 to +3.74 points |
| Relative lift | +5.51% |
| 95% CI for relative lift, delta method on the log risk ratio | +4.79% to +6.24% |
| Two-sided pooled z-test | z = 15.31, p < 0.001 |

**How to read it:** the difference is much larger than either placebo difference (+0.05 and +0.20 points). Under the assignment assumption it can be read as a causal effect of the recorded communication. Without that assumption, it is an association.

**What it cannot show:** the effect on any individual customer, whether some customers responded more than others, or revenue and margin.

### Observed precision

These are **Estimated** 95% margins for uplift in a targeted group, using observed group rates and actual split sizes. A targeted group's real rates may differ.

| Budget | Holdout (40,008) | Out-of-fold (160,031) | Plan's assumed values |
|---|---:|---:|---:|
| 5% | ±4.25 points | ±2.13 points | ±4.2 and ±2.1 |
| 10% | ±3.01 points | ±1.50 points | ±3.0 and ±1.5 |
| 20% (primary) | ±2.13 points | ±1.06 points | ±2.1 and ±1.1 |
| 30% | ±1.74 points | ±0.87 points | ±1.7 and ±0.9 |

The observed values confirm the plan's assumptions closely, so the design is unchanged.

## Status of the plan's claims

| Claim | Status |
|---|---|
| Row counts | **Confirmed** |
| Treatment ratio of about 50% | **Confirmed:** 49.98% |
| Response rate of about 62% | **Confirmed:** 61.99% (124,002 of 200,039) |
| `first_redeem_date` extends to about November 2019 | **Confirmed:** 2019-11-20 |
| `first_issue_date` ends in about March 2019 | **Confirmed:** 2019-03-15 |
| `purchase_sum` repeats across product rows | **Confirmed** under the composite key |
| Purchase history ends before the campaign | **Documented and supported:** the history ends 2019-03-18, and the campaign date is inferred |
| How and when the outcome window was defined | **Not documented** |
| How treatment was assigned | **Not documented** |
| Age contains invalid values | **Confirmed:** 1,779 of all clients and 883 labelled customers outside 14-100 |

## Files outside the analytical workflow

| File | Treatment | Why |
|---|---|---|
| `uplift_test.csv` | Row-count and overlap checks only | Has no labels, and the unlabelled customers are out of scope |
| `check_queries.tsv` | Skipped | 101 query records that are not listed on the ODS.ai data page and are not needed for this analysis |
| `uplift_sample_submission.csv` | Skipped | A competition submission template with no analytical content |

## Where Phase 1 departs from the plan

| Plan | This analysis | Why |
|---|---|---|
| Move the cutoff earlier if the checks show a problem | The cutoff is fixed, and a seven-day sensitivity check is reported | Documentation describes the purchases as pre-communication history, and small group ratios should not decide the cutoff |
| Placebo window of 28 to 15 days before the cutoff | That window is secondary, and a 28-day window ending 2019-02-23 is primary | The original window overlaps the 2019-02-24 activity boundary |
| Keep one `purchase_sum` per transaction | The transaction key is `(client_id, transaction_id)` | 28 `transaction_id` values are shared by two clients |
| Two-hour documentation search | Closed early | The timebox was an upper limit, and no further search was requested |

## Phase 2 status

**Complete.** The feature tables are validated, and the balance rerun and treatment-prediction check ran after their rules below were committed. Results are in "Phase 2 check results".

Definitions are in `outputs/tables/data_dictionary.md`. Phase 2 never reads `target`.

## Phase 2 locked decisions

| Topic | Decision |
|---|---|
| Feature tables | One SQL macro with the cutoff as a parameter builds both tables. Each holds `client_id` and 39 features, with no treatment, outcome or split columns. |
| Cutoffs | Primary: `transaction_datetime < 2019-03-19 00:00`. Sensitivity: `transaction_datetime < 2019-03-12 00:00`. Both are exclusive. |
| Sensitivity table | Used only for balance and treatment-prediction checks, never for training. |
| Names | `_hist` names totals over the available history: 118 days at the primary cutoff and 111 at the sensitivity cutoff. The data dictionary marks every feature this limit affects, including those without the suffix. |
| Trend | `ln((last 30 days + 1) / (previous 30 days + 1))` for transactions and spend. It is biased upward because every customer bought on or after 2019-02-24. |
| Timing | Weekend share and three neutral recorded-hour bands: 05-09, 10-13 and 14-19. |
| Points | Full-history totals for all four fields, plus 30-day spent for regular and express. Each uses one value per `(client_id, transaction_id)`, asserted constant within a transaction. Spent is shown as positive. |
| Express label | "Cleared in Phase 1; inclusion set by the treatment-check rule". The label does not change after the check, and the result is recorded in this log. Project rule 3 says "any doubtful field stays out of the primary model". Express points passed the Phase 1 checks, so they are not treated as doubtful under that rule, even though their meaning remains undocumented. Entry to the Phase 3 model is decided only by the inclusion rule below. |
| Missing and extreme values | Undefined stays null. Empty-window counts and spend are 0. No imputation, caps or logs in the table. |
| Age | Same rule as Phase 1: 14 to 100 inclusive is valid. Anything else is null with `age_invalid_flg` = 1. |
| `pre_issue_purchase_flg` | Same rule as Phase 1: compares timestamps. A same-day first purchase before the issue time is 1, and one at or after the issue time is 0. |
| `first_redeem_date` | Stays out of the feature tables and every treatment-prediction run. |

## Rules for the Phase 2 checks

These rules were written before either check ran. The commit that adds this section is the record of that order, and results are added in a later commit.

**Treatment-prediction setup**

| Item | Rule |
|---|---|
| Customers | All 200,039. `target` is not used. |
| Feature sets | 36 features without express points, and 39 with them. The three express features are `express_points_received_hist`, `express_points_spent_hist` and `express_points_spent_30d`. |
| Runs | Both feature sets at both cutoffs, four in total |
| Model | XGBoost, not tuned: `n_estimators=300`, `max_depth=4`, `learning_rate=0.05`, `subsample=0.8`, `colsample_bytree=0.8`, `tree_method="hist"`, seed 42 |
| Folds | New five-fold split, sorted by `client_id` and stratified on `treatment_flg` only, seed 42. The saved folds cover development customers only and were stratified using `target`. |
| AUC | Calculated once on the pooled out-of-fold predictions |
| Intervals | Stratified percentile bootstrap, 2,000 resamples, seed 42, using the same resamples for paired differences |

**Stop rule, using the AUC point estimate**

| Result | Action |
|---|---|
| Every AUC below 0.52 | Report with intervals, with no stop or investigation. The express inclusion rule below still decides whether express points enter Phase 3 |
| A 36-feature AUC at or above 0.52, at either cutoff | Stop and investigate before Phase 3 |
| Only 39-feature AUCs at or above 0.52 | Expected resolution: drop express points, without halting |

**Express inclusion rule:** express points enter the Phase 3 model only if, at the primary cutoff, the 36-feature and 39-feature AUCs are both below 0.52 and AUC(39) - AUC(36) is at most 0.005, using point estimates. A 39-feature AUC at or above 0.52 at the sensitivity cutoff also drops them, under the stop rule. The 0.005 test applies at the primary cutoff only. The inclusion result is recorded in this log after the check runs.

**Also reported:** AUC(39) - AUC(36) at the sensitivity cutoff, for information with no action, and primary-minus-sensitivity AUC for each feature set.

**Main multivariate check:** the treatment-prediction AUC is the main multivariate check, and it isn't affected by monotonic transforms of a feature, because tree splits depend only on each feature's order and AUC depends only on the ranking of predictions. So the choice of raw or log values below does not change it.

**Balance rerun**

| Item | Rule |
|---|---|
| Features | All 39 stored features at both cutoffs |
| SMD | Calculated on non-null stored values with no transforms, and these values drive the count and actions below. `log1p` SMDs for `txn_count_hist` and `spend_hist` are also shown for comparison with Phase 1, but do not count toward them |
| Null values | Report each feature's null share by group |
| Random-split range | Report how many features fall outside ±0.0088. No action follows from this count, because the features are correlated. |
| Action | Review any SMD above 0.05, and treat any above 0.1 as a concern |

## Phase 2 check results

All values are **Measured** from `notebooks/02_feature_engineering.ipynb`, and the tables are in `outputs/tables/`. `target` was not used.

### Treatment prediction

| Cutoff | Features | AUC | 95% CI |
|---|---:|---:|---:|
| Primary | 36 | 0.4982 | 0.4958 to 0.5008 |
| Primary | 39 | 0.4979 | 0.4954 to 0.5005 |
| Sensitivity | 36 | 0.4981 | 0.4956 to 0.5006 |
| Sensitivity | 39 | 0.4990 | 0.4966 to 0.5016 |

| Comparison | Difference | 95% CI |
|---|---:|---:|
| AUC(39) - AUC(36), primary cutoff | -0.0003 | -0.0021 to +0.0014 |
| AUC(39) - AUC(36), sensitivity cutoff (information only) | +0.0009 | -0.0007 to +0.0024 |
| Primary minus sensitivity, 36 features | +0.0001 | -0.0024 to +0.0027 |
| Primary minus sensitivity, 39 features | -0.0010 | -0.0037 to +0.0014 |

**Stop rule:** not triggered. Every AUC is below 0.52, and every interval includes 0.50.

**Express inclusion result: express points enter the Phase 3 model.** At the primary cutoff both AUCs are below 0.52 and AUC(39) - AUC(36) is -0.0003, within the 0.005 limit. The 39-feature AUC at the sensitivity cutoff is also below 0.52.

**Limit of the intervals:** they capture uncertainty from the evaluation sample, not from refitting the models.

### Balance on the final features

| Measure | Primary | Sensitivity |
|---|---:|---:|
| Features checked | 39 | 39 |
| Largest absolute SMD | 0.0130 | 0.0129 |
| Features above 0.05 (review) | 0 | 0 |
| Features above 0.1 (concern) | 0 | 0 |
| Features outside ±0.0088 | 1 | 2 |
| Largest gap in null share between groups | 0.06 points | 0.12 points |

- **Outside the random-split range:** `pre_issue_purchase_flg` at both cutoffs, and `days_since_last_purchase` at the sensitivity cutoff. No action follows, as the rules state.
- **Null shares:** the largest gap at each cutoff is on `avg_gap_days`: 2.01% treated and 2.07% control at the primary cutoff, and 2.93% and 3.05% at the sensitivity cutoff.
- **Phase 1 comparison only:** `log1p` SMDs are +0.0082 for `txn_count_hist` and +0.0095 for `spend_hist` at the primary cutoff, and +0.0084 and +0.0108 at the sensitivity cutoff. These match Phase 1, as do all ten variables shared with its balance table.

**How to read it:** these checks found no observed feature, alone or combined, that separates the groups. That supports the assignment wording already recorded, but it does not prove randomisation or rule out differences on unobserved characteristics.

## Where Phase 2 departs from the plan

| Plan | This analysis | Why |
|---|---|---|
| Optional product features, kept if they improve development results | Left out and moved to Future work, with no `03_product_features.sql` | Category spend shares would need the product-level amount that `purchase_sum` was locked over. Two `level_1` values cover 98% of spend. Adding them after Phase 3 locks its setup would mean redoing that lock. |
| Average items | Mean product rows per transaction, and distinct products across the history | `product_quantity` is 0 on 5.9% of labelled customers' product rows, and 99.7% of those rows have a positive amount, so summing quantity would undercount baskets |
| Time-of-day shares | Neutral recorded-hour bands | The recorded hours suggest a possible clock shift that no documentation settles |
| Treatment check with and without doubtful fields | Express points are the only tested field | `first_redeem_date` stays locked out, and Phase 1 already showed it holds post-treatment information |
| Treats doubtful fields as out of the primary model (rule 3), with express points to be checked in Phase 1 | Express points are not treated as doubtful, and their entry follows the inclusion rule above | They passed the Phase 1 checks, so the decision rests on a stated test |
| One feature table | A second table at the sensitivity cutoff, for checks only | The cutoff sensitivity logged in Phase 1 should also cover the final features |

## Phase 2 findings from validation

All values are **Measured** from `notebooks/02_feature_engineering.ipynb`.

- **Transaction key:** `(client_id, transaction_id)` is confirmed, with 8,045,229 distinct pairs against 8,045,201 distinct `transaction_id` values. `purchase_sum` and all four points fields are constant within every transaction.
- **Age:** the rule matches Phase 1 exactly, with 883 labelled customers invalid.
- **`pre_issue_purchase_flg`:** of the 23,532 customers flagged at the primary cutoff, 23,515 bought on the issue date itself and 17 on an earlier date. Only 5 customers have a same-day first purchase at or after the issue time. The flag mostly marks a first purchase recorded shortly before the issue time on the same day. That a card is recorded as issued after the sale that created it is an inference.
- **Sensitivity table:** 753 customers have no earlier purchase, and 154 cards were issued from 2019-03-12 to 2019-03-18. All 154 are among the 753.
- **Recency:** the longest `days_since_last_purchase` is 22 at the primary cutoff and 109 at the sensitivity cutoff. The 2019-02-24 pattern falls after the sensitivity cutoff, so differences between the two tables are partly mechanical.

## Phase 3 status

**Complete.** The setup is locked, and the project owner approved the recency check. Phase 3 builds the conventional "likely to purchase" ranking, `m1(X) = P(target = 1 given X, treatment_flg = 1)`, in `notebooks/03_response_vs_uplift.ipynb`. It produces the locked model setup and its metrics. It saves no model and uses no control or holdout rows. Results are in "Phase 3 results".

## Rules for Phase 3

These rules were written before any tuning ran. The commit that adds this section is the record of that order, and results are added in a later commit.

### Data

| Item | Rule |
|---|---|
| Customers | The 79,985 treated development customers, in the saved five folds: 15,998, 15,997, 15,997, 15,997 and 15,996 |
| Loading labels | One query, filtered to `split = 'development'` and `treatment_flg = 1`, so holdout and control labels are never loaded |
| Features | All 39 columns of `customer_features.parquet`, in stored order, including the three express features admitted by the Phase 2 inclusion rule |
| Row order | Sorted by `client_id` before folds are applied |
| Hard assertions | 79,985 rows, no holdout `client_id`, all rows treated, and feature columns equal to the locked Phase 2 list |

**Why row order is locked:** in a synthetic-data check on xgboost 3.4.1, changing only the training row order moved predictions by up to 0.099.

**Limit of reusing the saved folds:** the setup is chosen on the same rows that later produce the out-of-fold strategy results, and each tree count is chosen on the validation rows it is then scored on. Those results are therefore slightly optimistic. Tuning sees only treated log-loss, never an uplift metric, the out-of-fold view is secondary, and the holdout stays clean.

### Model settings

| Setting | Value |
|---|---|
| `objective` | `binary:logistic`, with no class weighting, so scores stay probabilities |
| `learning_rate` | 0.05 |
| `subsample` | 0.8 |
| `colsample_bytree` | 0.8 |
| `tree_method` | `hist` |
| Seed | `random_state=42` |
| Regularisation | `reg_lambda=1`, `reg_alpha=0`, `gamma=0`, the xgboost 3.4.1 defaults, stated explicitly |
| Threads | `n_jobs=8` |
| Missing values | Handled natively by XGBoost |

**Grid of eight settings:** `max_depth` of 2, 3, 4 or 6, crossed with `min_child_weight` of 10 or 100.

### Tree count

1. Train each setting in each fold up to a 1,500-tree cap, recording validation log-loss after every tree.
2. Average the curves across the five folds, and take the tree count with the lowest mean. The earliest count wins a tie.
3. If a setting's count lands on 1,500, rerun that setting once with a 3,000-tree cap, and use the rerun's count.
4. If it lands on 3,000, stop and escalate.

The Phase 4 refit on the full development set uses the same count on about 25% more rows, which is slightly conservative.

### Choosing the setting

Each setting is scored by its log-loss in each fold at its own locked tree count.

1. **Best:** the setting with the lowest mean log-loss across folds.
2. **Eligible:** for each setting, take its five paired fold differences against the best. It is eligible if the mean difference is at most `SE = SD of the five differences / sqrt(5)`, using the sample SD.
3. **Chosen:** the simplest eligible setting, by `max_depth` ascending, then `min_child_weight` 100 before 10, then fewer trees.

These two grid values identify each setting, so the tree-count step cannot change the choice here. It is recorded for completeness. With five folds this SE is rough, but the rule is fixed in advance.

### Performance

Reported on pooled out-of-fold predictions from the chosen setting, trained in each fold at its locked tree count.

| Item | Rule |
|---|---|
| Metrics | AUC and log-loss, each with a percentile 95% interval from 2,000 bootstrap resamples, stratified on `target`, seed 42, plus a per-fold table |
| Baseline | Log-loss from predicting each training fold's purchase rate for its validation fold |
| Stop rule | If the model's pooled log-loss is not below the baseline's, stop and investigate before Phase 4 |
| Limit | The intervals capture uncertainty from the evaluation sample, not from refitting the models |

### Calibration

| Item | Rule |
|---|---|
| Report | Ten equal-count bins with mean predicted and observed purchase rates, a plot, and a slope and intercept fitted together by logistic regression of `target` on the logit of the prediction |
| Flag | Slope outside 0.9 to 1.1, or any bin off by more than 2 points. These thresholds are judgement calls |
| If flagged | Report it and proceed without recalibrating, unless the project owner decides otherwise |
| Phase 4 | The same report runs on `m0` |

Recalibrating would not change the response ranking, but it would change `tau(X) = m1(X) - m0(X)`, so it is not applied by default.

### Leakage review

Strong recency effects are expected and do not show leakage on their own. The specific risk is that the undocumented outcome window overlaps the end of the purchase history.

**Stop and investigate before Phase 4 if any of these occur.** These thresholds are judgement calls.

| Check | Threshold | How it is measured |
|---|---|---|
| Feature gain | At least 50% of total gain | Each feature's share of total gain in each of the chosen setting's five fold models, averaged across the models |
| Single-feature AUC | At least 0.80 | `max(AUC, 1 - AUC)` across treated development rows, leaving out rows where the feature is null |
| Overall AUC | At least 0.90 | Pooled out-of-fold predictions |

**Descriptive check, with no automatic rule:** a table and plot of customer count and purchase rate by `days_since_last_purchase` from 0 to 22, among treated development customers. A smooth decline looks like habit, while a sharp jump at 0 or 1 days would suggest overlap. The project owner reviews this before Phase 4.

### Link to Phase 4

Phase 4 retrains `m1` within each fold and hard-asserts that its out-of-fold scores on treated rows match Phase 3's within 1e-9, using the same seed, folds, row order, feature order, `tree_method` and thread count. The comparison happens within one notebook run, so no scores are saved.

In the same synthetic-data check, repeating a fit and truncating a longer model to the same tree count both matched exactly, so the assertion is achievable. XGBoost returns 32-bit predictions, so this tolerance in effect requires an exact match.

### Order of work

1. **Stage 1:** add these rules to this log, ending at a commit.
2. **Stage 2:** after that commit, run the tuning and checks, then record the locked setup here and commit it before Phase 4.

## Where Phase 3 departs from the plan

| Plan | This analysis | Why |
|---|---|---|
| Select by five-fold log-loss | Simplest setting within one standard error of the lowest log-loss | Log-loss differences may be too small to separate settings reliably, and simpler models add less noise when subtracted in the T-Learner |
| Check AUC, log-loss and calibration | Adds intervals, a baseline with a stop rule, and calibration flags with a default action | The plan gave no failure condition |
| Review feature importance for anything suspicious | Three stop thresholds and a descriptive recency check | "Looks like leakage" needed a test fixed in advance |
| Calibration check on the response model | The same report also runs on `m0` in Phase 4 | `tau(X)` depends on both models |

## Phase 3 results

All values are **Measured** from `notebooks/03_response_vs_uplift.ipynb` on the 79,985 treated development customers, and the tables are in `outputs/tables/`. Control and holdout labels were not loaded.

### Locked setup

**`max_depth` 4, `min_child_weight` 10, 185 trees**, with the fixed settings listed in the rules above. Phase 4 uses this setup for both `m1` and `m0`.

| `max_depth` | `min_child_weight` | Trees | Mean log-loss | Difference from best | SE of difference | Eligible |
|---:|---:|---:|---:|---:|---:|---|
| 2 | 10 | 730 | 0.53492 | +0.00037 | 0.00012 | No |
| 2 | 100 | 726 | 0.53496 | +0.00041 | 0.00014 | No |
| 3 | 10 | 320 | 0.53485 | +0.00030 | 0.00011 | No |
| 3 | 100 | 345 | 0.53485 | +0.00030 | 0.00014 | No |
| **4** | **10** | **185** | **0.53455** | **Best** | | **Yes** |
| 4 | 100 | 214 | 0.53473 | +0.00018 | 0.00015 | No |
| 6 | 10 | 113 | 0.53480 | +0.00025 | 0.00019 | No |
| 6 | 100 | 126 | 0.53477 | +0.00022 | 0.00016 | No |

**How to read it:** no simpler setting came within one standard error, so the rule chose the best setting itself. Each gap exceeds its rough standard error but is very small, at most 0.0004, and the best setting does not win every fold. No setting reached the 1,500-tree cap, so no rerun was needed.

### Performance

| Measure | Value | 95% CI |
|---|---:|---:|
| AUC | 0.7801 | 0.7769 to 0.7832 |
| Log-loss | 0.5346 | 0.5317 to 0.5375 |
| Baseline log-loss | 0.6554 | 0.6554 to 0.6554 |
| Log-loss minus baseline | -0.1209 | -0.1237 to -0.1179 |

The stop rule was not triggered. Fold AUCs run from 0.7738 to 0.7864.

**Limits of the intervals:** they capture uncertainty from the evaluation sample, not from refitting the models. The baseline's interval is almost zero-width by construction, because stratifying on `target` fixes the number of buyers and non-buyers in every resample and the baseline gives each group nearly the same loss.

**What this does not show:** these metrics describe prediction of purchase among treated customers. They say nothing about whether the SMS changed anyone's behaviour.

### Calibration

| Measure | Result | Flag |
|---|---:|---|
| Slope | 1.0067 | Not raised |
| Intercept | -0.0036 | No threshold set |
| Largest bin gap | 0.96 points, in bin 4 | Not raised |

Nothing was recalibrated. The tenth bin has a mean predicted rate of 96.1% and an observed rate of 96.5%.

### Leakage review

| Check | Result | Stop threshold | Triggered |
|---|---:|---:|---|
| Largest gain share | 0.2779, `txn_count_60d` | At least 0.50 | No |
| Largest single-feature AUC | 0.7552, `txn_count_60d` | At least 0.80 | No |
| Overall out-of-fold AUC | 0.7801 | At least 0.90 | No |

The strongest features all measure purchase frequency or recency. Express points are weak: their largest gain share is 0.0079, and their largest single-feature AUC is 0.5144.

### Purchase rate by recency

This check is descriptive and has no automatic rule. The table is `outputs/tables/response_recency.csv`, and the plot is `outputs/figures/response_recency.png`.

| Days since last purchase | Customers | Purchase rate | 95% CI |
|---:|---:|---:|---:|
| 0 | 14,165 | 84.5% | 83.9% to 85.1% |
| 1 | 8,752 | 79.9% | 79.1% to 80.8% |
| 2 | 7,423 | 75.3% | 74.4% to 76.3% |
| 3 | 7,335 | 68.7% | 67.7% to 69.8% |
| 10 | 3,666 | 44.6% | 43.0% to 46.2% |
| 11 | 2,016 | 49.1% | 46.9% to 51.2% |
| 12 | 1,448 | 49.3% | 46.7% to 51.9% |
| 13 | 1,254 | 48.8% | 46.0% to 51.6% |
| 14 | 1,632 | 41.5% | 39.1% to 43.9% |

- **At 0 and 1 days:** the rate falls by about 4.6 points a day to 2 days, then by 6.6 points to 3 days, with no sharp jump at 0 or 1 days. This pattern does not suggest that the outcome window overlaps the end of the purchase history, but it cannot rule that out.
- **At 11 to 13 days:** the rate steps up by about 4 points and then down by about 7, and the intervals at 10 and 11 days do not overlap. These customers last bought from 2019-03-05 to 2019-03-07, just before International Women's Day on 2019-03-08, a public holiday in Russia. A holiday effect is an inference, not something this data establishes. The step is far from the cutoff, so it does not suggest window overlap.
- **Coverage:** the rule named 0 to 22 days, but no treated development customer has a value of 22.

**Project owner's review:** approved on 2026-11-08 to proceed to Phase 4. The step at 11 to 13 days stays documented as unexplained. The review does not rule out overlap with the outcome window.
