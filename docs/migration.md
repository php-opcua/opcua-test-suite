# Migration Guide: opcua-test-suite → uanetstandard-test-suite

This guide covers migrating from `php-opcua/opcua-test-suite` (Node.js / node-opcua) to `php-opcua/uanetstandard-test-suite` (.NET 8.0 / UA-.NETStandard).

## Why migrate?

| | opcua-test-suite | uanetstandard-test-suite |
|---|---|---|
| **OPC UA stack** | node-opcua (third-party) | UA-.NETStandard (OPC Foundation reference impl) |
| **Runtime** | Node.js 22 | .NET 8.0 |
| **Spec conformance** | Good | Reference-level — as close to the spec as possible |
| **Maintainer** | Community | OPC Foundation |
| **Status** | Deprecated | Active |

The OPC Foundation's UA-.NETStandard is the reference implementation used to validate the specification itself. Testing your client against it gives you the highest confidence in real-world interoperability.

## What stays the same

The new suite was designed as a **drop-in replacement**. These are identical:

- **Ports**: 4840-4847 (same 8 servers, same roles)
- **Endpoint paths**: `opc.tcp://localhost:48xx/UA/TestServer`
- **User accounts**: admin/admin123, operator/operator123, viewer/viewer123, test/test
- **Address space structure**: `TestServer/DataTypes/`, `TestServer/Methods/`, etc.
- **Node browse names**: `BooleanValue`, `Int32Value`, `Add`, `Multiply`, `Counter`, etc.
- **Certificate layout**: `certs/ca/`, `certs/server/`, `certs/client/`, `certs/self-signed/`, `certs/expired/`
- **Docker Compose**: `docker compose up -d` starts everything
- **CI override**: `docker-compose.ci.yml` disables restarts and healthchecks

## What changed

### 1. Namespace index

The custom namespace URI changed and is now at a fixed index for all servers:

| | Old (node-opcua) | New (UA-.NETStandard) |
|---|---|---|
| ns=1 | `urn:opcua:test-server:<ServerName>` (varies per server) | `urn:opcua:testserver:nodes` (same for all servers) |

**Impact**: If your tests use hardcoded namespace URIs, update them. If you use namespace index `1:` in browse paths, no change needed.

### 2. Namespace table

The new server has additional namespaces:

| Index | URI | Purpose |
|---|---|---|
| 0 | `http://opcfoundation.org/UA/` | Standard OPC UA |
| 1 | `urn:opcua:testserver:nodes` | All custom nodes |
| 2 | `http://opcfoundation.org/UA/DI/` | Device Integration |
| 3 | `urn:opcua:test-server:custom-types` | Extension object types |
| 4 | `http://opcfoundation.org/UA/Diagnostics` | Server diagnostics |

**Impact**: Extension object TypeIds are now in namespace 3 (was also namespace 3 in the old server). No change needed if you were already using `ns=3;i=3010` and `ns=3;i=3011`.

### 3. Extension objects

Extension objects are now proper binary-encoded `ExtensionObject` values:

| Node | TypeId | Body |
|---|---|---|
| `PointValue` | `ns=3;i=3010` | 24 bytes: 3 doubles (x=1.5, y=2.5, z=3.5) |
| `RangeValue` | `ns=3;i=3011` | 24 bytes: 3 doubles (min=0.0, max=100.0, value=42.5) |

**Impact**: If you read these nodes, the value is now an `ExtensionObject` with binary body, not an object with child variables.

### 4. Historical data recording interval

| | Old | New |
|---|---|---|
| Recording interval | 1000ms | 1000ms |
| Max samples | 10,000 | 10,000 |

No change.

### 5. Matrix dimensions

`Matrix2D_Double` is now 3x3 (9 elements) instead of 3x3 in the old server. No change.

### 6. Default values

| Node | Old value | New value |
|---|---|---|
| `WithRange/Temperature` | ~22.5 (dynamic sine) | 22.5 (initial) |
| `WithRange/Pressure` | ~101.325 (dynamic cosine) | 101.325 (initial) |
| `Structures/TestNested/Label` | `"origin"` | `"origin"` |

No change.

### 7. Access control enforcement

The new server **enforces** role-based write restrictions on `OperatorLevel/` variables:

- **admin** and **operator**: can read and write
- **viewer**: can read only (write returns `BadUserAccessDenied`)

The old server did not enforce this — all authenticated users could write.

**Impact**: If your tests write to `OperatorLevel/` variables as viewer, they will now correctly fail.

### 8. Server certificates

The new server auto-generates its own application certificate on startup via `CheckApplicationInstanceCertificates()`. The pre-generated certificates in `certs/` are used for **client authentication** only.

**Impact**: None for most users. The server cert will be different on each startup but all servers auto-accept client connections or use the trusted store.

### 9. Auto-accept server (port 4845)

Now also allows **anonymous** connections (in addition to username/password and certificate auth).

**Impact**: Tests that connect anonymously to 4845 will now succeed instead of being rejected.

### 10. Operation limits on no-security server (port 4840)

| Limit | Old | New |
|---|---|---|
| MaxNodesPerRead | 0 (unlimited) | 5 |
| MaxNodesPerWrite | 0 (unlimited) | 5 |

**Impact**: If your client discovers server limits and batches accordingly, this tests that behavior. Adjust if you were relying on unlimited reads.

## Step-by-step migration

### Docker Compose (local development)

```bash
# Stop the old suite
cd opcua-test-suite
docker compose down

# Start the new suite
cd ../uanetstandard-test-suite
docker compose up -d
```

No port changes, no endpoint changes.

### GitHub Actions

Replace:

```yaml
- uses: php-opcua/opcua-test-suite@v1.1.5
```

With:

```yaml
- uses: php-opcua/uanetstandard-test-suite@v1.0.0
```

Same inputs, same outputs.

### Certificate paths

If your tests reference the certs directory, update the path:

```diff
- OPCUA_CERTS_DIR=../opcua-test-suite/certs
+ OPCUA_CERTS_DIR=../uanetstandard-test-suite/certs
```

The directory structure inside `certs/` is identical.

### Test code

For most test suites, **no code changes are needed**. The address space, browse names, node paths, methods, and data types are all the same.

Check for these specific cases:

1. **Namespace URI hardcoded**: Replace `urn:opcua:test-server:<ServerName>` with `urn:opcua:testserver:nodes`
2. **Extension object reads**: Now returns `ExtensionObject` with binary body (was object with child variables)
3. **Viewer writing to OperatorLevel**: Now correctly returns `BadUserAccessDenied`
4. **Unlimited reads on port 4840**: Now limited to 5 nodes per read/write

## Need help?

Open an issue on [uanetstandard-test-suite](https://github.com/php-opcua/uanetstandard-test-suite/issues).
