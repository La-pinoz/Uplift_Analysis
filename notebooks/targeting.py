"""The one definition of a top-K target group, shared by the notebooks that need it."""
import numpy as np


def score_ranks(client_ids, scores):
    """Return each customer's rank, in input order, where 0 is the best.

    Customers are ordered by score descending, then `client_id` ascending. IDs must be unique
    strings and scores must be finite, so a bad join stops here rather than changing the group.
    """
    ids = np.asarray(client_ids, dtype=object)
    values = np.asarray(scores, dtype=np.float64)

    if ids.ndim != 1 or values.ndim != 1 or len(ids) != len(values):
        raise ValueError("client_ids and scores must be one-dimensional and the same length")
    if len(ids) == 0:
        raise ValueError("No customers to rank")
    if not all(isinstance(client_id, str) for client_id in ids):
        raise ValueError("client_ids must all be strings")
    if len(set(ids)) != len(ids):
        raise ValueError("client_ids must be unique")
    if not np.isfinite(values).all():
        raise ValueError("scores must be finite")

    # lexsort treats its last key as the primary one.
    order = np.lexsort((ids.astype(str), -values))
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
