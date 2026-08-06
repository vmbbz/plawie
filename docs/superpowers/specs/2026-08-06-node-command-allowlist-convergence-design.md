# Native Node Command Allowlist Convergence Design

## Goal

Make native Gateway startup converge after Plawie adds the bounded, read-only
payment and bridge node commands. The Android node must pair once, retain the
full approved command snapshot, and stop reconnecting every watchdog interval.
PRoot behavior is unchanged and remains the explicit fallback path.

## Confirmed Failure

The installed Android client declares 82 node commands. Official OpenClaw
2026.7.1 normalizes that declaration through
`gateway.nodes.allowCommands` before it creates a pending node-pairing request.
Plawie's central `GatewayToolCatalog.mobileNodeAllowCommands` currently omits
the eight payment and bridge entries, so OpenClaw persists a valid 74-command
snapshot.

Plawie's pairing repair then compares the stored 74 commands against all 82
declared commands. It interprets the intentional OpenClaw filtering as a stale
snapshot, clears pairing, reconnects, approves the same 74-command surface, and
repeats approximately every 30 seconds. Gateway RPC itself becomes live, but
the repair loop wastes work and can leave startup UI in a misleading settling
state.

The four most recent commits did not modify Gateway startup or node pairing.
The mismatch was introduced earlier when the payment and bridge capabilities
were declared without adding them to the central node-command allowlist, then
became visible after the recent APK reinstall/restart forced pairing repair.

## Approved Approach

Add exactly these commands to
`GatewayToolCatalog.mobileNodeAllowCommands`:

```text
payments.capabilities
payments.status
payments.receipts
payments_capabilities
payments_status
payments_receipts
bridge.capabilities
bridge.quote
```

These are the complete command set emitted by `AiPaymentsCapability` through
`NodeProvider`'s canonical and underscore-alias registration rules. No payment
approval, wallet unlock, signing, transaction submission, broadcasting, or
bridge execution command is added.

The existing `GatewayService._ensureNodeAllowCommands()` remains the owner of
the startup migration. It rewrites the native active-owner config from the
central catalog before the Gateway starts. On the next startup, official
OpenClaw therefore includes all 82 declared commands in the pending approval
surface. The existing command-contract repair performs one reapproval and then
stores the complete snapshot and contract hash.

## Alternatives Rejected

### Treat the 74-command snapshot as complete

This would stop the reconnect loop but make the payment and bridge node tools
unavailable while the app claims they are supported. It would hide the config
defect instead of repairing it.

### Automatically allow every declared node command

This would avoid future catalog drift but remove the deliberate reviewed
security boundary. A newly registered command could become Gateway-callable
without an explicit policy change. The central bounded allowlist remains the
production contract.

## Startup and Migration Flow

```text
NodeProvider registers 82 bounded commands
        |
GatewayService writes central allowCommands before native startup
        |
Official OpenClaw filters the declaration against the allowlist
        |
Pending node request contains all 82 commands
        |
Visible local Gateway RPC approves the pending request
        |
nodes/paired.json stores all 82 commands
        |
Plawie records the command-contract hash and watchdog becomes a no-op
```

Existing users do not need to clear data. The next in-place app launch updates
the native config before Gateway startup. If a 74-command pairing record is
already present, the existing repair path replaces it with the newly approved
82-command snapshot. Fresh installs receive the same catalog through the setup
config path.

## Failure Handling

- Config writes remain fail-closed through the existing active-owner config
  writer; no direct ad hoc Android file mutation is introduced.
- Pairing is not considered repaired until the persisted Gateway snapshot
  covers every currently declared command.
- The app must not accept a filtered snapshot merely to suppress retries.
- The app must not restart the Gateway when only node pairing is incomplete.
- Logs should distinguish Gateway readiness from node command-contract repair.
- No PRoot command, PRoot config rewrite, or PRoot process may be started while
  native remains the selected owner.

## Tests

Implementation follows test-driven development:

1. Add a failing contract test proving all commands exposed by
   `AiPaymentsCapability` and the `NodeProvider` alias rules exist in
   `GatewayToolCatalog.mobileNodeAllowCommands`.
2. Assert the allowlist contains exactly the eight approved payment/bridge
   entries and contains no signing or execution command.
3. Retain existing node-pairing snapshot tests to prove the repair path still
   rejects genuinely incomplete approved snapshots.
4. Run the focused payment, bridge, Gateway catalog, node pairing, and bootstrap
   tests, followed by the complete Flutter test suite.
5. Build one debug APK, install it in place without clearing app data, and
   observe a cold native startup. Device evidence must show Gateway RPC ready,
   one successful node approval, an 82-command stored pairing snapshot, and no
   recurring pairing refresh over at least two watchdog intervals.

## Documentation

Update `docs/TOOLS_SKILLS_GATEWAY_ARCHITECTURE.md` so payment and bridge
commands are listed under the reviewed `gateway.nodes.allowCommands` boundary.
No broader wallet, x402, provider, or bridge-execution architecture changes are
part of this fix.

## Release Boundaries

- Native embedded Node remains the primary runtime.
- Official OpenClaw remains downloaded independently during setup and is not
  bundled into the APK.
- PRoot remains fallback-only and is not touched by this migration.
- APKs, `libnode.so`, manifests generated from local binaries, Gradle reports,
  and temporary device logs are not committed.

## Success Criteria

- Native Gateway reaches RPC-ready normally.
- The paired Android node snapshot contains all 82 declared commands.
- Payment and bridge status/quote commands are callable through the existing
  read-only capability boundary.
- No node command-contract re-pair occurs on subsequent watchdog ticks.
- Existing non-payment mobile capabilities continue to work unchanged.
