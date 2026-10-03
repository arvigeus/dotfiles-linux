// Offline runtime contract tests; never execute a real upgrade or spawn the apply callback.
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const agentDir = process.env.PI_TEST_AGENT_DIR;
if (!agentDir) throw new Error("PI_TEST_AGENT_DIR is required");
const require = createRequire(join(agentDir, "package.json"));
const { createJiti } = require("jiti");
const jiti = createJiti(import.meta.url, { alias: {
  "@earendil-works/pi-ai": join(agentDir, "node_modules/@earendil-works/pi-ai/dist/index.js"),
  "@earendil-works/pi-tui": join(agentDir, "node_modules/@earendil-works/pi-tui/dist/index.js"),
  "@earendil-works/pi-coding-agent": join(agentDir, "dist/index.js"),
  typebox: require.resolve("typebox"),
} });
const { default: register } = await jiti.import(pathToFileURL(join(dirname(fileURLToPath(import.meta.url)), "index.ts")).href);

function harness(report, mode = "rpc") {
  const tools = new Map(), commands = new Map(), events = new Map();
  const turns = [], entries = [], calls = [], confirmations = [], customCalls = [];
  const h = { tools, commands, events, turns, entries, calls, confirmations, customCalls,
    report, outcome: { outcome: "completed", updated: true }, customResults: [], confirm: false,
    command: (action = "") => commands.get("system:update").handler(action, h.ctx) };
  const pi = {
    on: (name, handler) => events.set(name, handler),
    registerTool: (tool) => tools.set(tool.name, tool),
    registerCommand: (name, command) => commands.set(name, command),
    registerEntryRenderer: () => {}, appendEntry: (_name, text) => entries.push(text),
    sendUserMessage: (text) => turns.push(text),
    exec: async (program, args) => {
      const payload = JSON.parse(args[2]);
      calls.push([program, payload]);
      let response;
      if (payload.action === "result") response = h.outcome;
      else if (payload.action === "cleanup") response = { removed: [], manual: ["/etc/sample.pacnew"] };
      else {
        const items = h.report.items ?? [], offset = payload.offset ?? 0, limit = payload.limit ?? 20;
        response = { ...h.report, total: items.length,
          pending_total: h.report.pending.length, needs_ai_total: h.report.needs_ai.length,
          items: items.slice(offset, offset + limit) };
      }
      return { code: 0, killed: false, stderr: "", stdout: JSON.stringify(response) };
    },
  };
  h.ctx = { cwd: "/test", mode, hasUI: mode === "tui" || mode === "rpc", waitForIdle: async () => {},
    ui: { notify: () => {}, confirm: async (...args) => { confirmations.push(args); return h.confirm; },
      custom: async (_factory) => { customCalls.push("custom"); return h.customResults.shift() ?? 0; } } };
  register(pi);
  return h;
}

const ready = { id: "plan", distro: "arch", package_count: 1, pending: [], needs_ai: [],
  items: [{ key: "sample", review: { decision: "ready", summary: "1 to 2 reviewed", follow_up: "Reboot after inspecting UKI hooks" } }] };
let h = harness(ready);
assert.equal(h.tools.size, 1);
assert.ok(h.commands.has("system:update"));
assert.equal(h.commands.get("system:update"), h.commands.get("system-update"));
assert.ok(!JSON.stringify(h.tools.get("system_update").parameters).includes('"apply"'));
await h.command("check");
assert.equal(h.turns.length, 0, "cached ready evidence must not invoke a model");
assert.equal(h.calls[0][1].action, "check");
assert.match(h.entries.join("\n"), /Reboot after inspecting UKI/);

h = harness({ ...ready, pending: ["sample"], needs_ai: ["sample"], items: [{ key: "sample", review: null }] });
await h.command("check");
assert.equal(h.turns.length, 1);
assert.match(h.turns[0], /untrusted data/);
assert.match(h.turns[0], /version range/);
assert.match(h.turns[0], /inventory/);
assert.match(h.turns[0], /follow_up/);

h = harness({ ...ready, pending: ["sample"], items: [{ key: "sample", review: { decision: "unknown", summary: "Coverage uncertain" } }] });
await h.command("check");
assert.equal(h.turns.length, 0);
assert.match(h.entries.join("\n"), /Coverage uncertain/);
await h.command("review");
assert.equal(h.turns.length, 1, "explicit reconsideration may use AI");

h = harness({ ...ready, pending: ["sample"], items: [{ key: "sample", review: { decision: "unavailable", summary: "Searched: no changelog" } }] });
await h.command();
assert.equal(h.turns.length, 0, "known absence does not need AI");
assert.match(h.entries.join("\n"), /not a safety approval/);

const many = Array.from({ length: 121 }, (_, i) => ({ key: `p${i}`, review: { decision: "attention", summary: `Action ${i}` } }));
h = harness({ ...ready, package_count: many.length, items: many, pending: many.map(p => p.key) });
await h.command("status");
assert.match(h.entries.join("\n"), /Action 120/);
assert.deepEqual(h.calls.filter(([, p]) => p.action === "status").map(([, p]) => p.offset ?? 0), [0, 0, 50, 100]);

for (const mode of ["rpc", "print", "json"]) {
  h = harness(ready, mode);
  await h.command("apply");
  assert.match(h.entries.join("\n"), /requires interactive Pi TUI/);
  assert.equal(h.customCalls.length, 0);
}

h = harness(ready, "tui");
await h.command("apply");
assert.equal(h.customCalls.length, 0, "cancel must never enter apply");
assert.match(h.entries.join("\n"), /cancelled/);
assert.doesNotMatch(h.entries.join("\n"), /Updates completed/);

for (const outcome of ["completed", "cancelled", "no-op", "failed"]) {
  h = harness(ready, "tui"); h.confirm = true; h.outcome = { outcome, error: "mock failure" };
  await h.command("apply");
  assert.equal(h.customCalls.length, 1);
  assert.equal(h.calls.at(-1)[1].action, "result");
  assert.ok(h.calls.at(-1)[1].key, "structured result must be bound to a unique attempt");
  assert.equal(h.entries.join("\n").includes("Updates completed"), outcome === "completed");
}

// Default command is a one-entrypoint workflow. Mock progress UI and apply UI
// without invoking either factory (so no inherited-terminal process can run).
h = harness(ready, "tui"); h.confirm = true; h.customResults = [ready, 0];
await h.command();
assert.equal(h.turns.length, 0);
assert.equal(h.confirmations.length, 1);
assert.equal(h.customCalls.length, 2);

const unreviewed = { ...ready, pending: ["sample"], needs_ai: ["sample"], items: [{ key: "sample", review: null }] };
h = harness(unreviewed, "tui"); h.customResults = [unreviewed];
await h.command();
assert.equal(h.turns.length, 1);
await h.events.get("agent_settled")({}, h.ctx);
assert.equal(h.confirmations.length, 0, "no apply while user guidance/new reviews are outstanding");
h.report = ready;
await h.events.get("agent_settled")({}, h.ctx);
assert.equal(h.confirmations.length, 1, "offer apply when user-initiated review is complete");
await h.events.get("agent_settled")({}, h.ctx);
assert.equal(h.confirmations.length, 1, "continuation fires once only");

h = harness(unreviewed, "tui"); h.customResults = [unreviewed];
await h.command();
await h.events.get("session_shutdown")({}, h.ctx);
h.report = ready;
await h.events.get("agent_settled")({}, h.ctx);
assert.equal(h.confirmations.length, 0, "session replacement cancels pending update flow");

h = harness({ ...ready, package_count: 0, items: [] }, "tui");
h.customResults = [{ ...ready, package_count: 0, items: [] }];
await h.command();
assert.equal(h.turns.length, 0);
assert.equal(h.confirmations.length, 0);
assert.match(h.entries.join("\n"), /Nothing to apply/);
await h.command("cleanup");
assert.match(h.entries.join("\n"), /sample.pacnew/);
assert.equal(h.turns.length, 0);

console.log("Pi system:update extension: ok");
