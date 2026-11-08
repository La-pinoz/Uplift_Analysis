"""Rules that more than one notebook must apply identically: top-K selection, arm balance, the holdout freeze and Uplift@K."""
import hashlib

import numpy as np

FREEZE_TOLERANCE = 1e-5


def score_ranks(client_ids, scores):
    """Return each customer's rank, in input order, where 0 is the best.

    Customers are ordered by score descending, then `client_id` ascending. IDs must be unique
    strings and scores must be finite numbers, so a bad join stops here rather than changing the group.
    """
    ids = np.asarray(client_ids, dtype=object)
    values = np.asarray(scores)

    if ids.ndim != 1 or values.ndim != 1 or len(ids) != len(values):
        raise ValueError("client_ids and scores must be one-dimensional and the same length")
    if len(ids) == 0:
        raise ValueError("No customers to rank")
    if not all(isinstance(client_id, str) for client_id in ids):
        raise ValueError("client_ids must all be strings")
    if len(set(ids)) != len(ids):
        raise ValueError("client_ids must be unique")
    if values.dtype.kind not in "fiu":
        raise ValueError("scores must be numeric")
    if not np.isfinite(values).all():
        raise ValueError("scores must be finite")

    # lexsort treats its last key as the primary one.
    order = np.lexsort((ids.astype(str), -values.astype(np.float64)))
    ranks = np.empty(len(ids), dtype=np.int64)
    ranks[order] = np.arange(len(ids))
    return ranks


def select_by_rank(ranks, percent):
    """Return a boolean mask, in input order, of the best `percent` of the given ranks.

    The group size is `percent * n / 100` rounded to the nearest whole number, with exact halves
    rounded up. `percent` is a whole number from 1 to 100, so the size never depends on binary
    rounding. Ranks may repeat, as they do in a bootstrap resample. Copies of a customer on the
    cutoff are kept in input order.
    """
    ranks = _require_ranks(ranks)
    size = _group_size(len(ranks), percent)
    mask = np.zeros(len(ranks), dtype=bool)
    mask[np.argsort(ranks, kind="stable")[:size]] = True
    return mask


def _require_ranks(ranks):
    ranks = np.asarray(ranks)
    if ranks.ndim != 1 or len(ranks) == 0:
        raise ValueError("ranks must be one-dimensional and not empty")
    if ranks.dtype.kind not in "iu" or ranks.min() < 0:
        raise ValueError("ranks must be whole, non-negative numbers, as score_ranks returns")
    return ranks


def _group_size(n, percent):
    """`percent * n / 100` rounded to the nearest whole number, halves up, in whole-number arithmetic."""
    if isinstance(percent, (bool, np.bool_)) or not isinstance(percent, (int, np.integer)) or not 1 <= percent <= 100:
        raise ValueError("percent must be a whole number from 1 to 100")
    size = (int(percent) * n + 50) // 100
    if size == 0:
        raise ValueError("This percent selects no customers")
    return size


def select_top_k(client_ids, scores, percent):
    """Return a boolean mask, in input order, of the top `percent` of customers by score."""
    return select_by_rank(score_ranks(client_ids, scores), percent)


def arm_balance(client_ids, treatment, scores):
    """Return SMD, treated SD over control SD, and the treated share of the top 20% for one score."""
    arm = np.asarray(treatment)
    values = np.asarray(scores)
    if arm.ndim != 1 or values.ndim != 1 or len(arm) != len(values):
        raise ValueError("treatment and scores must be one-dimensional and the same length")
    if values.dtype.kind not in "fiu":
        raise ValueError("scores must be numeric")
    if not set(np.unique(arm).tolist()) == {0, 1}:
        raise ValueError("treatment must hold both 0 and 1, and nothing else")

    values = values.astype(np.float64)
    treated, control = values[arm == 1], values[arm == 0]
    if min(len(treated), len(control)) < 2 or treated.std(ddof=1) == 0 or control.std(ddof=1) == 0:
        raise ValueError("Each arm needs at least two rows and some spread in the score")
    pooled_sd = np.sqrt((treated.var(ddof=1) + control.var(ddof=1)) / 2)
    return {
        "smd": float((treated.mean() - control.mean()) / pooled_sd),
        "sd_ratio": float(treated.std(ddof=1) / control.std(ddof=1)),
        "treated_share_top_20": float((arm[select_top_k(client_ids, values, 20)] == 1).mean()),
    }


def _require_float32(*arrays):
    for values in arrays:
        if not isinstance(values, np.ndarray) or values.dtype != np.float32 or values.ndim != 1:
            raise ValueError("Scores must be one-dimensional 32-bit float arrays")


def assert_exact_tau(m1_scores, m0_scores, tau):
    """Stop unless `tau` is exactly the 64-bit `m1_score` minus the 64-bit `m0_score`."""
    _require_float32(m1_scores, m0_scores)
    exact = m1_scores.astype(np.float64) - m0_scores.astype(np.float64)
    if not np.array_equal(exact, np.asarray(tau, dtype=np.float64)) or np.asarray(tau).dtype != np.float64:
        raise ValueError("tau is not the exact 64-bit difference of m1_score and m0_score")


def holdout_score_hash(client_ids, m1_scores, m0_scores):
    """SHA-256 of `client_id,m1,m0\\n` lines, using lowercase hex of the big-endian 32-bit scores."""
    _require_float32(m1_scores, m0_scores)
    ids = np.asarray(client_ids, dtype=object)
    if not len(ids) == len(m1_scores) == len(m0_scores):
        raise ValueError("client_ids and scores must be the same length")
    if not all(isinstance(client_id, str) for client_id in ids) or any(a >= b for a, b in zip(ids, ids[1:])):
        raise ValueError("client_ids must be strings in strictly ascending order")

    m1_bytes, m0_bytes = m1_scores.astype(">f4").tobytes().hex(), m0_scores.astype(">f4").tobytes().hex()
    digest = hashlib.sha256()
    for row, client_id in enumerate(ids):
        digest.update(f"{client_id},{m1_bytes[row * 8:row * 8 + 8]},{m0_bytes[row * 8:row * 8 + 8]}\n".encode("utf-8"))
    return digest.hexdigest()


def check_freeze(recorded_hash, reference, client_ids, expected_client_ids, m1_scores, m0_scores, allow_first_run):
    """Apply the freeze state table in the logged order. Returns `(action, reason)`.

    `action` is "first_run", "proceed", "warn" or "stop". `reference` is the reference table, or
    None if the file is missing. The hash is calculated here from the scores passed in, so a stale
    value cannot pass. Phase 4 allows a first run, and Phase 5 does not.
    """
    ids, expected = list(client_ids), list(expected_client_ids)
    if ids != expected or any(a >= b for a, b in zip(expected, expected[1:])):
        return "stop", "client_id values are not exactly the sorted holdout IDs"
    if recorded_hash is None and reference is None:
        if allow_first_run:
            return "first_run", "No recorded hash and no reference file"
        return "stop", "The freeze record is missing, and this step does not allow a first run"
    if recorded_hash is None:
        return "stop", "A reference file exists with no recorded hash"
    if reference is None:
        return "stop", "A recorded hash exists with no reference file"
    if len(reference) != len(ids):
        return "stop", f"The reference file has {len(reference):,} rows, against {len(ids):,} customers"
    if recorded_hash == holdout_score_hash(ids, m1_scores, m0_scores):
        return "proceed", "The recorded hash matches"

    differences = np.abs(
        np.concatenate(
            (
                np.asarray(m1_scores, dtype=np.float64) - reference["m1_score"].to_numpy(dtype=np.float64),
                np.asarray(m0_scores, dtype=np.float64) - reference["m0_score"].to_numpy(dtype=np.float64),
            )
        )
    )
    largest = differences.max()
    if largest <= FREEZE_TOLERANCE:
        return "warn", f"The hash differs, and the largest difference from the reference file is {largest:.2e}"
    return "stop", f"The largest difference from the reference file is {largest:.2e}, above {FREEZE_TOLERANCE:.0e}"


def _require_binary(name, values, length):
    values = np.asarray(values)
    if values.ndim != 1 or len(values) != length:
        raise ValueError(f"{name} must be one-dimensional and the same length as ranks")
    if values.dtype.kind not in "biuf" or not np.isin(values, (0, 1)).all():
        raise ValueError(f"{name} must hold only 0 and 1")
    return values.astype(np.int64)


def uplift_at_k_by_rank(ranks, treatment, target, percent):
    """Treated purchase rate minus control purchase rate in the best `percent` of the given ranks.

    Selection goes through `select_by_rank`, so it works on full sets and on bootstrap resamples.
    A group missing either arm stops, because its uplift is undefined.
    """
    ranks = _require_ranks(ranks)
    arm = _require_binary("treatment", treatment, len(ranks))
    outcome = _require_binary("target", target, len(ranks))
    mask = select_by_rank(ranks, percent)
    treated, control = mask & (arm == 1), mask & (arm == 0)
    if not treated.any() or not control.any():
        raise ValueError(f"The top {percent}% holds only one arm, so its uplift is undefined")
    return outcome[treated].sum() / treated.sum() - outcome[control].sum() / control.sum()


def overall_difference(treatment, target):
    """Treated purchase rate minus control purchase rate over all rows given, with the same checks as Uplift@K."""
    arm = np.asarray(treatment)
    arm = _require_binary("treatment", arm, arm.size)
    outcome = _require_binary("target", target, len(arm))
    treated, control = arm == 1, arm == 0
    if not treated.any() or not control.any():
        raise ValueError("Both arms are needed for the overall difference")
    return outcome[treated].sum() / treated.sum() - outcome[control].sum() / control.sum()


def uplift_at_budgets(ranks, treatment, target, percents):
    """`uplift_at_k_by_rank` at several budgets from one sort. Returns {percent: uplift} in the order given.

    It takes prefixes of the same stable sort that `select_by_rank` uses, so the groups are identical.
    """
    ranks = _require_ranks(ranks)
    arm = _require_binary("treatment", treatment, len(ranks))
    outcome = _require_binary("target", target, len(ranks))
    if not isinstance(percents, (list, tuple)) or len(percents) == 0 or len(set(percents)) != len(percents):
        raise ValueError("percents must be a non-empty list or tuple of distinct budgets")

    order = np.argsort(ranks, kind="stable")
    treated_seen = np.cumsum(arm[order])
    treated_bought = np.cumsum((arm * outcome)[order])
    control_bought = np.cumsum(((1 - arm) * outcome)[order])

    results = {}
    for percent in percents:
        last = _group_size(len(ranks), percent) - 1
        n_treated = int(treated_seen[last])
        n_control = last + 1 - n_treated
        if n_treated == 0 or n_control == 0:
            raise ValueError(f"The top {percent}% holds only one arm, so its uplift is undefined")
        results[percent] = treated_bought[last] / n_treated - control_bought[last] / n_control
    return results


def stratified_resample_indices(treatment, n_resamples, seed):
    """Yield bootstrap row indices one resample at a time, from a new `default_rng(seed)`.

    Each resample draws, with replacement, as many treated rows as there are treated rows and as many
    control rows as there are control rows: treated draws first, then control draws.
    """
    arm = np.asarray(treatment)
    if arm.ndim != 1 or set(np.unique(arm).tolist()) != {0, 1}:
        raise ValueError("treatment must be one-dimensional and hold both 0 and 1, and nothing else")
    if isinstance(n_resamples, (bool, np.bool_)) or not isinstance(n_resamples, (int, np.integer)) or n_resamples < 1:
        raise ValueError("n_resamples must be a positive whole number")
    if isinstance(seed, (bool, np.bool_)) or not isinstance(seed, (int, np.integer)) or seed < 0:
        raise ValueError("seed must be a non-negative whole number, so resamples are reproducible")

    treated_rows, control_rows = np.flatnonzero(arm == 1), np.flatnonzero(arm == 0)

    def resamples():
        rng = np.random.default_rng(seed)
        for _ in range(int(n_resamples)):
            yield np.concatenate(
                (
                    treated_rows[rng.integers(0, len(treated_rows), len(treated_rows))],
                    control_rows[rng.integers(0, len(control_rows), len(control_rows))],
                )
            )

    return resamples()


def treated_share_band(size):
    """Half-width of the treated-share band: 3.5 binomial standard errors around 50%, sqrt(0.25 / size)."""
    if isinstance(size, (bool, np.bool_)) or not isinstance(size, (int, np.integer)) or size < 1:
        raise ValueError("size must be a positive whole number")
    return 3.5 * float(np.sqrt(0.25 / size))
