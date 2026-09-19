# Rotorflight configuration and MSP from Ethos

Use ordinary Ethos sources or the Suite dashboard telemetry facade when the
requested value is already available there. An internal Suite alias is not
a sensor display name. Read [rotorflight-telemetry-sensors.md](rotorflight-telemetry-sensors.md)
for that distinction.

## Inside the rewritten suite

Read the current page/runtime/codec callers before adding a request. In the
checkout audited 2026-09-07:

- `app/page_runtime.lua` owns reusable page loading/saving behavior.
- `lib/msp_*.lua` and `lib/mspcodec.lua` encode/decode versioned messages.
- `lib/bus.lua` carries requests between app and background task.
- `tasks/msp/queue.lua`, `common.lua`, and `transport_select.lua` own the
  background queue, framing, and selected transport.
- `tasks/msp/transport_crsf.lua` and `transport_sport.lua` are private to that
  subsystem. A dashboard theme or app page must not load them directly and
  compete to drain the radio's raw response frames.

Reuse the closest actual page and codec for API-version handling, connection
gates, timeout/error UI, save completion, and cancellation/close cleanup.
Do not copy pre-rewrite `tasks/scheduler/msp/api/...` paths or assume every
codec exposes the old field-spec API. Inspect the code being integrated.

## Independent standalone MSP implementations

Only build a separate transport when the requested product actually needs
one. Check official Ethos `crsf`, `sport`, or `multimodule` APIs for the radio
and receiver arrangement. Rotorflight Suite supports both CRSF and S.Port;
MSP-over-CRSF is not the universal Ethos transport.

For CRSF, MSP frame types are `0x7A` request, `0x7B` response, and `0x7C`
write. The outer payload addresses are **destination first, origin second**:
requests use `{0xC8, 0xEA, ...}` (FC then radio), replies reverse those
addresses. Those bytes precede a properly encoded MSP-over-CRSF chunk, not a
bare command ID or an arbitrary MSP serial frame.

Consult the current Rotorflight firmware protocol and working transport for
chunk headers, sequence handling, checksums, payload bounds, and API-specific
message fields. Validate the entire response before decoding. The previous
skill's short frame example was not a complete interoperable MSP stack.

Poll without blocking; reuse transmit/receive buffers, bound queue growth,
and handle missing sensors, dropped/out-of-order chunks, timeout, disconnect,
and stale callbacks after close. Serialize competing requests through one
owner. Verify writes against the target API and surface acknowledgement/
failure rather than announcing success when a request is merely queued.
