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

## Phase 4 status

**Complete.** Results are in "Phase 4 results". Phase 4 builds the T-Learner in `notebooks/03_response_vs_uplift.ipynb`: `m1(X) = P(target = 1 given X, treatment_flg = 1)`, `m0(X) = P(target = 1 given X, treatment_flg = 0)` and `tau(X) = m1(X) - m0(X)`. It produces scores for every labelled customer from models that did not train on them. It does not evaluate targeting.

An individual `tau(X)` is **Estimated from the model**. It is not a measured effect on that customer, and a negative score does not show that the SMS harmed anyone.

## Rules for Phase 4

These rules were written before any Phase 4 score existed. The commit that adds this section is the record of that order, and results are added in a later commit.

### Data

| Item | Rule |
|---|---|
| Development customers | 160,031: 79,985 treated and 80,046 control, all sorted by `client_id` |
| Control fold sizes | 16,009, 16,009, 16,009, 16,009 and 16,010. Treated fold sizes are as in Phase 3 |
| Development labels | One query, filtered to `split = 'development'`. It asserts that no holdout `client_id` is present |
| Holdout customers | 40,008. One query reads `client_id` and features only, from `customer_features.parquet` and `splits.parquet`. It does not touch `uplift_train.parquet`, and it asserts that neither `treatment_flg` nor `target` is present |
| Features | The locked list of 39, in stored order |
| Order in the notebook | Phase 4 runs after every Phase 3 cell, so Phase 3 still sees only treated development labels |

**Boundary with evaluation:** Phase 4 never compares `tau` with `target`, on any rows. `target` is used only to train the models, to assess `m0` as a purchase predictor on control rows, and to calculate the development interval for the mean `tau` check below. All of these use development rows only. Whether uplift targeting works is left to the evaluation phase.

### Models

| Item | Rule |
|---|---|
| Setup | The Phase 3 locked setup for both models: `max_depth` 4, `min_child_weight` 10, 185 trees, the fixed settings and seed 42 |
| Out-of-fold scoring | In each fold, train `m1` on the treated training rows and `m0` on the control training rows, then score every validation row in both arms with both models |
| Match with Phase 3 | `m1` out-of-fold scores on treated rows must match `phase3_m1_scores` within 1e-9, or the notebook stops |
| No in-sample scoring | Assert that each development row is scored once, in its own fold, by models whose training rows exclude it |
| Refit | Train `m1` on all 79,985 treated and `m0` on all 80,046 control development customers, at 185 trees, then score the holdout |
| Recalibration | None by default, as in Phase 3. `tau` is the plain difference of the two scores |

### Checks on `m0`

`m0` gets the same reports and thresholds as `m1`, on pooled out-of-fold scores for the 80,046 control development customers.

| Check | Rule | If triggered |
|---|---|---|
| Performance | AUC and log-loss, each with a percentile 95% interval from 2,000 bootstrap resamples, stratified on `target`, seed 42, plus a per-fold table | Report |
| Baseline | Log-loss must be below that of predicting each training fold's control purchase rate | Stop and investigate |
| Largest gain share | At least 0.50, averaged across the five fold models | Stop and investigate |
| Largest single-feature AUC | At least 0.80, using `max(AUC, 1 - AUC)` and leaving out null rows | Stop and investigate |
| Overall AUC | At least 0.90 | Stop and investigate |
| Calibration | Ten equal-count bins, slope and intercept. Flag a slope outside 0.9 to 1.1 or any bin off by more than 2 points | Report and proceed, with no recalibration, unless the project owner decides otherwise |

**Left out on purpose:** a recency table for control customers, because comparing it with the treated table would show the SMS effect by recency before the segment rules are locked, and a tree-count curve for `m0`, because the setup is locked and no action could follow.

### Mean `tau`

Mean `tau` must fall within the **development interval**, on out-of-fold rows and separately on holdout rows. Nothing is rounded, and both sides are compared as probabilities.

**Development interval:** the unpooled Wald 95% interval for the treated-minus-control purchase rate difference, using `scipy.stats.norm.ppf(0.975)` as in Phase 1, on the 160,031 development customers only. The notebook calculates it, and the Stage 2 results record it. No holdout outcome enters this check.

If either mean falls outside, stop and look for a pipeline bug, then bring the result to the project owner. Nothing is corrected automatically, and any fix is recorded in this log.

The split was stratified on treatment by target, so the development difference should be almost identical to the Phase 1 difference. With fewer customers, the interval should be about 12% wider.

**Limit:** this is a rough check. The interval reflects sampling uncertainty in the development difference, not pipeline error, so a bug that shifts mean `tau` by a few tenths of a point could pass, and one that only reorders scores does not move the mean at all. The row alignment assertions under "Saved files" cover reordering.

### Arm balance

Evaluating targeting compares treated and control customers inside a score-selected group, so selecting on a score must not also select on arm. This check uses `treatment_flg` but not `target`, on out-of-fold rows.

| Measure | Applies to | Stop and investigate if |
|---|---|---|
| Absolute standardised mean difference between arms | `m1`, `m0`, `tau` | At least 0.05 |
| Treated SD divided by control SD | `m1`, `m0`, `tau` | Outside 0.9 to 1.1 |
| Treated share of the top 20% | `m1`, `tau` | Outside 48% to 52%, against 49.98% overall |

The top 20% comes from `select_top_k`, described below, and is 32,006 customers here. These thresholds are judgement calls. The check catches scores that differ by arm. It cannot catch scores misaligned independently of arm, or reliably catch in-sample scoring, and those have their own assertions.

### Top-K selection

Every top-K group comes from one shared function, `select_top_k(client_ids, scores, percent)` in `notebooks/targeting.py`. The Phase 4 balance check and score reports use it, and so do the Phase 5 balance check and Uplift@K.

It has two steps, also available separately: `score_ranks(client_ids, scores)` checks the inputs and ranks each customer, and `select_by_rank(ranks, percent)` applies the group size.

| Item | Rule |
|---|---|
| Sort order | Score descending, then `client_id` ascending for ties |
| Group size | `percent x n / 100` rounded to the nearest whole number, with exact halves rounded up, calculated in whole-number arithmetic |
| Sizes at 20% | 32,006 of the 160,031 out-of-fold rows and 8,002 of the 40,008 holdout rows |
| Rejected inputs | IDs that are not strings, including nulls; duplicate IDs; scores that are not finite; mismatched lengths; a percent that is not a whole number from 1 to 100; and a group of no customers |
| Bootstrap resamples | A resample repeats customers, which `select_top_k` rejects. Each one uses `select_by_rank` on the resampled ranks, so the same order and size rule apply at the resample's size |
| Use in a notebook | The setup cell adds `notebooks/` to `sys.path`, and known-answer checks on the function run first, including both sizes above |

**Other shared code:** Phases 4 and 5 both need the freeze and arm-balance checks, so these also go in `notebooks/targeting.py`. They are added in Stage 2, with known-answer checks, and neither phase keeps its own copy.

| Function | What it does |
|---|---|
| `holdout_score_hash(client_ids, m1_scores, m0_scores)` | The exact SHA-256 defined under "Holdout score freeze" |
| `check_freeze(recorded_hash, reference, client_ids, expected_client_ids, m1_scores, m0_scores, allow_first_run)` | Applies the freeze state table and returns its result. It calculates the hash from the scores passed in, so a stale value cannot pass. Phase 4 allows a first run, and Phase 5 does not |
| `arm_balance(client_ids, treatment, scores)` | The three arm-balance measures, with the top 20% from `select_top_k`. A score with no spread in one arm stops, because its SMD would otherwise be undefined and pass unnoticed |
| `assert_exact_tau(m1_scores, m0_scores, tau)` | The exact `tau` assertion required on every load of a score file. Added in Stage 2, because both phases need it |

**Comparing with scikit-uplift:** in version 0.5.1, `uplift_at_k` with a fractional `k` rounds down with `int(n * k)`, giving 8,001 holdout rows at 20%, and its reversed sort puts tied rows in the opposite order. It also rejects a whole-number `k` at or above the row count. The plan's cross-check must therefore pass the `select_top_k` group size as a whole-number `k`, allow for ties, and cover budgets below 100% only.

### Score reports

These are report only.

| Report | Rows |
|---|---|
| Histogram of `tau`, with minimum, maximum and the 1st, 5th, 10th, 25th, 50th, 75th, 90th, 95th and 99th percentiles | Out-of-fold and holdout |
| Share of customers with `tau` below zero | Out-of-fold and holdout |
| Spearman correlation of `m1` and `tau`, with no interval | Pooled out-of-fold, each fold and holdout |
| Mean and SD of `tau`, share below zero, and share of the pooled top 20% of `tau`, from `select_top_k` | Each fold |

**Flag for the project owner:** out-of-fold scores come from five different model pairs, so one fold could dominate a pooled ranking. If any fold's share of the pooled top 20% is outside 15% to 25%, bring it to the project owner before the evaluation phase. The notebook does not stop.

### Saved files

| File | Contents | In Git |
|---|---|---|
| `data/processed/scores_oof.parquet` | `client_id`, `fold`, `m1_score`, `m0_score`, `tau` | No |
| `data/processed/scores_holdout.parquet` | `client_id`, `m1_score`, `m0_score`, `tau` | No |
| `models/m1_refit.ubj`, `models/m0_refit.ubj` | The two refit models. Fold models are not saved | No |
| `outputs/tables/holdout_scores_reference.csv` | `m1_score` and `m0_score` at 6 decimals, in sorted `client_id` order, with no labels or client IDs | Yes, with the Stage 2 results, before the evaluation phase |

- **Types:** scores stay as XGBoost's 32-bit values, and `tau` is their exact 64-bit difference.
- **No labels:** neither score file holds `treatment_flg` or `target`.
- **Coverage:** assert that all 200,039 customers appear exactly once across the two score files.
- **Row alignment:** reload each saved score file, join it to the features by `client_id`, and rescore with both models. The result must equal the saved scores exactly. Neither mean `tau` nor arm balance can catch scores attached to the wrong customer.
  - **Out-of-fold rows:** rescored in the same run, in both arms, before the fold models are discarded, because they are not saved.
  - **Holdout rows:** rescored from the saved refit models, reloaded from the staging folder described under "Holdout score freeze".
- **`tau`:** every load of a score file, in Phase 4 and Phase 5, asserts that `tau` equals the 64-bit `m1_score` minus the 64-bit `m0_score` exactly. The freeze and the rescore cover only the two model scores, and `tau` is what gets ranked.

### Holdout score freeze

The exact SHA-256 of the holdout scores is recorded in this log. It is calculated over UTF-8 text with one line per customer, in ascending `client_id` order: `client_id,m1,m0` followed by `\n`. `m1` and `m0` are the lowercase hex of the 32-bit big-endian float scores, so values must be cast to 32 bits before hashing. `tau` follows from those two scores.

**Order within a run,** so a stop never overwrites existing files:

1. Score the holdout in memory and compare with the freeze record, before any table is built from holdout scores. Then run every other stop check and compare the values quoted in this log. A warned run skips that comparison, because tiny differences could change a rounded value.
2. Write the score files and refit models to a staging folder, `data/processed/phase4_staging/`, and run the row alignment assertions on those copies.
3. Move them to their final paths. On a first run only, write the reference file last.

A rerun never changes the reference file or the recorded hash, so every run is measured against the same committed record and differences cannot build up. A warned run's scores do replace the local score files, because a clean environment has none.

The states below are tested in this order, and the first match applies.

| State | Action |
|---|---|
| `client_id` values are not exactly the sorted holdout IDs in `splits.parquet` | Stop and investigate. The reference file has no IDs and is compared by position, so this check protects that comparison |
| No recorded hash and no reference file | First run. Once every check passes, write the reference file and report the hash for this log |
| A reference file with no recorded hash | Stop. This can only arise before the Stage 2 commit. Delete the uncommitted file and rerun as a first run |
| A recorded hash with no reference file | Stop and investigate |
| The row count differs from the reference file | Stop and investigate |
| The recorded hash matches | Proceed |
| The hash differs, and the largest absolute difference from the reference file in `m1_score` or `m0_score` is at most 1e-5 | Warn and proceed |
| The difference is larger | Stop and investigate |

**Replacing the record:** before any holdout outcome is opened, the hash and reference file may be replaced only for a fix the project owner approves. This log then records the old hash, the new hash and the reason, in a commit. After a holdout outcome is opened, they are never replaced.

**Why not a rounded hash:** hashes have no tolerance. One score crossing a rounding boundary changes the whole hash, so a harmless numerical difference would almost certainly stop the run.

**Limits:**

- **Tolerance:** 1e-5 allows for tiny numerical differences, and it has not been tested across machines. Different hardware could change a split choice and move scores by more than that, which would stop the run. A clean rerun on another machine is therefore possible but not guaranteed to pass. After a warning, `tau` can differ by up to 2e-5, which can change who falls just inside a top-K group, so results from those scores could differ slightly from a run on the recorded ones.
- **Meaning:** the freeze shows whether holdout scores changed from the committed record. It does not show why they changed.

### Order of work

1. **Stage 1:** add these rules to this log, ending at a commit.
2. **Stage 2:** after that commit, build and run the Phase 4 cells, and record the results and the hash here. A second full run must then match the recorded hash. Commit the results with the reference file before the evaluation phase.

## Rules carried into Phase 5

These are written now because they follow from Phase 4 choices, and they apply in this order before any holdout outcome is computed.

1. **Holdout score freeze:** `scores_holdout.parquet` must pass the freeze rule above when it is first loaded, because the results depend on the frozen scores and that file is not in Git. Phase 5 only compares. A missing hash or reference file is a stop rather than a first run, and it never writes or replaces either.
2. **Arm balance:** the check above runs again on holdout scores, with the same measures and thresholds. Phase 4 does not load holdout `treatment_flg`, so this is the first check of the holdout arms. The query for it reads `treatment_flg` but not `target`. The top 20% comes from `select_top_k` and is 8,002 customers.

If either triggers, stop and investigate before opening any holdout outcome.

**Same selection rule:** Uplift@K at every budget must select customers with `select_top_k`, so at the 20% budget the group checked for balance is the group evaluated. This balance check does not cover the other budgets.

## Future work

Ideas kept out of the frozen scope, to carry into the README's "Future work" section:

- **Product features:** moved here in Phase 2, for the reasons in "Where Phase 2 departs from the plan".
- **Ranking stability across fold model pairs:** the five fold pairs could score the same holdout customers, to measure how much `tau` rankings change with the training rows. This adds no validity fix, so the project owner kept it out of Phase 4.

## For the README

When the README is written, it must state that `outputs/tables/holdout_scores_reference.csv` holds label-free, ID-free model scores and serves as the holdout freeze record.

## Where Phase 4 departs from the plan

| Plan | This analysis | Why |
|---|---|---|
| Score the holdout without opening its evaluation results | Holdout scoring loads features only, with no labels | No label is needed to score, and a query that never touches the label file is easy to defend |
| Check that mean `tau` is broadly close to the ATE | Mean `tau` must fall within the same interval calculated on development rows only, or the notebook stops | "Broadly close" needed a test fixed in advance, and this one uses no holdout outcome |
| Calibration report on `m0`, from the Phase 3 rules | `m0` also gets the performance report, baseline stop and leakage stops | `tau` depends equally on both models |
| No arm-balance check on scores | Added on out-of-fold rows, and carried into Phase 5 for holdout rows | This protects validity: selecting on a score must not also select on arm |
| Review the score distribution and rank correlation | Reports fixed in advance, with a per-fold table and one flag | Out-of-fold scores come from five model pairs, so a pooled ranking could favour one fold |
| Save models | Only the two refit models are saved | Fold models can be regenerated, and their scores are already saved |
| Not in the plan | Holdout score hash and a committed reference file | Shows whether holdout scores changed before the evaluation, while tolerating tiny numerical differences on a rerun |
| Not in the plan | Assertions that saved scores match a rescore joined by `client_id` | Scores attached to the wrong customer would pass every other check |
| Code lives in SQL files and five numbered notebooks | Adds one helper file, `notebooks/targeting.py`, holding top-K selection and the freeze and arm-balance checks. It is not a package | Two notebooks need the same rules, and a second copy could drift |

## Phase 4 results

Values for `m0`, the development interval and arm balance are **Measured** from `notebooks/03_response_vs_uplift.ipynb`, on out-of-fold development rows. Values for `tau` are **Estimated from the model**. Tables are in `outputs/tables/`. No holdout label was loaded.

The Phase 3 performance, calibration and importance code became functions so that `m0` uses the same code. Phase 3's pinned values still pass, so its results did not change.

### Holdout score freeze record

**Holdout scores SHA-256:** `b40d79c605f5447f7b0ba94eafbe0e30f1651aa0fcb266356a4f2b3fe33b6bc2`

A second full run of the notebook on the same machine reproduced this hash exactly. The notebook reads the current hash from this exact label. If it is ever replaced, the old hash is recorded under a different label, "Superseded holdout hash". The reference file is `outputs/tables/holdout_scores_reference.csv`, with 40,008 rows.

### Match with Phase 3

`m1` out-of-fold scores on the 79,985 treated rows match Phase 3 exactly: the largest difference is 0.0, against a tolerance of 1e-9.

### `m0`

| Measure | Value | 95% CI |
|---|---:|---:|
| AUC | 0.7817 | 0.7784 to 0.7848 |
| Log-loss | 0.5452 | 0.5423 to 0.5483 |
| Baseline log-loss | 0.6717 | 0.6717 to 0.6717 |
| Log-loss minus baseline | -0.1265 | -0.1294 to -0.1234 |

Fold AUCs run from 0.7779 to 0.7863. The intervals capture uncertainty from the evaluation sample, not from refitting the models. As in Phase 3, the baseline's interval is almost zero-width by construction.

| Check | Result | Threshold | Triggered |
|---|---:|---:|---|
| Calibration slope | 1.0007 | Flag outside 0.9 to 1.1 | No |
| Calibration intercept | -0.0007 | No threshold set | |
| Largest calibration bin gap | 0.45 points, in bin 5 | Flag above 2 points | No |
| Largest gain share | 0.2950, `txn_count_60d` | Stop at 0.50 | No |
| Largest single-feature AUC | 0.7621, `txn_count_60d` | Stop at 0.80 | No |
| Overall out-of-fold AUC | 0.7817 | Stop at 0.90 | No |

Nothing was recalibrated. The strongest features measure purchase frequency, as they do for `m1`. Express points are weak: their largest gain share is 0.0012, and their largest single-feature AUC is 0.5057.

**What this does not show:** these metrics describe prediction of purchase among control customers. They say nothing about whether the SMS changed anyone's behaviour.

### Mean `tau`

| Item | Points |
|---|---:|
| Development treated rate | 63.65% |
| Development control rate | 60.33% |
| Development difference | +3.32 |
| Development interval, 95% | +2.85 to +3.80 |
| Mean `tau`, out-of-fold | +3.19 |
| Mean `tau`, holdout | +3.24 |

Both means fall inside the interval, so the stop rule was not triggered. Both sit a little below the development difference, by 0.13 and 0.09 points. The limit stated in the rules applies: this check cannot detect a small shift in the mean.

### Arm balance

| Score | SMD | Treated SD / control SD | Treated share of the top 20% |
|---|---:|---:|---:|
| `m1` | +0.0061 | 0.9995 | 50.33% |
| `m0` | +0.0063 | 0.9990 | Not applied |
| `tau` | -0.0023 | 0.9924 | 49.64% |

No stop rule was triggered. These are out-of-fold rows only, and the same check runs on holdout scores in Phase 5.

### Distribution of `tau`

All values are in points, apart from customer counts and the share below zero.

| Rows | Customers | Mean | SD | Below zero | Minimum | 5th percentile | Median | 95th percentile | Maximum |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Out-of-fold | 160,031 | +3.19 | 4.79 | 21.41% | -25.47 | -2.99 | +2.50 | +11.23 | +60.00 |
| Holdout | 40,008 | +3.24 | 4.71 | 19.38% | -20.38 | -2.55 | +2.50 | +11.06 | +58.34 |

The full percentiles are in `outputs/tables/tau_summary.csv`, and the chart is `outputs/figures/tau_distribution.png`.

**How to read it:** these are model estimates, not measured effects, and a score below zero does not show that the SMS harmed anyone. The spread includes model noise, and nothing in this phase shows how much of it reflects real differences between customers. The holdout has fewer scores below zero, 19.38% against 21.41%. Its models trained on about 25% more rows, which may reduce noise, but that explanation is an inference.

### By fold

| Fold | Mean `tau` (points) | SD (points) | Below zero | Share of the pooled top 20% | Spearman, `m1` and `tau` |
|---:|---:|---:|---:|---:|---:|
| 1 | +3.22 | 4.80 | 22.0% | 20.0% | -0.143 |
| 2 | +3.12 | 4.96 | 22.6% | 20.3% | -0.074 |
| 3 | +3.14 | 4.64 | 21.7% | 19.4% | -0.185 |
| 4 | +3.27 | 4.89 | 20.7% | 20.8% | -0.144 |
| 5 | +3.20 | 4.66 | 20.0% | 19.5% | -0.113 |

No fold's share falls outside 15% to 25%, so nothing was flagged, and no fold dominates the pooled ranking.

### Rank correlation of `m1` and `tau`

The Spearman correlation is -0.131 pooled out-of-fold and -0.128 on the holdout, with no interval. The two scores therefore rank customers differently, and customers more likely to buy tend to have slightly lower estimated uplift. This does not show which ranking finds more incremental purchasers. Both scores also share `m1`, so some of this correlation can come from shared noise.

### What the checks cover

- **Scoring:** every fold model trains through one function, which asserts that its training rows come from one arm and share no `client_id` with the fold it scores. Every development row is scored once, in its own fold. All 200,039 customers appear exactly once across the two score files.
- **Row alignment:** rescoring each saved file after a join by `client_id` reproduced its scores exactly, and every `tau` is the exact 64-bit difference.
- **Shared code:** the known-answer checks on `notebooks/targeting.py` passed, including the two carried review items that reject bad ranks and non-numeric scores.

## Phase 5 status

**Complete.** The rules were committed in `202c311` before any targeting result existed, and the analysis was locked in `8c468b5` before any holdout outcome was opened. Out-of-fold results are under "Phase 5 development results" and holdout results under "Phase 5 holdout results". Phase 5 asks whether ranking by `tau` finds more incremental purchasers than ranking by `m1`, in `notebooks/04_policy_evaluation.ipynb`, using the scores frozen in Phase 4. The models, features and scores are not changed.

## Rules for Phase 5

These rules were written before any targeting result existed, on out-of-fold or holdout rows. The commit that adds this section is the record of that order. The "Rules carried into Phase 5" above still apply.

### Order of work

1. **Stage 1, rules:** add this section to this log, ending at a commit.
2. **Stage 2, development:** on out-of-fold development rows only, run the sanity checks, the strategy comparison, the disagreement analysis and the RFM cut points, then record them under "Phase 5 development results" and "Phase 5 lock record". This ends at a commit, which is the **lock commit**.
3. **Stage 3, holdout:** after the lock commit, run the freeze check, the holdout arm balance, the holdout evaluation once and the segment effects, then record the results. This ends at a commit.

Stage 2 results cannot change any choice in this section. If a Stage 2 check stops, the code is fixed and the rules stay as written. If a rule itself proves unworkable, it can be changed only with the project owner's approval, before Stage 3, with the old rule, the new rule and the reason recorded here.

### Primary comparison

| Item | Rule |
|---|---|
| Rows | The 40,008 holdout customers |
| Statistic | Uplift@20 of the uplift strategy minus Uplift@20 of the response strategy, in percentage points |
| Alongside it | The same difference in incremental purchasers per 100,000 customers, `100,000 x 0.20 x difference`, so 1 point is 200 per 100,000 |
| Interval | Two-sided 95% paired percentile bootstrap interval, as set out under "Bootstrap" |
| Decision | Applied only to this comparison, as in the table below |

| Paired 95% interval for uplift minus response | Conclusion |
|---|---|
| Entirely above zero | Uplift targeting performed better at the 20% budget |
| Includes zero, including an end exactly at zero | The evidence does not separate the two strategies at this budget |
| Entirely below zero | Response targeting performed better at the 20% budget |

A two-sided 95% interval entirely above zero corresponds to a one-sided test of H0 at 2.5%.

**Expected precision, Estimated before any result:** the interval on the difference should be about ±3 points wide, from ±2.8 to ±3.0 for overlap of 0% to 15% between the two top-20% lists. A true difference has an 80% chance of producing an interval entirely above zero only if it is about 4.0 to 4.3 points or more, for that same overlap range, so "does not separate" is a likely outcome. Assumptions: purchase rates in each top 20% near the overall development rates (63.65% treated, 60.33% control), an even arm split within each list, and customers on both lists cancelling out. The Phase 4 Spearman correlation of -0.128 between `m1` and `tau` on the holdout suggests low overlap.

### Strategies and metrics

| Strategy | Selection | Budgets |
|---|---|---|
| Random | Expected value of random targeting, below | 5%, 10%, 20%, 30% |
| Response | Highest `m1_score`, through `select_top_k` | 5%, 10%, 20%, 30% |
| Uplift | Highest `tau`, through `select_top_k` | 5%, 10%, 20%, 30% |
| Contact everyone | All rows | 100% |

- **Uplift@K:** within the top K%, the treated purchase rate minus the control purchase rate, as in scikit-uplift's `overall` strategy. A group with no treated or no control rows stops the run.
- **Group sizes:** from `select_top_k`. On the holdout they are 2,000, 4,001, 8,002 and 12,002 at 5%, 10%, 20% and 30%. On the out-of-fold rows they are 8,002, 16,003, 32,006 and 48,009.
- **Incremental purchasers per 100,000:** `100,000 x K x Uplift@K`. For contact everyone, `100,000 x` the overall difference.
- **Random:** its value is the overall treated-minus-control difference on the same rows, which is the expected Uplift@K of a random top K% at any budget. In each bootstrap resample it is that resample's overall difference. It is labelled "expected value of random targeting", and its interval leaves out the noise of a single random draw, which a real random campaign would also have.
- **Contact everyone:** the same overall difference, at 100%.
- **Not a second campaign effect:** on holdout rows, Random and contact everyone use the holdout's overall difference only as the reference point for strategies on the same rows. The campaign effect remains the Phase 1 difference on all 200,039 customers, in line with the Phase 1 decision of no separate holdout estimate, and the holdout figure is never reported as the campaign effect.
- **Qini and AUUC:** `qini_auc_score(y_true, uplift, treatment)` with its default `negative_effect=True`, and `uplift_auc_score(y_true, uplift, treatment)`, from scikit-uplift 0.5.1. Both are normalised by scikit-uplift, so random ranking scores near zero. They are computed for the response and uplift strategies, use the score values directly, and leave ties to scikit-uplift rather than to `select_top_k`.
- **Curves:** Qini and uplift curves for the response and uplift strategies, with the random line, are drawn with Matplotlib from `qini_curve` and `uplift_curve` in `sklift.metrics`. `sklift.viz` fails to import with the installed scikit-learn, because `check_matplotlib_support` is missing, so it is not used.

### Results reported, and how they are labelled

On holdout rows and, separately, on pooled out-of-fold rows:

- Uplift@K and incremental purchasers per 100,000 for each strategy and budget, plus contact everyone, each with its interval
- Paired differences for uplift minus response, uplift minus random and response minus random, at each budget
- Qini and AUUC for the response and uplift strategies, each with its interval, plus the paired uplift minus response difference

| Result | Label |
|---|---|
| Holdout, uplift minus response at 20% | **Primary**, with the decision rule |
| Every other result at 10%, 20% or 30%, and every Qini and AUUC result | **Secondary** |
| Every result at 5% | **Exploratory** |

Secondary and exploratory results get no multiplicity correction and no conclusion wording, and none of them can override the primary result. Any disagreement between holdout and out-of-fold results is reported as it is.

**Out-of-fold view:** the main development view ranks all 160,031 pooled out-of-fold rows together, because Phase 4 found that no fold dominates the top 20%. A per-fold table adds, for each fold, Uplift@20 for each strategy and their difference, ranking each fold's own rows with `select_top_k`. That table is report only, with no interval and no stop rule.

All Uplift@K and Qini values are **Measured** on the stated rows. Contact everyone and Random are **Measured** overall differences.

### Bootstrap

| Item | Rule |
|---|---|
| Resamples | Exactly 2,000 for every interval, with no increase if results look unstable |
| Random numbers | A new `numpy.random.default_rng(42)` for each evaluation set, used for these resamples and nothing else |
| Stratification | Each resample draws, with replacement, as many treated rows as the set has treated rows and as many control rows as it has control rows |
| Shared resamples | The loop runs one resample at a time. Each resample's indices are drawn once and used for every strategy, budget and metric before the next resample is drawn, so every difference is paired and the indices are never all held in memory |
| Selection in a resample | Each score's ranks come from `score_ranks` on the full set. A resample uses `select_by_rank` on the resampled ranks, so it takes the top K% of its own rows. A helper may sort once and take several budgets, if a known-answer check shows it gives exactly the `select_by_rank` groups |
| Interval | The 2.5th and 97.5th percentiles from `numpy.percentile` with its default method. The point estimate comes from the original rows |

**Limit:** the intervals capture uncertainty from the evaluation sample, not from refitting the models.

### Sanity checks

These run on out-of-fold rows in Stage 2 and on holdout rows in Stage 3, before the strategy results are reported.

| Check | Rule | If it fails |
|---|---|---|
| Shuffle check | At each budget, 1,000 random orderings from a new `numpy.random.default_rng(42)` for each evaluation set, kept apart from the bootstrap generator, each passed to `select_by_rank` as ranks. The mean Uplift@K must be within 4 Monte Carlo standard errors of the overall difference on the same rows, where one standard error is the SD across the shuffles divided by √1000 | Stop and investigate |
| Match with scikit-uplift | For the response and uplift strategies at each budget, `uplift_at_k(y_true, -ranks, treatment, strategy='overall', k=size)` must equal the custom Uplift@K within 1e-12. `-ranks` contains no ties, so scikit-uplift's reversed sort keeps the `select_top_k` order, and the whole-number `k` avoids its rounding down | Stop and investigate |

Because every generator is created where it is used and never shared, skipping or reordering a step cannot change any draw.

This replaces "allow for ties" in "Comparing with scikit-uplift" above. The shuffle check tests the selection and Uplift@K code. It does not test the models.

### Arm balance at other budgets

The Phase 4 rule stays as written: SMD, SD ratio and a 48% to 52% treated share of the top 20%. For `m1` and `tau` at 5%, 10% and 30%, the treated share must be within 3.5 binomial standard errors of 50% at that group size, where one standard error is `sqrt(0.25 / size)`.

| Budget | Holdout band | Out-of-fold band |
|---|---:|---:|
| 5% | ±3.91 points | ±1.96 points |
| 10% | ±2.77 points | ±1.38 points |
| 30% | ±1.60 points | ±0.80 points |

Outside the band, stop and investigate. It runs on out-of-fold rows in Stage 2 and on holdout rows in Stage 3, using `treatment_flg` but not `target`. A fixed 48% to 52% band would trigger by chance about 7% of the time at the 5% holdout size.

This replaces "This balance check does not cover the other budgets" in "Rules carried into Phase 5" above. The bands are centred on 50%, as the project owner chose. Both evaluation sets have an overall treated share of 49.98%, so the offset is 0.02 points.

### Disagreement analysis

This uses pooled out-of-fold rows only, and there is no holdout version.

- **Higher or lower:** "higher" is the top 50% of each score from `select_top_k`, so ties at the median follow the shared rule. That is 80,016 customers per score.
- **Quadrants:** as in the plan, with these labels:

| | Lower estimated uplift | Higher estimated uplift |
|---|---|---|
| **Higher purchase likelihood** | Likely buyers, less apparent SMS effect | Likely buyers, more apparent SMS effect |
| **Lower purchase likelihood** | Less likely buyers, less apparent SMS effect | Possible persuadables |

- **For each quadrant:** customer count, treated and control purchase rates, and observed uplift with an unpooled Wald 95% interval.
- **Profile:** the mean and median of `days_since_last_purchase`, `txn_count_hist` and `spend_hist` in each quadrant, with no tests.
- **List overlap:** at each budget, the share of the uplift list that is also in the response list. The two lists are the same size, so the share is the same in both directions.

These are model-defined groups. They do not identify individual persuadable customers.

### RFM segments

| Item | Rule |
|---|---|
| Recency | `days_since_last_purchase`. A lower value is more recent |
| Frequency | `txn_count_hist` |
| Monetary | `spend_hist` |
| Cut points | The 1/3 and 2/3 quantiles of each variable on the 160,031 development rows, from `numpy.quantile` with its default method, calculated in Stage 2 without outcomes |
| Tertiles | 1 if the value is at most the first cut point, 2 if above it and at most the second, 3 if above the second. Tied customers share a tertile, so sizes can differ, and they are reported |
| Recency groups | Tertile 1 is "Recent", 2 is "Moderately recent" and 3 is "Least recent" |
| Higher frequency and monetary value | The mean of the frequency and monetary tertiles is above 2. A mean of exactly 2 counts as lower |
| Missing values | None are expected, since every labelled customer has a purchase on or after 2019-02-24. Any null stops the run |
| Applied to | All 200,039 customers, using the development cut points |

| | Lower frequency and monetary value | Higher frequency and monetary value |
|---|---|---|
| **Recent** | Segment 1 | Segment 2 |
| **Moderately recent** | Segment 3 | Segment 4 |
| **Least recent** | Segment 5 | Segment 6 |

**Fallback, set in advance:** if any tertile of recency, frequency or monetary value holds under 20% or over 50% of development rows, that variable uses rank-based tertiles instead. Development rows are sorted by value ascending, then `client_id` ascending. Rank `r`, counted from 0, goes to tertile `floor(3r / 160,031) + 1`. The cut points become the `(value, client_id)` pairs of the last development customer in tertiles 1 and 2. Every customer is placed by comparing their own `(value, client_id)` with those pairs in that order. Any variable that uses the fallback is logged under "Phase 5 lock record". Recency covers only 0 to 22 days, so it is the most likely to need it. **Limit:** under the fallback, customers with the same value can fall in different tertiles by `client_id` order. The results then say that the boundary group was split arbitrarily, and the segment names describe the group as a whole, not every customer in it.

**Segment effects:** calculated once in Stage 3, on all 200,039 customers, as the overall difference was in Phase 1. They do not depend on the models.

- **For each segment:** customer count, treated and control rates, the difference with an unpooled Wald 95% interval, and a two-sided pooled two-proportion z-test.
- **Correction:** Benjamini-Hochberg at 5% across the six p-values, from `statsmodels.stats.multitest.multipletests(method='fdr_bh')`. Raw and adjusted p-values are both reported.
- **Wording:** "significant" means a BH-adjusted p-value below 0.05. The Wald intervals are unadjusted, and the table says so.
- **Limit:** a significant effect within one segment does not show that it differs from the other segments. No test between segments is run.
- **No changes:** segments are not added or redefined after results are seen.

### Holdout guard

| Item | Rule |
|---|---|
| Switch | `RUN_HOLDOUT_EVALUATION = False` in the notebook's setup cell. It is set to `True` only after the project owner confirms the lock commit |
| Lock record | The holdout section asserts that this log has a line reading exactly `### Phase 5 lock record`. Stage 2 adds it at that level, under a `## Phase 5 development results` heading |
| Commit record | `LOCK_COMMIT_SHA` holds the lock commit hash the project owner provides. The holdout section asserts it is 7 to 40 hexadecimal characters, prints it, and Stage 3 records it with the results |
| Nothing earlier | No holdout label, and no holdout score, is loaded before these assertions pass |

The notebook does not run git. The project owner's commit is the record of the order.

### Order within Stage 3

Each step must pass before the next starts.

1. Run the guard assertions.
2. Load `scores_holdout.parquet`, assert the exact `tau`, and run `check_freeze` with `allow_first_run=False`. Proceed on a match, proceed with a warning within the tolerance, and stop otherwise.
3. Load holdout `treatment_flg` without `target`. Run `arm_balance` on `m1`, `m0` and `tau`, then the treated-share bands at 5%, 10% and 30% for `m1` and `tau`.
4. Load holdout `target`. Run the sanity checks, then the strategy results and the primary decision.
5. Calculate the segment effects on all 200,039 customers.

### If a bug is found after the holdout is opened

The first complete holdout run is the recorded result. If a bug is found later, the code is fixed and both results are reported with the reason. The decision rule applies to the corrected result, which is labelled as a departure from the locked analysis. Locked choices such as the features, budgets, segments and primary comparison never change. If this ever happens, both results go into this log, the README and the decision memo.

A later rerun from raw data must reproduce the recorded holdout values. If the freeze check warns, any small differences are reported rather than hidden.

### Shared code added in Stage 2

These go in `notebooks/targeting.py`, with known-answer checks in the notebook's setup cells, so that Phase 6 can reuse them.

| Function | What it does |
|---|---|
| `uplift_at_k_by_rank(ranks, treatment, target, percent)` | Uplift@K for the rows given, through `select_by_rank`, so it works on full sets and resamples. It stops if either arm is missing from the group. Its name differs from scikit-uplift's `uplift_at_k`, so the match check cannot compare a function with itself |
| `stratified_resample_indices(treatment, n_resamples, seed)` | The bootstrap indices described under "Bootstrap" |
| `treated_share_band(size)` | The 3.5-standard-error band for a group size |

## Where Phase 5 departs from the plan

| Plan | This analysis | Why |
|---|---|---|
| About 1,000 resamples, more if unstable | Exactly 2,000, with seed 42 | "More if unstable" would allow resampling until a result looked better |
| Bootstrap stratified by treatment group | The same, with each resample's top K% taken from its own rows through `select_by_rank` | The plan did not say how a resample selects its group |
| Random strategy as randomly selected customers | Expected value of random targeting, the overall difference | A single random draw adds noise that has nothing to do with the comparison |
| Shuffled scores close to the ATE | 1,000 shuffles, with a stop at 4 Monte Carlo standard errors | "Close" needed a test fixed in advance that scales with group size |
| Custom Uplift@K matches scikit-uplift | Exact match, by passing `-ranks` and a whole-number group size | scikit-uplift rounds the group size down and orders ties differently |
| No balance check at other budgets | Treated share at 5%, 10% and 30%, with bands scaled to group size | Item carried from the Phase 4 review |
| Out-of-fold scores as one view | A pooled ranking, plus a report-only per-fold table | Five model pairs produced the scores |
| Tertile thresholds for RFM | Defined columns, cut point rule, a tie rule and a fallback set in advance | Recency covers only 0 to 22 days, so ties could leave a tertile nearly empty |
| Segment treatment effects | On all 200,039 customers, in Stage 3 | Segment effects do not select a model, so they are treated like the overall difference |
| Lock before the final test | A switch, a lock record heading and the printed lock commit hash | The notebook cannot run git, so the holdout section checks what it can |
| "Run this once" | A rule for bugs found after the holdout is opened | The plan did not say what to do then |
| Curves from scikit-uplift | Drawn with Matplotlib from `sklift.metrics` | `sklift.viz` does not import with the installed scikit-learn |
| Random and contact everyone on the holdout | Use the holdout's overall difference as a reference point only | Paired differences need a reference on the same rows. The campaign effect stays the Phase 1 figure |

## Phase 5 development results

Values are **Measured** from `notebooks/04_policy_evaluation.ipynb`, on the 160,031 pooled out-of-fold development rows. They are **secondary**, or **exploratory** at 5%, and none of them is the primary result, which comes only from the holdout in Stage 3. Causal readings depend on the assignment assumption. Tables are in `outputs/tables/`, and the intervals capture uncertainty from the evaluation sample, not from refitting the models.

Later full runs of the notebook reproduced every Stage 2 table exactly, by file checksum. The notebook also stops if any value quoted below changes.

### Checks

| Check | Result | Rule | Triggered |
|---|---|---|---|
| Treated share, `m1`, at 5%, 10% and 30% | 50.34%, 50.18%, 50.06% | Within ±1.96, ±1.38 and ±0.80 points of 50% | No |
| Treated share, `tau`, at 5%, 10% and 30% | 49.99%, 49.89%, 49.64% | Same bands | No |
| Shuffle check, 1,000 orderings per budget | Largest gap 0.36 Monte Carlo standard errors, at 5% | Stop beyond 4 | No |
| Match with scikit-uplift, 8 comparisons | Largest difference 0.0 | Stop above 1e-12 | No |

The closest treated share to its band is `tau` at 30%: 49.64%, against a lower limit of 49.20%.

### Uplift@K by strategy

In points, with 95% intervals. Random is the expected value of random targeting, and its interval leaves out the noise of a single random draw.

| Budget | Random | Response | Uplift |
|---:|---:|---:|---:|
| 5% (exploratory) | +3.32 (+2.86 to +3.78) | +0.31 (-0.37 to +1.00) | +11.57 (+9.54 to +13.83) |
| 10% | +3.32 (+2.86 to +3.78) | +1.33 (+0.73 to +1.92) | +9.28 (+7.78 to +10.82) |
| 20% | +3.32 (+2.86 to +3.78) | +1.45 (+0.87 to +2.04) | +7.12 (+6.03 to +8.17) |
| 30% | +3.32 (+2.86 to +3.78) | +1.84 (+1.28 to +2.44) | +5.87 (+4.93 to +6.73) |

Contact everyone: +3.32 points (+2.86 to +3.78), or 3,323 incremental purchasers per 100,000 customers (2,857 to 3,782). Incremental purchasers per 100,000 for each strategy and budget are in `oof_strategy_results.csv`.

### Paired differences

In points, with paired 95% intervals. Incremental purchasers per 100,000 customers are in brackets.

| Budget | Uplift minus response | Uplift minus random | Response minus random |
|---:|---:|---:|---:|
| 5% (exploratory) | +11.26 (+9.01 to +13.57) [+563] | +8.25 (+6.22 to +10.40) [+412] | -3.01 (-3.81 to -2.18) [-151] |
| 10% | +7.95 (+6.35 to +9.62) [+795] | +5.96 (+4.58 to +7.43) [+596] | -1.99 (-2.71 to -1.27) [-199] |
| 20% | +5.67 (+4.46 to +6.92) [+1,134] | +3.80 (+2.88 to +4.78) [+760] | -1.87 (-2.52 to -1.23) [-374] |
| 30% | +4.04 (+2.95 to +4.99) [+1,211] | +2.55 (+1.77 to +3.28) [+765] | -1.49 (-2.05 to -0.85) [-446] |

At 20%, the uplift minus response difference is +1,134 incremental purchasers per 100,000 customers, 95% interval +893 to +1,384. This is the out-of-fold version of the primary comparison, so the decision rule does not apply to it.

### Qini and AUUC

| Metric | Response | Uplift | Uplift minus response |
|---|---:|---:|---:|
| Qini coefficient | -0.0053 (-0.0082 to -0.0022) | +0.0131 (+0.0099 to +0.0165) | +0.0184 (+0.0140 to +0.0229) |
| AUUC | -0.0083 (-0.0128 to -0.0034) | +0.0204 (+0.0155 to +0.0255) | +0.0287 (+0.0219 to +0.0357) |

Both are normalised by scikit-uplift, so random ranking scores near zero. The chart is `outputs/figures/oof_qini_uplift_curves.png`.

### By fold

| Fold | Response Uplift@20 | Uplift Uplift@20 | Uplift minus response |
|---:|---:|---:|---:|
| 1 | +1.95 | +8.09 | +6.14 |
| 2 | +1.75 | +5.08 | +3.34 |
| 3 | +1.13 | +8.01 | +6.88 |
| 4 | +1.49 | +6.98 | +5.49 |
| 5 | +1.09 | +7.88 | +6.79 |

Report only. Each fold ranks its own rows. The difference is positive in every fold, and fold 2 is the smallest.

### Disagreement analysis

| Quadrant | Customers | Treated rate | Control rate | Observed uplift, 95% CI |
|---|---:|---:|---:|---:|
| Likely buyers, more apparent SMS effect | 34,523 | 78.92% | 75.06% | +3.86 (+2.97 to +4.75) |
| Likely buyers, less apparent SMS effect | 45,493 | 85.83% | 84.24% | +1.59 (+0.94 to +2.25) |
| Possible persuadables | 45,493 | 44.41% | 39.09% | +5.31 (+4.41 to +6.22) |
| Less likely buyers, less apparent SMS effect | 34,522 | 44.20% | 42.41% | +1.79 (+0.75 to +2.84) |

| Quadrant | Days since last purchase, median | Transactions, median | Spend, median |
|---|---:|---:|---:|
| Likely buyers, more apparent SMS effect | 2 | 21 | 7,041 |
| Likely buyers, less apparent SMS effect | 1 | 32 | 12,191 |
| Possible persuadables | 8 | 8 | 3,237 |
| Less likely buyers, less apparent SMS effect | 9 | 9 | 4,040 |

Means are in `disagreement_profile.csv`, and the chart is `outputs/figures/disagreement_quadrants.png`.

| Budget | List size | On both lists | Share of the uplift list on the response list |
|---:|---:|---:|---:|
| 5% | 8,002 | 0 | 0.0% |
| 10% | 16,003 | 76 | 0.5% |
| 20% | 32,006 | 1,193 | 3.7% |
| 30% | 48,009 | 7,042 | 14.7% |

**How to read it:** these are model-defined groups, and no test between them was run. The two rankings choose almost entirely different customers at small budgets. The customers most likely to buy, who are frequent, recent and high-spending, already buy at about 84% without the SMS, and their observed uplift is small. That is consistent with the negative response minus random estimates, which carry no conclusion, and it does not identify individual persuadable customers.

### RFM cut points

| Variable | Column | Method | First cut point | Second cut point | Development shares of tertiles 1, 2 and 3 |
|---|---|---|---:|---:|---|
| Recency | `days_since_last_purchase` | Value | 2 | 7 | 37.9%, 29.7%, 32.4% |
| Frequency | `txn_count_hist` | Value | 10 | 22 | 34.3%, 33.2%, 32.4% |
| Monetary | `spend_hist` | Value | 4,045.09 | 8,973.04 | 33.3%, 33.3%, 33.3% |

Every tertile holds between 20% and 50% of development rows, so no variable uses the fallback.

| Segment | Recency | Frequency and monetary value | Development customers | All customers |
|---:|---|---|---:|---:|
| 1 | Recent | Lower | 22,189 | 27,843 |
| 2 | Recent | Higher | 38,478 | 48,222 |
| 3 | Moderately recent | Lower | 29,385 | 36,640 |
| 4 | Moderately recent | Higher | 18,111 | 22,564 |
| 5 | Least recent | Lower | 42,667 | 53,259 |
| 6 | Least recent | Higher | 9,201 | 11,511 |

No outcome was used to set these, and segment effects are not calculated until Stage 3.

### What Stage 2 does not show

Every score comes from a model that did not train on that customer. These same rows chose the model setup in Phase 3, though, and five different model pairs produced the pooled ranking. Whether the difference holds on untouched customers is the Stage 3 question. The Stage 1 precision estimate assumed 0% to 15% list overlap at 20%, and the observed out-of-fold overlap is 3.7%, inside that range. That is not a forecast of the holdout result.

### Phase 5 lock record

- **Rules:** "Rules for Phase 5" is unchanged since commit `202c311`. Stage 2 changed no rule.
- **RFM segments:** value-based tertiles for all three variables, with the cut points above. No fallback.
- **Arm balance:** the Phase 4 measures, SMD, SD ratio and the 48% to 52% share at 20%, ran on these rows in Phase 4 and are not repeated here. Stage 2 ran only the new bands at 5%, 10% and 30%. The full check runs on holdout rows in Stage 3.
- **Code paths:** the shuffle check passes its orderings to `select_by_rank` through `uplift_at_k_by_rank`. The reported Uplift@K values come from `uplift_at_budgets`, and both paths must match scikit-uplift within 1e-12. `overall_difference` moved into `notebooks/targeting.py`, with the same input checks as Uplift@K.
- **Holdout:** no holdout score or holdout label has been loaded in Phase 5. The Phase 4 freeze record, hash `b40d79c6...`, is unchanged.
- **Lock commit:** the commit that adds this record. The project owner supplies its hash for `LOCK_COMMIT_SHA`, and Stage 3 prints it and records it with the results.

## Phase 5 holdout results

The first complete holdout run is the recorded result, from `notebooks/04_policy_evaluation.ipynb` after lock commit `8c468b5`. The notebook printed that hash, and `outputs/tables/primary_result.csv` records it. Holdout values are **Measured** on the 40,008 holdout customers. Segment effects are **Measured** on all 200,039 labelled customers. Causal readings depend on the assignment assumption: observed checks are consistent with random assignment, but randomisation is not documented.

The same run first re-executed every Stage 2 cell with the code as reviewed. Every Stage 2 table matched the committed files by checksum, and every quoted development value matched, before any holdout cell ran.

### Checks before any holdout outcome

| Step | Result | Rule | Triggered |
|---|---|---|---|
| Guard | Lock record heading found; lock commit `8c468b5` printed | Stop if either is missing | No |
| Freeze | The recorded hash matches | Proceed on a match | No |
| Arm balance, SMD | `m1` -0.0036, `m0` -0.0026, `tau` -0.0044 | Stop at an absolute value of 0.05 | No |
| Arm balance, SD ratio | `m1` 0.9983, `m0` 0.9981, `tau` 1.0234 | Stop outside 0.9 to 1.1 | No |
| Treated share of the top 20% | `m1` 49.45%, `tau` 49.64% | Stop outside 48% to 52% | No |
| Treated share at 5%, 10% and 30% | `m1` 49.35%, 49.41%, 49.91%; `tau` 50.50%, 50.04%, 50.02% | Within ±3.91, ±2.77 and ±1.60 points of 50% | No |
| Shuffle check | Largest gap 1.97 Monte Carlo standard errors, at 5% | Stop beyond 4 | No |
| Match with scikit-uplift | Largest recorded difference 0.0, for `uplift_at_k_by_rank`. The reported values from `uplift_at_budgets` also passed the 1e-12 check, but their differences were not recorded | Stop above 1e-12 | No |

### Primary result

| Item | Value |
|---|---:|
| Uplift@20, uplift strategy | +6.26 points |
| Uplift@20, response strategy | +1.21 points |
| **Uplift minus response at 20%** | **+5.05 points** |
| Paired 95% interval | +2.55 to +7.34 points |
| Incremental purchasers per 100,000 customers | +1,010 (+510 to +1,467) |

**Conclusion under the decision rule:** the paired interval is entirely above zero, so **uplift targeting performed better at the 20% budget**. H0 is rejected at the pre-set level, a one-sided 2.5% test. The interval is about ±2.4 points wide, a little narrower than the ±3 points estimated before any result, consistent with the low list overlap.

### Uplift@K by strategy

Secondary, or exploratory at 5%. In points, with 95% intervals. Random is the expected value of random targeting, and its interval leaves out the noise of a single random draw. On these rows, Random and contact everyone use the holdout's overall difference only as the reference point for strategies. The campaign effect remains the Phase 1 difference on all 200,039 customers.

| Budget | Random | Response | Uplift |
|---:|---:|---:|---:|
| 5% (exploratory) | +3.32 (+2.32 to +4.27) | +0.54 (-0.63 to +1.89) | +16.24 (+11.87 to +20.39) |
| 10% | +3.32 (+2.32 to +4.27) | +0.61 (-0.63 to +1.79) | +11.02 (+7.81 to +13.98) |
| 20% | +3.32 (+2.32 to +4.27) | +1.21 (+0.10 to +2.40) | +6.26 (+3.99 to +8.35) |
| 30% | +3.32 (+2.32 to +4.27) | +1.36 (+0.23 to +2.43) | +4.75 (+2.94 to +6.50) |

### Paired differences

In points, with paired 95% intervals. Incremental purchasers per 100,000 customers are in brackets.

| Budget | Uplift minus response | Uplift minus random | Response minus random |
|---:|---:|---:|---:|
| 5% (exploratory) | +15.70 (+11.18 to +20.04) [+785] | +12.92 (+8.79 to +16.95) [+646] | -2.78 (-4.20 to -1.17) [-139] |
| 10% | +10.41 (+6.88 to +13.51) [+1,041] | +7.70 (+4.68 to +10.43) [+770] | -2.71 (-4.21 to -1.29) [-271] |
| 20% | **+5.05 (+2.55 to +7.34) [+1,010], primary** | +2.94 (+0.89 to +4.82) [+587] | -2.11 (-3.39 to -0.76) [-423] |
| 30% | +3.39 (+1.33 to +5.31) [+1,016] | +1.42 (-0.11 to +2.87) [+426] | -1.96 (-3.17 to -0.80) [-589] |

### Qini and AUUC

| Metric | Response | Uplift | Uplift minus response |
|---|---:|---:|---:|
| Qini coefficient | -0.0065 (-0.0124 to -0.0004) | +0.0069 (-0.000003 to +0.0131) | +0.0134 (+0.0037 to +0.0218) |
| AUUC | -0.0100 (-0.0193 to -0.0004) | +0.0108 (+0.0002 to +0.0204) | +0.0209 (+0.0056 to +0.0338) |

The chart is `outputs/figures/holdout_qini_uplift_curves.png`.

### Agreement with the out-of-fold view

| Comparison | Out-of-fold | Holdout |
|---|---:|---:|
| Uplift minus response at 20% | +5.67 (+4.46 to +6.92) | +5.05 (+2.55 to +7.34) |
| Uplift Uplift@20 | +7.12 | +6.26 |
| Response Uplift@20 | +1.45 | +1.21 |
| Uplift minus random at 30% | +2.55 (+1.77 to +3.28) | +1.42 (-0.11 to +2.87) |
| Uplift Qini coefficient | +0.0131 (+0.0099 to +0.0165) | +0.0069 (-0.000003 to +0.0131) |

The two views agree in direction on every uplift minus response comparison. These are the disagreements:
- On the holdout, uplift minus random at 30% has an interval that includes zero.
- The holdout Qini interval for the uplift strategy includes zero, with a lower end of -0.000003.
- The exploratory 5% results are larger on the holdout, with wide intervals.

The holdout has a quarter of the rows, so its intervals are about twice as wide.

### RFM segment effects

All 200,039 labelled customers, with the development cut points from the lock record. The Wald intervals are unadjusted. "Significant" means a Benjamini-Hochberg adjusted p-value below 0.05.

| Segment | Customers | Treated rate | Control rate | Difference, unadjusted 95% CI | BH-adjusted p | Significant |
|---|---:|---:|---:|---:|---:|---|
| 1. Recent, lower F and M | 27,843 | 67.35% | 63.17% | +4.18 (+3.06 to +5.30) | 4.9e-13 | Yes |
| 2. Recent, higher F and M | 48,222 | 88.37% | 87.04% | +1.33 (+0.74 to +1.91) | 1.4e-05 | Yes |
| 3. Moderately recent, lower F and M | 36,640 | 53.77% | 49.42% | +4.34 (+3.32 to +5.36) | 2.7e-16 | Yes |
| 4. Moderately recent, higher F and M | 22,564 | 78.54% | 76.81% | +1.72 (+0.64 to +2.81) | 0.0019 | Yes |
| 5. Least recent, lower F and M | 53,259 | 39.93% | 35.91% | +4.02 (+3.19 to +4.84) | 7.6e-21 | Yes |
| 6. Least recent, higher F and M | 11,511 | 61.84% | 58.40% | +3.45 (+1.66 to +5.23) | 0.00019 | Yes |

All six segments show a positive difference after correction. The two lowest are the recent and moderately recent segments with higher frequency and monetary value, whose control customers already buy at 77% to 87%. A significant effect within one segment does not show that it differs from the other segments, and no test between segments was run. The chart is `outputs/figures/rfm_segment_effects.png`.

### What Phase 5 does not show

- **Value:** the unit is incremental purchasers, not revenue or margin, for an outcome window that is undocumented.
- **Individuals:** the results do not identify individual persuadable customers. They compare targeting rules on groups.
- **Model uncertainty:** the intervals cover the evaluation sample only, not refitting the models.
- **Other budgets:** only the 20% comparison carries a conclusion. The others are secondary or exploratory.
- **Population:** the results apply to the labelled cohort only.

## Phase 6 status

**Complete.** The rules were committed in `37ac8a5` before any Phase 6 quantity was calculated, with one approved correction to recorded hashes. Results are under "Phase 6 results", and the memo is `reports/decision_memo.md`. Phase 6 turns the Phase 5 results into a budget recommendation, in `notebooks/05_business_recommendations.ipynb`. The models, features, scores and Phase 5 results are not changed.

## Rules for Phase 6

**When these rules were written:** on 2026-11-08, after every Phase 5 result in this log was known, including the holdout strategy table. They were not written blind to those values. Approximate net values at the locked budgets, which follow by arithmetic from the Phase 5 tables, were looked at while the rules were discussed. No Phase 6 table, curve or recommendation had been calculated. The commit that adds this section is the record of that order.

### Order of work

1. **Stage 1, rules:** add this section to this log, ending at a commit.
2. **Stage 2, analysis and memo:** build the notebook, the tables and figures below and `reports/decision_memo.md`, then record the results under "Phase 6 results". This ends at a commit.

Stage 2 results cannot change any choice in this section. If a rule proves unworkable, it can be changed only with the project owner's approval, with the old rule, the new rule and the reason recorded here.

**Scope:** Phase 6 covers the notebook, the memo and this log. The README, its "Future work" section, the CV bullets and the final clean rerun from raw data are a separate closing step.

### Data

| Source | Use |
|---|---|
| `outputs/tables/holdout_strategy_results.csv` | Holdout Uplift@K and incremental purchasers per 100,000, with intervals, for every strategy at 5%, 10%, 20% and 30%, plus contact everyone |
| `outputs/tables/oof_strategy_results.csv` | The same, on the 160,031 pooled out-of-fold rows |
| `outputs/tables/primary_result.csv` | The headline comparison |
| `data/processed/scores_oof.parquet`, with development labels | The out-of-fold context results only |

### Holdout guard

- **No new holdout outcome calculation.** The notebook never loads `scores_holdout.parquet` or any holdout `treatment_flg` or `target`. Holdout values enter only through the saved Phase 5 tables above.
- **Development labels:** loaded only for rows with `split = 'development'` in `splits.parquet`. The notebook asserts 160,031 rows with exactly the `client_id` values in `scores_oof.parquet`.
- **Saved tables:** each of the three CSVs must match the SHA-256 below, calculated after converting CRLF line endings to LF so that a Windows checkout gives the same value. A mismatch stops the run.

| File | SHA-256 of the LF content |
|---|---|
| `holdout_strategy_results.csv` | `12734dd300e96f46018706e062850433b940cb602a46124aa2b64441fc4b8135` |
| `oof_strategy_results.csv` | `c439298cb7acaccc27a3f3f9e8386f60db41b7cd607209deab6e8f2ef9958387` |
| `primary_result.csv` | `b2b2a9ecbdb6cc7dae68eb5e2b950652c3dbb3367ef846726f7d259eeb87ca87` |

- **Lock commit:** `primary_result.csv` must record lock commit `8c468b5`.

**Correction to the Phase 6 rules, approved by the project owner on 2026-11-08:** the hashes first committed above, in `37ac8a5`, were taken from the raw files, which have CRLF line endings, although the rule describes the hash of the LF content. They were `d2b1c157d5910c85573aba64ccded74d36411fe6cf7e46c8d89dbecf58cafb0d`, `b2f77cc35418f0b7698501f9c70c5fae5b5fc756b79938c7ac5de2c0fa7d663f` and `3a0ea5f934e28c3924ee668da599587934b858034ee8e13dbe40b279521c818c`, in the order of the table. The guard stopped on the first table before any Phase 6 quantity was calculated. The values above are the LF hashes, and each equals the hash of the same file as committed in Phase 5, `b987a94`, so the tables have not changed. This corrects a recording error. The rule itself is unchanged.

### Cost scenarios and net value

| Scenario | `r = c / m` | Label |
|---|---:|---|
| Optimistic | 1% | Assumed |
| Moderate | 3% | Assumed |
| Conservative | 5% | Assumed |

- **No currency:** the scenarios are cost-to-margin ratios only. No SMS price, margin or basket value is researched or used.
- **Net value per 100,000 customers, in purchaser-equivalents:** incremental purchasers per 100,000 minus `100,000 x K x r`. This is the plan's net value divided by `m`, so one purchaser-equivalent is the margin of one incremental purchaser. A positive value means contact is worthwhile under that scenario.
- **Interval:** the Phase 5 per-100,000 interval minus the same `100,000 x K x r`. For a fixed `r` the cost term is the same in every resample, so this is exact and needs no new bootstrap.
- **Contact no one:** a net value of 0, with no interval.
- **Coverage:** net value is reported for every strategy and locked budget, and for contact everyone, on both evaluation sets.

### Recommendation rule

For each scenario:

1. **Candidates:** the uplift strategy at 5%, 10%, 20% and 30%, contact everyone at 100%, and contact no one at 0%. These are the locked points, so every choice has a holdout value. Response and Random are reported but are not candidates.
2. **Choice:** the candidate with the highest out-of-fold net value, by point estimate. If no candidate that contacts customers has a positive net value, the choice is contact no one. An exact tie goes to the smaller budget.
3. **Close call:** the runner-up is the candidate with the second-highest out-of-fold net value. The choice is marked as a close call when the runner-up's point estimate lies inside the chosen candidate's out-of-fold 95% net value interval, ends included. If the choice is contact no one, it is a close call when the runner-up's interval includes zero. This is reported only and never breaks a tie or changes the choice.
4. **Holdout check:** the holdout net value at the chosen point is reported with its interval, together with the candidate that has the highest holdout net value under the same rule. If they differ, the memo says so plainly. The out-of-fold choice stands, in line with the Phase 5 rule that disagreements are reported as they are.

### Context results

These use the pooled out-of-fold rows only, have no intervals and are labelled context. They never choose the recommendation.

- **Budget curve:** Uplift@K and net value under each scenario for the uplift and response strategies, from 5% to 100% in 5% steps, through `score_ranks` and `uplift_at_k_by_rank`. Values at 5%, 10%, 20%, 30% and 100% must match `oof_strategy_results.csv` within 1e-12, or the run stops. Random appears as its straight-line expected value.
- **Band uplift:** for the uplift and response strategies, the treated purchase rate minus the control purchase rate among the rows in each band between locked points: 0–5%, 5–10%, 10–20%, 20–30% and 30–100%. A band is the top K2% minus the top K1% from `select_by_rank` on the same ranks. Each band is compared with each scenario's `r`.
- **Break-even curve:** `r` from 0 to the highest out-of-fold Uplift@K at any locked point across all strategies, rounded up to the next whole point. That is 11.57 points, for the uplift strategy at 5%, so the range is 0 to 12 points, in steps of 0.1 point. For each `r`, the curve shows each candidate's out-of-fold net value and marks the best one, so the points where contact everyone stops being best and where contact no one starts are both visible.

### Outputs

| File | Contents |
|---|---|
| `outputs/tables/net_value_scenarios.csv` | Net value with intervals, for each set, strategy, budget and scenario |
| `outputs/tables/recommendation.csv` | For each scenario: the choice, its out-of-fold and holdout net values with intervals, the runner-up, the close call flag and the holdout's best candidate |
| `outputs/tables/oof_budget_curve.csv` | The budget curve |
| `outputs/tables/oof_band_uplift.csv` | The band uplift |
| `outputs/tables/break_even_curve.csv` | The break-even curve |
| `outputs/figures/net_value_by_budget.png` | One panel per scenario: out-of-fold context lines for uplift, response and random, holdout values at the locked points with intervals, and the choice marked |
| `outputs/figures/break_even_curve.png` | The break-even curve |

### Labels

| Number | Label |
|---|---|
| Uplift@K, incremental purchasers per 100,000 and band uplift | **Measured**, naming holdout or out-of-fold |
| `r` and each scenario | **Assumed** (c/m = x%) |
| Net value, break-even points and each recommendation row | **Assumed**, naming its measured input, for example "Assumed (Measured out-of-fold Uplift@K, c/m = 3%)" |
| Raw `tau` | Not used for business numbers. If quoted, **Estimated from the model** |

Any number with an assumed input is labelled Assumed.

### Decision memo

| Item | Rule |
|---|---|
| Reader | A CRM or marketing manager |
| Length | At most 450 words, counting everything except the title and the tables, checked with a word count in Stage 2 |
| Tables | At most two: the conditional recommendation table and the measured-versus-assumed table |
| Figure | At most one, linked rather than embedded |
| Sections, in order | 1. Recommendation, 2. Evidence, 3. Measured results vs assumptions, 4. Limitations, 5. Next step |
| Recommendation | A three-row conditional table, one row per scenario, each labelled Assumed (c/m = x%), with the choice, its out-of-fold and holdout net values with intervals, and any close call or holdout disagreement. It points the reader to the break-even curve to place their own ratio. There is no base case |
| Headline | "At a 20% budget, targeting by estimated uplift produced about 1,010 more extra purchasers per 100k customers than targeting by purchase likelihood (95% range +510 to +1,467)", labelled **Measured (holdout)** |
| Assignment | The Phase 1 wording, verbatim: "Observed checks are consistent with random assignment, but randomisation is not documented. Causal claims depend on that assumption." |
| Method terms | None in the body. A single "Method" line links to the notebooks and this log |
| Limitations | Assignment evidence, the undocumented outcome window, no revenue or margin, no opt-outs or long-term effects, the labelled cohort only, intervals that do not cover refitting the models, and assumed cost scenarios |
| Next step | A randomised test of "top K by uplift" against contact everyone or random targeting, with revenue tracked and a documented outcome window |

## Where Phase 6 departs from the plan

| Plan | This analysis | Why |
|---|---|---|
| Replace placeholder costs with researched values if a credible source exists | Cost-to-margin ratios only, with no currency | The outcome is whether a customer purchased, not spend, and the outcome window is undocumented, so margin per incremental purchaser cannot be known from this data. A researched price or basket value would make currency figures look measured |
| Net value in money | Net value in purchaser-equivalents | It needs only the ratio `c / m` |
| Incremental purchasers for each strategy and budget, with intervals | Taken from the saved Phase 5 tables, with net value intervals by an exact shift | No new holdout outcome calculation, and no new bootstrap is needed |
| Plot net value by budget | Out-of-fold curve in 5% steps as context, with the choice limited to locked points | Every choice then has a holdout value, and choosing from a finer grid would select on noise |
| Compare each budget band's uplift with break-even | Out-of-fold band uplift as context. The choice uses net value at locked points | Net value at the locked points already accounts for every band below the chosen budget |
| Identify when contact everyone beats targeting | The break-even curve from 0 to the highest locked-point Uplift@K | It shows both the contact everyone and the contact no one boundaries |
| Three labels | Any number with an assumed input is labelled Assumed | The plan did not say how to label a number built from measured and assumed parts |
| Not in the plan | A recommendation rule, a close call flag and a holdout check, all set in advance | The plan did not say how a recommendation would be chosen |
| One-page memo | At most 450 words, at most two tables and one linked figure | Markdown has no page size, so the limit needed to be testable |

## Phase 6 results

From `notebooks/05_business_recommendations.ipynb`. Incremental purchasers are **Measured** in Phase 5, on the 160,031 pooled out-of-fold rows or the 40,008 holdout customers. Every net value, break-even point and recommendation is **Assumed**, because it uses an assumed cost-to-margin ratio `r`. Net values are per 100,000 customers, in purchaser-equivalents, with 95% intervals. Causal readings depend on the assignment assumption.

### Checks

| Check | Result |
|---|---|
| Known-answer checks on the helpers | All passed |
| Hashes of the three Phase 5 tables, LF content | All three match the corrected record |
| Lock commit in `primary_result.csv` | `8c468b5` |
| Development rows | 160,031, all `split = 'development'`, the same IDs as `scores_oof.parquet`, 79,985 treated and 80,046 control |
| Budget curve at the locked points against the Phase 5 out-of-fold table | Match within 1e-12, including Random and contact everyone |
| Memo rules | 348 words outside the title and tables, 2 tables, 1 figure link, sections in order, headline and assignment wording verbatim, no method terms, every recommendation number and switching point matches |
| Reproducibility | A second full run gave byte-identical copies of all five Phase 6 tables |

No holdout score or holdout label was loaded.

### Recommendation

| Scenario | Choice | Out-of-fold net value | Runner-up, out-of-fold | Close call | Holdout net value at the choice | Holdout's best candidate |
|---|---|---:|---|---|---:|---|
| Optimistic, `r` = 1% | Contact everyone | +2,323 (+1,857 to +2,782) | Top 30%, +1,462 | No | +2,324 (+1,319 to +3,274) | Contact everyone, the same |
| Moderate, `r` = 3% | Top 30% by estimated uplift | +862 (+580 to +1,119) | Top 20%, +824 | Yes | +524 (-17 to +1,049) | Top 10%, +802, **differs** |
| Conservative, `r` = 5% | Top 10% by estimated uplift | +428 (+278 to +582) | Top 20%, +424 | Yes | +602 (+281 to +898) | Top 10%, the same |

Under the rule, the out-of-fold choice stands in the moderate scenario, where the holdout ranks the top 10% higher. The holdout interval at the top 30% includes zero there. The memo states both.

### Break-even curve

Best candidate by out-of-fold net value, as `r` rises from 0 to 12 points. The switching points are exact crossings of the candidates' straight lines.

| `r` range | Best candidate |
|---|---|
| 0 to 2.23% | Contact everyone |
| 2.23% to 3.38% | Top 30% |
| 3.38% to 4.96% | Top 20% |
| 4.96% to 6.99% | Top 10% |
| 6.99% to 11.57% | Top 5% |
| Above 11.57% | Contact no one |

Contact everyone beats every targeted budget only while `r` is below 2.23%. Each switching point is the uplift of the band between two locked budgets, computed from the Phase 5 per-100,000 values. The band uplifts below are computed directly on band rows, so they differ slightly, because the arm split within a band is not exactly even.

### Band uplift, context

Treated rate minus control rate among the out-of-fold customers in each band, in points.

| Band | Uplift strategy | Response strategy |
|---|---:|---:|
| 0–5% | +11.57 | +0.31 |
| 5–10% | +7.01 | +2.33 |
| 10–20% | +4.98 | +1.61 |
| 20–30% | +3.37 | +2.38 |
| 30–100% | +2.16 | +3.91 |

For the uplift strategy, band uplift falls steadily from the top band down. For the response strategy, the customers it leaves out, the 30–100% band, have the highest uplift. The chart is `outputs/figures/net_value_by_budget.png`, and the break-even chart is `outputs/figures/break_even_curve.png`.

### Added in Stage 2

These change no choice in "Rules for Phase 6":

- **Exact switching points** on the break-even curve, from the crossing of two straight lines, beside the 0.1-point grid.
- **Memo checks** in the notebook, so a rerun tests the memo rules and its numbers against the calculation.

### What Phase 6 does not show

- **Money:** no currency values. Each reader supplies their own cost-to-margin ratio.
- **Model uncertainty:** net value intervals cover the evaluation sample only, not refitting the models.
- **Close calls:** in the moderate and conservative scenarios the runner-up lies inside the choice's interval, so the data do not clearly separate those budgets.

## Clean rerun record

On 2026-11-08, after the Phase 6 commit `17248c6`, all five notebooks ran in order from `data/raw/`. They used a fresh virtual environment built from `requirements.txt` on Python 3.13.5. `data/processed/` and `models/` were moved aside first, so every Parquet file and model was regenerated. No check stopped.

| Item | Result |
|---|---|
| Run time | 01: 1 min, 02: 3 min, 03: 13 min, 04: 14 min, 05: under 1 min |
| Split | Matched the recorded SHA-256 |
| Holdout scores | Both freeze checks: "proceed. The recorded hash matches" |
| Scores, split and labels against the earlier run | `scores_oof`, `scores_holdout`, `splits` and `uplift_train` exactly identical |
| Feature tables against the earlier run | Largest absolute difference 1.75e-10, most likely from summation order in DuckDB's parallel aggregation |
| Committed outputs | Every result table and every figure byte-identical. Seven descriptive tables differ only in trailing floating-point digits: `amount_reconciliation`, `disagreement_profile`, `feature_balance`, `feature_profile`, `m0_feature_importance`, `response_feature_importance` and `rfm_cut_points` |
| Values quoted in this log | None changed |

The holdout evaluation was re-executed as a reproduction under the Phase 5 rule that a rerun must reproduce the recorded holdout values. It did, so the recorded result stands unchanged.

The README now states that `outputs/tables/holdout_scores_reference.csv` serves as the holdout freeze record, as "For the README" requires.
