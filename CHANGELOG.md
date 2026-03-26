# Changelog

## v1.1.5 — 2026-03-29
- Rebranding :) to `php-opcua/opcua-test-suite`

## v1.1.4 — 2026-03-19

### Address Space

- **extension-objects.js**: Added new `ExtensionObjects` module with custom
  structured data types defined via a NodeSet XML file (`config/custom-types.xml`).
  Two new variables: `PointValue` (RW, `TestPointXYZ` with X/Y/Z Double fields)
  and `RangeValue` (R, `TestRangeStruct` with Min/Max/Value Double fields).
  Custom types are loaded as an additional nodeset at server startup.

### Server

- **config.js / index.js**: Added configurable OPC UA operation limits via
  environment variables: `OPCUA_MAX_NODES_PER_READ`, `OPCUA_MAX_NODES_PER_WRITE`,
  `OPCUA_MAX_NODES_PER_BROWSE`. When set to a value > 0, the server binds the
  corresponding standard OPC UA ServerCapabilities nodes (`i=11705`, `i=11707`,
  `i=11710`). Default is `0` (unlimited).

- **config.js**: Added `OPCUA_CUSTOM_TYPES_FILE` environment variable to specify
  the path to a custom NodeSet XML file (default: `config/custom-types.xml`).

### Dependencies

- **package.json**: Bumped `node-opcua` from `^2.133.0` to `^2.165.0`.

### Docker

- **docker-compose.yml**: Added `OPCUA_MAX_NODES_PER_READ: "5"` and
  `OPCUA_MAX_NODES_PER_WRITE: "5"` to `opcua-no-security` and
  `opcua-all-security` services for operation limit testing.

## v1.1.3 — 2026-03-18

### Actions

- **docker-publish.yml**: Updated Docker actions to Node.js 24-compatible
  versions: `docker/setup-buildx-action` v3→v4, `docker/login-action` v3→v4,
  `docker/metadata-action` v5→v6, `docker/build-push-action` v5→v6.

## v1.1.2 — 2026-03-16

### Actions
- **action.yml**: update action\checkout to v6
- **.github/workflows/docker-publish.yml**: update action\checkout to v6
## v1.1.1 — 2026-03-15

### Docker

- **Dockerfile**: Upgraded Node.js from 20 to 24 (Alpine). No breaking changes
  on dependencies (`node-opcua`, `node-opcua-pki`).

### Certificates

- **generate-certs.sh**: Added skip of certificate regeneration if already
  present (`ca-cert.pem`, `server/cert.pem`, `client/cert.pem`). Prevents
  unnecessary regeneration on subsequent `docker compose up`. To force
  regeneration set `FORCE_REGEN=1` or delete the `certs/` directory.

## v1.1.0 — 2026-03-14

### GitHub Action & CI

- **action.yml**: Fixed bug using `github.action_repository` (empty in
  composite actions) with fallback to `github.repository`, causing the wrong
  Docker image to be pulled (`opcua-php` instead of `opcua-test-suite`).
  The GHCR image name is now correctly hardcoded.

- **action.yml**: Added GHCR login step with `github.token` to support
  private images.

- **action.yml**: Certificates are now read directly from the bind mount
  (`./certs`) instead of extracting them from a Docker volume via a temporary
  container, eliminating volume-not-found issues in CI.

- **docker-compose.ci.yml**: Changed from Docker volume (`certs-volume`) to bind
  mount (`./certs`), aligned with `docker-compose.yml`. Certificates are
  accessible directly on the host filesystem without extraction.

### Certificates & PKI

- **generate-certs.sh**: Added CRL (Certificate Revocation List) generation for
  the CA. node-opcua requires a CRL to verify client certificate revocation
  status. Without a CRL, the server rejects all secure connections with
  `BadCertificateRevocationUnknown (0x801b0000)`, even with `autoAcceptCerts: true`.

- **index.js**: Restructured PKI management with `populatePki()`.
  CA certificates and the CRL are now copied into PKI directories **before**
  `certificateManager.initialize()`, because node-opcua indexes CRL files
  during initialization and does not detect them if added afterwards.

- **index.js**: Added `userCertificateManager` for X509 authentication.
  node-opcua uses two separate certificate managers: one for the transport layer
  (OPN/SecureChannel) and one for user tokens (ActivateSession). Without the
  second one, X509 certificate authentication fails with
  `BadIdentityTokenRejected (0x80210000)`.

- **docker-compose.yml**: Changed from Docker volume (`certs-volume`) to bind
  mount (`./certs`) to make generated certificates accessible from the host,
  required for integration tests that reference certificate files directly.

### Address Space

- **events-alarms.js**: Fixed alarm creation.
  - `alarmsFolder` registered as event source on the server object with
    `HasEventSource` reference and `setEventNotifier(1)`, required because
    node-opcua requires the `conditionSource` to be a valid event source.
  - Changed `conditionSource` from `alarmSource` (variable) to `alarmsFolder`
    (folder) for all 3 alarms.
  - Fixed the `instantiateOffNormalAlarm` call: removed the first string
    argument `"OffNormalAlarmType"` (the namespace method already includes it)
    and passed `nodeId` instead of objects for `inputNode` and `normalState`.

- **historical.js**: Added `setValueFromSource()` calls in `setInterval`.
  Updating local variables is not enough: node-opcua only records historical
  data when the value is set via `setValueFromSource()`, which triggers the
  internal historical data recording mechanism.

- **access-control.js**: Added `rolePermissions` to OperatorLevel variables
  (`Setpoint`, `MotorSpeed`, `ProcessEnabled`). Without role permissions,
  node-opcua allows writes from any authenticated user, preventing testing of
  role-based access restrictions.

- **data-types.js**: Changed the value of `Int64Value` from `[0, -1000000]` to
  `[0, 1000000]`. node-opcua's `[high, low]` format for Int64 does not support
  negative values in the `low` part, causing a server crash with
  `ERR_OUT_OF_RANGE` during binary serialization.
