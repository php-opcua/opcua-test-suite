<h1 align="center"><strong>OPC UA Test Suite</strong></h1>

<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/logo-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="assets/logo-light.svg">
    <img alt="OPC UA Test Suite" src="./assets/logo-light.svg" width="435">
  </picture>
</div>

---

A comprehensive, ready-to-use OPC UA suite built specifically for **integration testing of OPC UA client libraries**. It provides 8 pre-configured server instances covering every major security policy, authentication method, and communication mode defined by the OPC UA specification.

Whether you're building an OPC UA client in Rust, C#, Python, Go, Java, or any other language, this suite gives you a realistic test environment with ~270 nodes, 12 callable methods, dynamic variables, events, alarms, historical data, structured objects, and custom extension objects — all running with a single `docker compose up`.

## What's Inside

| Port | Server | What it tests |
|---|---|---|
| 4840 | No Security | Basic connectivity, anonymous access |
| 4841 | Username/Password | Encrypted channel + credential authentication |
| 4842 | Certificate Auth | X.509 certificate-based authentication |
| 4843 | All Security | Every policy, every mode, every auth method |
| 4844 | Discovery | OPC UA Discovery Server (FindServers) |
| 4845 | Auto-Accept | Encrypted with auto-trust for any client cert |
| 4846 | Sign Only | Message signing without encryption |
| 4847 | Legacy Security | Deprecated policies (Basic128Rsa15, Basic256) |

All servers share the same rich address space:

- **21 scalar data types** (Boolean through LocalizedText) in read/write and read-only variants
- **20 array types** + 14 empty arrays + 6 read-only arrays
- **3 multi-dimensional matrices** (2D and 3D)
- **12 methods** — arithmetic, string ops, arrays, async, error handling, event generation
- **13 dynamic variables** — counters, sine/sawtooth/triangle waves, random values, status cycling
- **3 custom event types** with periodic emission
- **3 alarm types** — ExclusiveLimit, NonExclusiveLimit, OffNormal
- **4 historical variables** with HistoryRead support
- **Structured objects** with nesting up to 10 levels deep
- **50 access control variables** covering every combination of type and access level
- **4 OPC UA Views** for filtered browsing

## Fork It

This suite covers the most common OPC UA testing scenarios out of the box, but every industrial environment is different. Need to simulate a SCADA system with hundreds of registers? An HVAC controller with multi-zone temperature loops? A fleet of PLCs on a factory floor? A smart energy meter with real-time power readings?

**Fork this repository** and build exactly the OPC UA environment you need.

The codebase was designed from the ground up to be extended. Each feature — methods, events, alarms, historical data, structures — lives in its own independent module under `src/address-space/`. You can modify any of them, remove the ones you don't need, or add entirely new modules without touching the rest. Adding a new variable is 10 lines of code. Adding a whole new address space section is a single file and two lines of wiring.

The **[Customization Guide](docs/customization.md)** walks you through everything step by step:

- Adding variables, methods, events, alarms, and historical nodes
- Creating new address space modules from scratch
- Adding new server instances with custom configurations
- Complete simulation examples (PLC, HVAC, energy meter, device network)

If you build something useful on top of this, consider opening a PR or sharing your fork — the OPC UA community benefits from better testing tools.

## Already Enough for You?

If the default suite already covers what you need, you're good to go. Jump straight to the **[Quick Start](#quick-start)** below, check the full **[Documentation](docs/README.md)** for every node, method, and alarm available, or head to the **[CI Integration Guide](docs/ci-integration.md)** to plug it into your pipeline in one step.

## Quick Start

```bash
docker compose up -d
```

That's it. Eight servers are now running on ports 4840–4847 with auto-generated certificates.

```bash
# Connect to the simplest server
# Endpoint: opc.tcp://localhost:4840/UA/TestServer

# Stop everything
docker compose down
```

## Use in CI/CD (GitHub Actions)

This repository is also a **reusable GitHub Action**. Add a single step to your workflow and all test servers are ready:

```yaml
steps:
  - uses: actions/checkout@v4

  - uses: php-opcua/opcua-test-suite@v1.1.4

  - run: cargo test  # or npm test, pytest, dotnet test, etc.
```

You can select which servers to start, set timeouts, and access the generated certificates:

```yaml
- id: opcua
  uses: php-opcua/opcua-test-suite@v1.1.4
  with:
    servers: 'no-security,userpass,certificate'
    wait-timeout: '90'

- run: cargo test
  env:
    OPCUA_CERTS_DIR: ${{ steps.opcua.outputs.certs-dir }}
```

For real-world usage examples, see the CI workflows in [opcua-client](https://github.com/php-opcua/opcua-client), [opcua-session-manager](https://github.com/php-opcua/opcua-session-manager), and [laravel-opcua](https://github.com/php-opcua/laravel-opcua).

For the full integration guide with all options, certificate usage, version pinning, and examples for other CI systems (GitLab, Jenkins), see **[docs/ci-integration.md](docs/ci-integration.md)**.

## Documentation

Detailed documentation is available in the [`docs/`](docs/) folder:

| Document | Description |
|---|---|
| [Setup & Installation](docs/setup.md) | Docker setup, environment variables, certificate regeneration |
| [Server Instances](docs/servers.md) | The 8 servers explained: when and why to use each one |
| [Authentication & Roles](docs/authentication.md) | Users, passwords, roles, and permissions matrix |
| [Security & Certificates](docs/security.md) | Policies, modes, certificate files, trust chain |
| [Address Space Overview](docs/address-space.md) | Top-level structure and navigation |
| [Data Types](docs/data-types.md) | All scalar types, arrays, matrices, and analog items |
| [Methods](docs/methods.md) | 12 methods with full signatures and testing checklist |
| [Dynamic Variables](docs/dynamic-variables.md) | Time-varying variables and subscription testing |
| [Events & Alarms](docs/events-and-alarms.md) | Custom event types, periodic events, alarm conditions |
| [Historical Data](docs/historical-data.md) | HistoryRead operations and historical variables |
| [Structures](docs/structures.md) | Nested objects, collections, deep nesting |
| [Extension Objects](docs/extension-objects.md) | Custom structured types (TestPointXYZ, TestRangeStruct) |
| [Access Control](docs/access-control.md) | Access levels, role-based folders, type/access combinations |
| [Views](docs/views.md) | 4 OPC UA views for filtered browsing |
| [Testing Guide](docs/testing-guide.md) | Step-by-step test scenarios for every feature |
| [CI Integration](docs/ci-integration.md) | GitHub Actions, GitLab CI, Docker Compose usage |
| [Customization](docs/customization.md) | How to fork and build your own OPC UA simulations |
| [AI Reference](docs/AI_REFERENCE.md) | Single-file machine-readable reference for AI tools |

## Test Credentials

| Username | Password | Role |
|---|---|---|
| `admin` | `admin123` | Full access |
| `operator` | `operator123` | Read/write on operational variables |
| `viewer` | `viewer123` | Read-only |
| `test` | `test` | Full access (convenience) |

## Support

For bug reports, feature requests, or questions, please open an issue on [GitHub Issues](https://github.com/php-opcua/opcua-test-suite/issues).

## AI Disclosure

This project was built in part with the assistance of **Claude** (Anthropic). The AI contributed to code generation, documentation writing, and architecture decisions. All outputs were reviewed and validated by the author. The [AI Reference](docs/AI_REFERENCE.md) document was specifically designed to be consumed by AI coding assistants working with this project.

## License

This project is licensed under the [MIT License](LICENSE).
