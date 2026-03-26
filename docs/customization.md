# Customization Guide

How to fork this repository and build your own OPC UA test environment tailored to your specific needs.

## Getting Started

```bash
# Fork on GitHub, then clone your fork
git clone https://github.com/php-opcua/opcua-test-suite.git
cd opcua-test-suite
```

All source code lives in `src/address-space/`. Each file is an independent module that you can modify, replace, or use as a template for new modules.

## Project Structure

```
src/
├── index.js                 Entry point — creates the server, handles shutdown
├── config.js                Environment variable parsing
├── user-manager.js          Username/password authentication
└── address-space/
    ├── index.js             Orchestrator — calls all modules, controls what gets built
    ├── data-types.js        Scalar and array variables
    ├── methods.js           Callable methods
    ├── dynamic.js           Time-varying variables (timers)
    ├── events-alarms.js     Event types and alarm instances
    ├── historical.js        Variables with history recording
    ├── structures.js        Nested object hierarchies
    ├── access-control.js    Access level and role-based variables
    └── views.js             OPC UA views
```

Every module exports a `build*()` function and optionally a `stop*()` function for cleanup. The orchestrator in `address-space/index.js` calls them based on config flags.

## Common Tasks

### Adding a New Variable

Open any existing module or create a new file. The pattern is always the same:

```js
const { DataType, Variant, StatusCodes } = require("node-opcua");

let myValue = 42.0;
namespace.addVariable({
  componentOf: parentFolder,       // the folder this variable belongs to
  browseName: "MyVariable",        // the name clients see when browsing
  dataType: DataType.Double,       // OPC UA data type
  accessLevel: "CurrentRead | CurrentWrite",
  userAccessLevel: "CurrentRead | CurrentWrite",
  value: {
    get: () => new Variant({ dataType: DataType.Double, value: myValue }),
    set: (variant) => {
      myValue = variant.value;
      return StatusCodes.Good;
    },
  },
});
```

For a read-only variable, remove the `set` function and change `accessLevel` to `"CurrentRead"`.

### Adding a New Method

```js
const method = namespace.addMethod(parentFolder, {
  browseName: "MyMethod",
  inputArguments: [
    { name: "input", dataType: DataType.String, description: { text: "An input" } },
  ],
  outputArguments: [
    { name: "result", dataType: DataType.String, description: { text: "The result" } },
  ],
});

method.bindMethod((inputArguments, context, callback) => {
  const input = inputArguments[0].value;
  const result = input.toUpperCase();
  callback(null, {
    statusCode: StatusCodes.Good,
    outputArguments: [{ dataType: DataType.String, value: result }],
  });
});
```

### Adding a Dynamic Variable (Timer-Based)

Variables that change over time use `setInterval`. Keep a reference to the timer so it can be stopped on shutdown.

```js
const timers = [];

function buildMyDynamic(namespace, parentFolder) {
  let value = 0;
  namespace.addVariable({
    componentOf: parentFolder,
    browseName: "MyCounter",
    dataType: DataType.UInt32,
    value: {
      get: () => new Variant({ dataType: DataType.UInt32, value: value }),
    },
  });

  timers.push(setInterval(() => { value++; }, 1000));
}

function stopMyDynamic() {
  for (const t of timers) clearInterval(t);
  timers.length = 0;
}

module.exports = { buildMyDynamic, stopMyDynamic };
```

For variables computed on every read (no timer), use the `get` function directly:

```js
namespace.addVariable({
  componentOf: parentFolder,
  browseName: "CurrentLoad",
  dataType: DataType.Double,
  value: {
    get: () => {
      const load = Math.sin(Date.now() / 5000) * 50 + 50;
      return new Variant({ dataType: DataType.Double, value: load });
    },
  },
});
```

### Adding a Custom Event Type

```js
const myEventType = namespace.addEventType({
  browseName: "MotorFaultEventType",
  subtypeOf: "BaseEventType",
});

namespace.addVariable({
  propertyOf: myEventType,
  browseName: "MotorId",
  dataType: DataType.String,
  modellingRule: "Mandatory",
});

namespace.addVariable({
  propertyOf: myEventType,
  browseName: "FaultCode",
  dataType: DataType.UInt32,
  modellingRule: "Mandatory",
});
```

To emit the event:

```js
emitterObject.raiseEvent(myEventType, {
  message: { dataType: DataType.LocalizedText, value: { text: "Motor overheated" } },
  severity: { dataType: DataType.UInt16, value: 800 },
  sourceNode: { dataType: DataType.NodeId, value: emitterObject.nodeId },
  sourceName: { dataType: DataType.String, value: "Motor-03" },
  motorId: { dataType: DataType.String, value: "MOT-003" },
  faultCode: { dataType: DataType.UInt32, value: 0x4012 },
});
```

### Adding an Alarm

```js
// First, create the source variable the alarm monitors
let processTemp = 25.0;
const tempSource = namespace.addVariable({
  componentOf: alarmsFolder,
  browseName: "ProcessTemperature",
  dataType: DataType.Double,
  accessLevel: "CurrentRead | CurrentWrite",
  userAccessLevel: "CurrentRead | CurrentWrite",
  value: {
    get: () => new Variant({ dataType: DataType.Double, value: processTemp }),
    set: (variant) => { processTemp = variant.value; return StatusCodes.Good; },
  },
});

// Then instantiate the alarm
namespace.instantiateExclusiveLimitAlarm("ExclusiveLimitAlarmType", {
  browseName: "ProcessTempAlarm",
  componentOf: alarmsFolder,
  conditionSource: tempSource,
  inputNode: tempSource,
  highHighLimit: 95,
  highLimit: 80,
  lowLimit: 10,
  lowLowLimit: 0,
});
```

### Adding a Historical Variable

```js
const histVar = namespace.addVariable({
  componentOf: folder,
  browseName: "HistoricalPH",
  dataType: DataType.Double,
  accessLevel: "CurrentRead | HistoryRead",
  userAccessLevel: "CurrentRead | HistoryRead",
  value: {
    get: () => new Variant({ dataType: DataType.Double, value: phValue }),
  },
});

addressSpace.installHistoricalDataNode(histVar, {
  maxOnlineValues: 50000,  // how many samples to keep in memory
});
```

### Adding a New User

Edit `config/users.json`:

```json
{
  "users": [
    { "username": "admin", "password": "admin123", "role": "admin" },
    { "username": "operator", "password": "operator123", "role": "operator" },
    { "username": "viewer", "password": "viewer123", "role": "viewer" },
    { "username": "plc_service", "password": "s3cure!Pass", "role": "operator" }
  ]
}
```

To add a new role, update the `getUserRoles` function in `src/user-manager.js`:

```js
case "engineer":
  return ["AuthenticatedUser", "Operator", "Engineer"];
case "supervisor":
  return ["AuthenticatedUser", "Operator", "ConfigureAdmin"];
```

---

## Creating a New Address Space Module

Step by step guide for adding an entirely new section to the address space.

### 1. Create the module file

Create `src/address-space/my-module.js`:

```js
const { DataType, Variant, StatusCodes } = require("node-opcua");

const timers = [];

function buildMyModule(namespace, rootFolder) {
  const folder = namespace.addFolder(rootFolder, { browseName: "MyModule" });

  // Add your variables, methods, events here
  // ...
}

function stopMyModule() {
  for (const t of timers) clearInterval(t);
  timers.length = 0;
}

module.exports = { buildMyModule, stopMyModule };
```

### 2. Add a feature toggle (optional)

In `src/config.js`, add a new toggle:

```js
enableMyModule: parseBool(process.env.OPCUA_ENABLE_MY_MODULE, true),
```

### 3. Wire it into the orchestrator

In `src/address-space/index.js`:

```js
const { buildMyModule } = require("./my-module");

// Inside constructAddressSpace(), after the other modules:
if (config.enableMyModule) {
  console.log("[AddressSpace] Building my module...");
  buildMyModule(namespace, rootFolder);
}
```

### 4. Register the stop function (if using timers)

In `src/index.js`, import and call the stop function in the shutdown handler:

```js
const { stopMyModule } = require("./address-space/my-module");

async function shutdown() {
  console.log("\n[Server] Shutting down...");
  stopDynamic();
  stopEvents();
  stopHistorical();
  stopMyModule();
  await server.shutdown(1000);
  process.exit(0);
}
```

### 5. Test it

```bash
docker compose build && docker compose up -d
docker compose logs -f opcua-no-security
```

---

## Adding a New Server Instance

To create a 9th server with a different configuration, add a new service in `docker-compose.yml`:

```yaml
opcua-my-scenario:
  build: .
  ports:
    - "4848:4848"
  environment:
    OPCUA_PORT: "4848"
    OPCUA_SERVER_NAME: "MyScenarioServer"
    OPCUA_SECURITY_POLICIES: "Basic256Sha256"
    OPCUA_SECURITY_MODES: "SignAndEncrypt"
    OPCUA_ALLOW_ANONYMOUS: "false"
    OPCUA_AUTH_USERS: "true"
    OPCUA_AUTH_CERTIFICATE: "false"
    OPCUA_CERTIFICATE_FILE: "/app/certs/server/cert.pem"
    OPCUA_PRIVATE_KEY_FILE: "/app/certs/server/key.pem"
    OPCUA_ENABLE_HISTORICAL: "false"
    OPCUA_ENABLE_EVENTS: "false"
  volumes:
    - certs-volume:/app/certs:ro
  depends_on:
    certs-generator:
      condition: service_completed_successfully
  restart: unless-stopped
```

You can disable features you don't need via the `OPCUA_ENABLE_*` variables to create a leaner server.

If your new server needs to be recognized by the certificates, add its hostname to the SAN list in `scripts/generate-certs.sh`:

```
DNS.10 = opcua-my-scenario
```

Then regenerate certificates:

```bash
docker compose down -v
docker compose up -d
```

---

## Simulation Examples

Here are some ideas for custom simulations you could build.

### Industrial PLC

Simulate a PLC with registers, coils, and process data:

```js
function buildPLC(namespace, rootFolder) {
  const plc = namespace.addFolder(rootFolder, { browseName: "PLC_001" });

  const registers = namespace.addFolder(plc, { browseName: "HoldingRegisters" });
  for (let i = 0; i < 100; i++) {
    let val = 0;
    namespace.addVariable({
      componentOf: registers,
      browseName: `HR_${i.toString().padStart(4, "0")}`,
      dataType: DataType.UInt16,
      accessLevel: "CurrentRead | CurrentWrite",
      userAccessLevel: "CurrentRead | CurrentWrite",
      value: {
        get: () => new Variant({ dataType: DataType.UInt16, value: val }),
        set: (v) => { val = v.value; return StatusCodes.Good; },
      },
    });
  }
}
```

### HVAC System

```js
function buildHVAC(namespace, rootFolder) {
  const hvac = namespace.addFolder(rootFolder, { browseName: "HVAC" });

  const zones = ["LobbyZone", "OfficeZone", "ServerRoom", "Warehouse"];
  for (const zone of zones) {
    const zoneObj = namespace.addObject({ organizedBy: hvac, browseName: zone });

    let setpoint = zone === "ServerRoom" ? 18.0 : 22.0;
    let current = setpoint + (Math.random() - 0.5) * 2;
    let fanSpeed = 50;
    let mode = "auto";

    namespace.addVariable({
      componentOf: zoneObj, browseName: "Setpoint", dataType: DataType.Double,
      accessLevel: "CurrentRead | CurrentWrite", userAccessLevel: "CurrentRead | CurrentWrite",
      value: {
        get: () => new Variant({ dataType: DataType.Double, value: setpoint }),
        set: (v) => { setpoint = v.value; return StatusCodes.Good; },
      },
    });

    namespace.addVariable({
      componentOf: zoneObj, browseName: "CurrentTemp", dataType: DataType.Double,
      value: {
        get: () => {
          current += (setpoint - current) * 0.01 + (Math.random() - 0.5) * 0.1;
          return new Variant({ dataType: DataType.Double, value: current });
        },
      },
    });

    // FanSpeed, Mode, etc.
  }
}
```

### Energy Meter

```js
function buildEnergyMeter(namespace, rootFolder) {
  const meter = namespace.addFolder(rootFolder, { browseName: "EnergyMeter" });
  const startTime = Date.now();

  namespace.addVariable({
    componentOf: meter, browseName: "ActivePower_kW", dataType: DataType.Double,
    accessLevel: "CurrentRead | HistoryRead", userAccessLevel: "CurrentRead | HistoryRead",
    value: {
      get: () => {
        const t = (Date.now() - startTime) / 1000;
        const base = 150 + 50 * Math.sin(t / 3600 * Math.PI);
        const noise = (Math.random() - 0.5) * 10;
        return new Variant({ dataType: DataType.Double, value: base + noise });
      },
    },
  });

  // ReactivePower, Voltage_L1/L2/L3, Current_L1/L2/L3, PowerFactor, TotalEnergy_kWh, etc.
}
```

### Multi-Device Network

Simulate multiple devices of the same type:

```js
function buildDeviceNetwork(namespace, rootFolder) {
  const network = namespace.addFolder(rootFolder, { browseName: "Devices" });

  const deviceConfigs = [
    { id: "PUMP-001", type: "CentrifugalPump", flow: 120, pressure: 3.5 },
    { id: "PUMP-002", type: "CentrifugalPump", flow: 95, pressure: 4.1 },
    { id: "VALVE-001", type: "ControlValve", position: 75 },
    { id: "VALVE-002", type: "ControlValve", position: 30 },
    { id: "SENSOR-T01", type: "TempSensor", value: 85.2 },
  ];

  for (const dev of deviceConfigs) {
    const obj = namespace.addObject({ organizedBy: network, browseName: dev.id });
    namespace.addVariable({
      componentOf: obj, browseName: "DeviceType", dataType: DataType.String,
      accessLevel: "CurrentRead", userAccessLevel: "CurrentRead",
      value: { get: () => new Variant({ dataType: DataType.String, value: dev.type }) },
    });
    // Add device-specific variables based on dev.type...
  }
}
```

---

## Tips

- **Keep modules independent.** Each module should only use the `namespace` and `rootFolder` parameters. Don't reference other modules' variables directly.
- **Always register timers.** Every `setInterval` must be tracked and cleared in the `stop*()` function, otherwise the server won't shut down cleanly.
- **Use `console.log` with tags.** Follow the existing pattern: `console.log("[MyModule] Something happened")` for easy log filtering.
- **Test locally first.** Run `docker compose build && docker compose up opcua-no-security` to test with a single server before starting all 8.
- **Check node-opcua docs.** The [node-opcua API documentation](https://node-opcua.github.io/) covers all available node types, data types, and advanced features like custom data types, state machines, and file transfer.
