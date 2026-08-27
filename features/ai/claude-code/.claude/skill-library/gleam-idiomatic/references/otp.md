# gleam_otp

Fault-tolerant, multi-core programs on the BEAM using OTP (actors, supervisors).

**Package:** [gleam_otp on Hex](https://hex.pm/packages/gleam_otp)  
**Docs:** [HexDocs](https://hexdocs.pm/gleam_otp/)

## When to use

- Long-lived stateful processes (actors).
- Supervision trees: restart child processes on crash.
- Erlang/OTP compatibility and tooling (debugging, tracing).

## Entrypoints

- **actor** — Main building block: `actor.new(initial_state)`, `actor.on_message(handle_message)`, `actor.start(...)`. Handle messages by returning `actor.continue(new_state)` or sending replies. Use `actor.send(pid, message)` and `actor.call(pid, waiting:, sending:)` for request–reply.
- **gleam/otp/static_supervisor** — Start and supervise a fixed set of child processes; restart them if they crash.

## Notes

- Actors are type-safe: message type and state type are explicit.
- Not all OTP system messages are supported yet; some debugging APIs may be limited.
