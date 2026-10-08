# Meo AI Router session contract

`meo-ai-router` owns `org.meo.AIRouter1` on the user session bus at
`/org/meo/AIRouter1`. It has no root authority. Its first executable capability
is `org.meo.application.launch`, which accepts exactly one string argument,
`desktopId`, and launches only an installed application desktop entry through
KIO. `org.meo.desktop.audio.setVolume` accepts an integer `percent` from 0 to
100 and calls the same PulseAudioQt sink authority used by Meo.System.
`org.meo.desktop.audio.getVolume` reads the same default sink without arguments.
`org.meo.settings.openPage` accepts a fixed page key and activates Meo Settings'
installed page desktop entry; Meo Settings owns the destination page.
Direct Do Not Disturb control and System Monitor summaries are not registered
until their owning components expose a maintained typed runtime interface.
`SubmitRequest(capabilityId, arguments)` dispatches these typed capabilities
without a Router confirmation card. `ListCapabilities()` reports the currently
executable allowlist. `GetRequest(requestId)` is limited to the original D-Bus
caller. Requests and results are transient daemon memory.

## Capability metadata

Each registered capability has machine-readable metadata in addition to its
typed argument schema. `ListCapabilities()` returns this metadata only for
capabilities that are actually executable in the current Router policy.

The current metadata fields are:

- `id` — stable capability identifier;
- `title` — trusted human-readable action title;
- `owner` — component namespace responsible for the action;
- `effect` — one of `read`, `session`, `persistent`, or `irreversible`;
- `verification` — the result contract used by the owning dispatcher (`owner-result` or `read-back`);
- `maturity` — `preview` or `stable`;
- `requiresConfirmation` — whether the Router confirmation protocol applies;
- `argumentSchema` — Router-owned JSON-Schema-shaped metadata for the exact typed argument object.

`argumentSchema` is generated from the same `Capability.arguments` table used by
`SubmitRequest()` type validation unless an owner supplies a richer schema. A
supplied schema is accepted only when its required keys and JSON types still
match the authoritative QMetaType argument table. This lets clients expose
argument names and constraints without copying an allowlist or inventing types,
while the Router remains the final validator at execution time.

A capability that does not provide an explicit owner derives it conservatively
from its capability namespace by removing the final action segment. For
example `org.meo.desktop.audio.setVolume` derives the owner
`org.meo.desktop.audio`. An identifier that cannot produce a meaningful owner
namespace is rejected at registration time.

Maturity is deliberately independent from availability. A `preview` capability
may be executable and tested while still carrying a narrower compatibility or
acceptance guarantee. Adding metadata must never promote a capability to
`stable` implicitly. Likewise, metadata never grants authority: the Router
still validates the capability ID, exact typed arguments, effect policy,
caller binding, and confirmation fingerprint before dispatch.

The verification field describes the dispatcher's completion contract, not a
promise that the Router independently understands every subsystem. An owner
may complete a request from its authoritative operation result, or use a
read-back check when the capability requires state verification. Either way,
state-changing integrations should prefer an authoritative post-operation
check when practical.

`SubmitText(text)` resolves an unambiguous installed application name after
`open` or `打开`, simple `set volume to 30%` / `音量调到30%` requests,
and current-volume queries locally,
so those paths work offline. Otherwise it asks the
Meo Account `org.meo.Accounts1` broker to resolve a request only when a
connection has a saved prompt-free grant and a default
model. It sends the user's typed text with purpose `system_ai_routing` and the
sole data category `user_prompt`. The Router never reads a provider key. It
prefers an opted-in Ollama connection over an opted-in cloud connection. The
model's JSON is parsed as untrusted input and must still name an allowlisted
capability with exact typed arguments; invalid or invented actions are rejected.
Without a grant, the response is a Settings handoff. Account remains the
authority for that grant and any per-request inference consent. Account
inference permission never authorizes an OS action.

`DecideRequest(requestId, fingerprint, approve)` is the separate OS action
confirmation interface. Only an irreversible capability may enter
`awaiting_confirmation`; the card shows its trusted title, specific target and
impact. The request binds its capability and typed arguments to a SHA-256
fingerprint, the caller's session-bus name, and a 30-second expiry. Denial,
dismissal, expiry, caller mismatch and changed content cannot execute it.
The first release disables all irreversible capabilities, including those
registered internally, so no destructive action is reachable. Reversible
installation and repair still use their owning applications' existing
confirmation and Polkit flows; Router approval cannot bypass them.

Static builds and offscreen tests validate only the source and protocol.
Real Account/KWallet, Plasma application activation and user interaction need
separate session testing.
