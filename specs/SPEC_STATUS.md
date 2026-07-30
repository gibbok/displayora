# Displayora Specification Status

This tracker is authoritative. Update one row at a time according to
[README.md](README.md).

Specification states: `Planned`, `Drafting`, `Ready`, `Blocked`.

Implementation states: `Not started`, `In progress`, `Verified`, `Deferred`,
`Omitted`, `Blocked`.

Code-review states: `Not reviewed`, `Reviewing`, `Changes requested`,
`Approved`.

| ID | Specification | Dependencies | Specification | Implementation | Code review |
|---|---|---|---|---|---|
| 01 | Project Foundation | — | Ready | Verified | Approved |
| 02 | Menu-Bar Shell and Onboarding | 01 | Ready | Verified | Approved |
| 03 | Display Platform and Capabilities | 01, 02 | Ready | In progress | Not reviewed |
| 04 | Brightness | 01, 02, 03 | Ready | Not started | Not reviewed |
| 05 | Contrast | 01, 02, 03 | Ready | Not started | Not reviewed |
| 06 | Volume and Mute | 01, 02, 03 | Ready | Not started | Not reviewed |
| 07 | Resolution Selector | 01, 02, 03 | Ready | Not started | Not reviewed |
| 08 | Keyboard Controls | 01, 02, 03 | Ready | Not started | Not reviewed |
| 09 | Disable and Re-enable Display | 01, 02, 03 | Ready | Not started | Not reviewed |
| 10 | Night Comfort | 01, 02, 03 | Ready | Not started | Not reviewed |
| 11 | Direct Distribution and Release | 01, 02, 03 | Ready | Not started | Not reviewed |

## Platform validation

- **Specification 01 — Project Foundation:** the product scope is Intel macOS
  only. Validation is performed on a native Intel host; Apple Silicon is out of
  scope.
