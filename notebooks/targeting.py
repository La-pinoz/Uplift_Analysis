"""Rules that more than one notebook must apply identically: top-K selection, arm balance and the holdout freeze."""
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
    ranks = np.asarray(ranks)
    if ranks.ndim != 1 or len(ranks) == 0:
        raise ValueError("ranks must be one-dimensional and not empty")
    if ranks.dtype.kind not in "iu" or ranks.min() < 0:
        raise ValueError("ranks must be whole, non-negative numbers, as score_ranks returns")
    if isinstance(percent, (bool, np.bool_)) or not isinstance(percent, (int, np.integer)) or not 1 <= percent <= 100:
        raise ValueError("percent must be a whole number from 1 to 100")

    size = (int(percent) * len(ranks) + 50) // 100
    if size == 0:
        raise ValueError("This percent selects no customers")

    mask = np.zeros(len(ranks), dtype=bool)
    mask[np.argsort(ranks, kind="stable")[:size]] = True
    return mask


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
