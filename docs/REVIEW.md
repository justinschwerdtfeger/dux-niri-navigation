# Codebase review — 2026-10-10

Reviewed the complete tracked plugin, pure models, scripts, tests, manifests, and documentation against installed/active DMS 1.6.2. Preserve the existing visual style; improve correctness, state updates, DMS consistency, and repeatable checks.

## Changes

| Finding                                                                                       | Resolution                                                                                                                  |
| --------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| Views duplicated ListModel reconciliation and rewrote unchanged roles                         | Shared `ModelUtils.syncRows`; preserve delegates and write only changed roles; exhaustive small-list edit tests             |
| Workspace seeding repeatedly filtered/sorted all windows and serialized whole assignment maps | One-pass first-window index; retain unchanged assignments by identity                                                       |
| Favicon matching repeatedly scanned all active tabs                                           | One title-index pass; preserve conservative duplicate agreement and handle arbitrary page titles                            |
| Drag acknowledgment logic lived inside a large QML adapter                                    | Pure `ReorderModel` with focus/layout sequencing tests; QML owns dispatch and timeout                                       |
| Row and preview-offset animations could conflict during drag acknowledgment                   | One animated absolute visual position per tab, keyed by ID; retain dropped-tab stacking/background                          |
| Navigation buttons lacked consistent keyboard activation/focus feedback                       | Enter/Return/Space activation and theme-colored focus outline                                                               |
| Inline favicon files accumulated across a long shell session                                  | Remove files once no profile references them; add lifecycle regression                                                      |
| A startup profile could disappear between D-Bus discovery calls                               | Ignore that discovery race and keep subscribing to other profiles                                                           |
| QML, JS, Python, shell, and docs lacked enforced lint/format checks                           | Qt tools, ESLint, Ruff, ShellCheck, Prettier, pinned development dependencies, explicit check targets, working devcontainer |
| Current docs contradicted scroll defaults and repeated obsolete experiments                   | Rewrite around current contracts, API baseline, validation matrix, and acceptance checks                                    |
| Optional tab-detaching extension broadened scope                                              | Remove it and its tests/docs at the user’s request; keep independent TabCtl favicon support                                 |

The icon picker retains its current controls/layout at the user’s request. No automatic-reset action was added. Desktop configuration was not reconfigured.

## Validation

The Docker devcontainer builds successfully, is accessible through the Dev Container CLI, and runs checks as an unprivileged user against the mounted repository. `make check` passes: packaging, 53 JavaScript behavior tests, 16 Python tests, ESLint, Ruff lint/format, Prettier, ShellCheck, strict zero-warning QML lint, QML format consistency, and diff whitespace. `make test-qml` passes all five component tests plus initialization/cleanup (seven QtTest passes).

With user authorization, restarted the existing DMS service after a plugin reload retained an old helper component. Both plugin instances then loaded without plugin QML errors. The user reports improved release-time tab movement. The isolated drag test samples settled preview positions throughout an order acknowledgment; it also passes against the old animation implementation, so it does not independently reproduce the original bug. Rapid/partial acknowledgments, changing tab widths, and overflow drops still need broader live acceptance.

Live read-only inspection matched all 12 Helium windows to valid favicon URLs and confirmed TabCtl helper/extension compatibility. It also confirmed the installed TabCtl 2.3.0 event listener omits favicon-only notifications. With explicit user authorization, patched the separate TabCtl source to emit on favicon changes/completed loads. All 36 extension tests pass. The user loaded the local 2.3.0.1 test build; `tabctl status` confirms its connection. A local fixture changed only its icon after six seconds, and the actual subscriber emitted distinct icon snapshots. The user confirmed the DMS icon changed from red to green. See [Configuration](CONFIGURATION.md).

Runtime validation must still distinguish matching, notification delivery, and image readiness. Visible workspace-rail acceptance, unusual center modes/multiple growing instances, and compositor generation/ID reuse remain compatibility limits. See [Development](DEVELOPMENT.md#runtime-acceptance).

Earlier implementation and review notes remain in Git history, including the 2026-09-30 review. They are historical evidence, not the current API or behavior contract.
