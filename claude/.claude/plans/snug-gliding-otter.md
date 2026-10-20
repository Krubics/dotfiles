# Plan: Cancel protective legs (broker-confirmed) before a manual exit — IBKR + Moomoo

## Context

A manual SELL/TRIM on a held position is currently placed **before** its protective
legs (stop-loss / take-profit) are cleared. On Moomoo the resting protective SELLs
reserve the position's quantity, so the manual exit is rejected by the gateway with
**"Not enough positions"** even though the contract is fully held. This got worse after
we made the protective legs GTC earlier this session — they now survive across days, so
the reservation never clears on a multi-day hold.

Current order of operations in [`_handle_exit`](only_trades/executor.py#L328) (lines
355-373): place the sell first, then call
[`_reconcile_protective_on_exit`](only_trades/executor.py#L463) to resize/cancel the legs
— too late, and it only runs if the sell actually filled.

**Desired outcome (confirmed with user):** for a manual exit, reconcile the protective
legs to the post-exit remaining coverage, **wait until the broker confirms** the
cancel/reduction, then place the manual exit. On a partial exit (trim) the kept
contracts stay protected (legs shrunk to the remaining qty, not left naked). If the
broker does not confirm within a timeout, **abort the exit and alert** (never send a sell
that will be rejected). Applies uniformly to **IBKR and Moomoo**.

Key facts that shape the design:
- Both adapters' `cancel`/`modify` are fire-and-forget; confirmation only arrives later
  via the order-update callback. We need a way to *read* the broker's current state.
- Broker-live protective legs exist only for **filled positions**. A standing (unfilled)
  entry's protective rows are still PENDING and not placed at the broker
  (Moomoo defers arming to entry fill; IBKR arms OCA children only on fill), so they do
  not reserve quantity. The confirmation gate therefore applies to the **position sell**,
  which is the only order that reserves held quantity.

## Approach

### 1. New broker-neutral read: `working_qty(order_ref) -> int`

Add to [`BrokerProtocol`](only_trades/brokers/protocol.py) a method returning the broker's
current *unfilled* quantity for a ref, `0` if unknown/terminal. This is the
broker-confirmation primitive (works for both a full cancel → 0 and a shrink → reduced).

- **IBKR** ([ibkr.py](only_trades/brokers/ibkr.py)): reuse
  [`_lookup_trade`](only_trades/brokers/ibkr.py#L204); `None` or `trade.isDone()` → `0`;
  else `int(round(trade.remaining()))`.
- **Moomoo** ([moomoo.py](only_trades/brokers/moomoo.py)): `order_list_query` (already used
  by [`resync`](only_trades/brokers/moomoo.py#L436)); match the row whose `remark == ref`
  (or map via [`_oid_for_ref`](only_trades/brokers/moomoo.py#L320)); terminal status → `0`;
  else `qty - dealt_qty`.

The existing [`test_broker_protocol.py`](tests/test_broker_protocol.py) conformance check
guarantees both adapters implement it.

### 2. Executor: reconcile + confirm BEFORE the sell

Reorder [`_handle_exit`](only_trades/executor.py#L328) so protection is freed first:

- Compute the intended exit up front from **pure** decisions (no placement):
  - position: reuse [`risk.decide_exit`](only_trades/risk.py#L54) for the intended sold qty,
    folding in the existing [`has_working_exit`](only_trades/orders.py#L242) guard so an
    `exit_in_flight` contract plans `0` (and is left untouched).
  - standing: extract the trim/cancel math from
    [`_exit_standing`](only_trades/executor.py#L423) into a pure helper for the intended
    standing-left qty.
  - `remaining = max(0, floor(pos_net) - intended_sold) + intended_standing_left`.
- New helper `_free_protective_confirmed(trader_id, occ, remaining, *, timeout, poll) -> bool`:
  1. snapshot the contract's protective leg refs via
     [`working_protective_for_contract`](only_trades/orders.py#L369);
  2. call the existing `_reconcile_protective_on_exit(trader_id, occ, remaining)` to issue
     the cancel/modify (+ its current optimistic DB write);
  3. poll `sum(self.ib.working_qty(ref))` over those refs until `<= remaining` or the
     timeout elapses; return the result. (PENDING standing legs report `0` at the broker,
     so they never block confirmation.)
- Gate the **position sell** on it: only when `intended_sold > 0`, call
  `_free_protective_confirmed(...)`. On `False` → `_notify_alert("exit_aborted", …)` and
  **skip this contract entirely** (place nothing); on `True` → proceed.
- Place the exit (`_exit_position` / `_exit_standing`) as today, and **remove** the now-
  redundant post-sell `_reconcile_protective_on_exit` block (lines 366-373). To keep all
  gates ahead of touching protection, ensure `qualify` runs before the free step (qualify
  a held contract effectively never fails, but ordering it first avoids any under-protect
  window); simplest is to have `_exit_position` run its decide → has_working_exit →
  qualify gates, then invoke the free-and-confirm step immediately before
  [`_place_and_record`](only_trades/executor.py#L494), aborting (return 0 + alert) if it
  fails.

Add a small `_notify_alert` executor helper (guarded, mirrors existing
`_notify_*`) that forwards to `notifier.notify_alert` (already used by
[safety.py](only_trades/safety.py#L161)).

### 3. Config

Add `protective_cancel_timeout_s` (default ~5.0) and `protective_cancel_poll_s`
(default ~0.25) to the `ORDER_POLICY` block in `config.json` / [config.py](only_trades/config.py),
per the repo convention that order-shape tuning lives in `ORDER_POLICY` (not the executor).

## Files to modify

- [only_trades/brokers/protocol.py](only_trades/brokers/protocol.py) — declare `working_qty`.
- [only_trades/brokers/ibkr.py](only_trades/brokers/ibkr.py) — implement `working_qty`.
- [only_trades/brokers/moomoo.py](only_trades/brokers/moomoo.py) — implement `working_qty`.
- [only_trades/executor.py](only_trades/executor.py) — reorder exit flow; add
  `_free_protective_confirmed`, pure planning helpers, `_notify_alert`; drop the post-sell reconcile.
- [only_trades/config.py](only_trades/config.py) + `config.json` — timeout/poll knobs.
- [order_processing.md](order_processing.md) — document the new "cancel-confirm-then-sell" ordering.

## Verification

- **Unit tests** ([tests/test_executor.py](tests/test_executor.py)): extend the fake broker
  with `working_qty` and record call order. Assert:
  - full exit → protective legs cancelled AND broker-confirmed (`working_qty`→0) **before**
    the SELL is placed;
  - trim → legs shrunk to the remaining qty, confirmed, then partial SELL; remaining still
    has protective coverage;
  - confirmation timeout (fake `working_qty` never drops) → **no** SELL placed and
    `notify_alert` fired;
  - `exit_in_flight` / no-position paths unchanged.
- **Protocol conformance**: `PYTHONPATH=. .venv/bin/pytest tests/test_broker_protocol.py -q`.
- **Full suite**: `PYTHONPATH=. .venv/bin/pytest -q`.
- **Manual smoke (paper)**: with a held Moomoo position that has resting GTC stop/TP,
  send a SELL; confirm in logs the legs are cancelled + confirmed before the exit, and the
  exit is accepted (no "Not enough positions").
