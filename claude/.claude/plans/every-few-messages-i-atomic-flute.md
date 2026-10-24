# Fix: intermittent DeepSeek "Timeout" errors dropping trade signals

## Context

Every few messages, the log shows:

```
LLM error: litellm.Timeout: Timeout Error: DeepseekException - litellm.Timeout: Connection
timed out. Timeout passed=20.0, time taken=0.002 seconds
```

The `time taken=0.002 seconds` is the giveaway: this is not a real 20s stall. Verified in
this repo's installed litellm (1.90.0): DeepSeek's chat path routes through litellm's
`base_llm_http_handler` (custom httpx client, not the OpenAI SDK client), whose
`except httpx.TimeoutException` blocks catch **any** timeout-flavored httpx exception —
`ConnectTimeout`, `PoolTimeout`, `ReadTimeout` alike — and re-raise them all as
`litellm.Timeout`, regardless of how little time elapsed. litellm also caches/reuses a
single global `httpx.AsyncClient` per provider with no concurrency limit. So a near-instant
`ConnectTimeout`/`PoolTimeout` — pool contention or a stale pooled connection under bursty
concurrent message load — produces exactly this "20s timeout in 0.002s" signature. It is
not a genuine network stall; it's a transient connection blip mislabeled by litellm.

Also confirmed: `num_retries`/`max_retries` on `litellm.acompletion` is **never read** by
the `base_llm_http_handler` completion path DeepSeek uses (only wired for unrelated
OCR/transcription paths) — so litellm's built-in retry is a no-op here. A manual retry is
required.

**Exactly which exceptions count as "network error"**: in
`llms/custom_httpx/http_handler.py`, every request path has this shape:

```python
try:
    response = await client.send(request)
except httpx.TimeoutException as e:      # no HTTP response ever received
    raise litellm.Timeout(...)
except httpx.HTTPStatusError as e:       # a real HTTP response came back (4xx/5xx)
    raise <BadRequestError/RateLimitError/AuthenticationError/InternalServerError/...>(...)
```

`httpx.TimeoutException` is httpx's shared base for `ConnectTimeout`, `ReadTimeout`,
`WriteTimeout`, and `PoolTimeout` — litellm maps all four to `litellm.Timeout` even though
only `ReadTimeout` is a genuine "waited the full 20s" case; the other three (connection
refused/pool exhausted/stale pooled connection) fail almost instantly, which is exactly
what `time taken=0.002 seconds` shows. Verified class hierarchy:
`litellm.Timeout -> APITimeoutError -> APIConnectionError -> APIError`, while
`BadRequestError`, `RateLimitError`, `AuthenticationError`, `InternalServerError`,
`ServiceUnavailableError` are **siblings** of `APIConnectionError` (they come from the
separate `httpx.HTTPStatusError` branch, i.e. DeepSeek actually responded). So catching
`litellm.APIConnectionError` (which covers `Timeout`) retries precisely "network error, no
response received" and structurally cannot catch a real DeepSeek API response error (bad
request, rate limit, auth, 5xx) — those are a different exception branch entirely and must
never be retried.

**User-visible impact today**: `only_trades/llm_parser.py:interpret()` makes a single
`acompletion` call with no retry. When this blip hits, `executor.py:167-170`
(`process_message`) sees `interp.error` set, logs a warning, sends a Discord "notify only"
message, and **returns — the trade signal is permanently dropped**, never retried. A real
buy/sell signal from a trader is silently lost whenever this transient connection hiccup
occurs.

The fix: retry only the connection-flavored failure inside `interpret()` (short exponential
backoff with jitter, since the cause is load-related pool contention — unjittered retries
risk re-triggering the same contention), while leaving deterministic failures (malformed
JSON, schema errors, auth errors) to fail fast as today. This keeps the "LLM never raises
into the executor loop" invariant intact and needs no change to `executor.py`'s
error-handling behavior itself.

## Changes

### `only_trades/llm_parser.py`
- Add `import asyncio`, `import random`.
- Add `_TRANSIENT_EXC = (litellm.APIConnectionError,)` at module level with a short comment
  explaining this is deliberately network-error-only: `litellm.Timeout` is a subclass of
  `APIConnectionError` (so the reported error is covered), while `BadRequestError`,
  `RateLimitError`, `AuthenticationError`, `InternalServerError`, and
  `ServiceUnavailableError` are siblings, not subclasses — a real DeepSeek response (4xx/5xx)
  can never match this tuple and will always fall through to the non-retried path below.
- Add two new keyword params to `interpret()`: `retry_attempts: int = 2` (extra attempts
  after the first, so 3 calls total) and `retry_base_delay: float = 0.25`.
- Restructure the body so **only the `acompletion` call** is inside the retry loop; JSON
  parsing (`_extract_json` / `json.loads`) stays in the existing single-shot
  except-and-return-error path, unchanged:
  - `for attempt in range(retry_attempts + 1):` call `acompletion`.
  - On `_TRANSIENT_EXC` with attempts remaining: `log.warning(...)` naming the attempt
    number, `await asyncio.sleep(retry_base_delay * 2**attempt + random.uniform(0, retry_base_delay))`,
    then continue the loop.
  - On `_TRANSIENT_EXC` with attempts exhausted: `log.error(...)` once, return
    `Interpretation(None, 0.0, "", error=str(e))` — same shape as today's error path.
  - Any other `Exception` (e.g. JSON parse failure, schema error, non-transient API error):
    unchanged behavior — immediate `log.warning` + error return, no retry wasted.
- `interpret()`'s "never raises into the executor loop" contract is preserved: both exit
  paths return an `Interpretation`.

### `only_trades/config.py`
- Add `retry_attempts: int = 2` to `LLMConfig` (`config.py:39-46`), parsed from
  `LLM.RETRY_ATTEMPTS` in `load_config` (`config.py:173-178`), mirroring the existing
  `timeout`/`TIMEOUT` two-line pattern exactly. This is the one new config surface —
  justified because it's operationally tunable exactly like `timeout` already is.

### `only_trades/executor.py`
- One line added to the existing call to `self._interpret(...)` (`executor.py:147-153`):
  `retry_attempts=self.config.llm.retry_attempts,` alongside the existing `timeout=...`.
  No other change — the downstream error handling at `executor.py:167-170` (log, notify
  once, drop) stays exactly as-is; it's now just reached far less often.

### `tests/test_llm_parser.py`
- Extend the `_patch` fixture (currently line 25-30, single fixed exception/payload) to
  support a **sequence** of behaviors consumed in order via a call counter, so a test can
  simulate "fails twice, succeeds on the third call."
- Existing `test_api_error_has_no_trade_and_sets_error` (line 78-80, uses plain
  `RuntimeError`) needs no change — `RuntimeError` isn't in `_TRANSIENT_EXC`, so it still
  fails on the first attempt with no retry.
- New test: a transient exception (e.g. `litellm.APIConnectionError`) on the first call(s)
  followed by a successful payload returns the successful `Interpretation`.
- New test: transient exception on every attempt exhausts retries, returns an error
  `Interpretation` (never raises), and the call count equals `retry_attempts + 1`.
- New test: a non-transient exception makes exactly one call (no retry wasted).
- Pass `retry_base_delay=0` in these new test calls to keep them fast without needing to
  monkeypatch `asyncio.sleep`.

## Verification
- `PYTHONPATH=. .venv/bin/pytest tests/test_llm_parser.py -q` — new + existing tests green.
- `PYTHONPATH=. .venv/bin/pytest -q` — full suite unaffected (executor tests still pass
  `timeout=` plus the new `retry_attempts=` kwarg through the same fake `_interpret`
  callable pattern already used in `tests/test_executor.py`).
- Manually trigger a transient failure once (e.g. temporarily monkeypatch
  `litellm.acompletion` to raise `litellm.APIConnectionError` on the first call only) to
  confirm a message that previously would've been dropped now succeeds on retry, and that
  the WARNING-per-attempt / ERROR-on-give-up log lines appear as expected.
