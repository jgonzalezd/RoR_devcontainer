#!/usr/bin/env node
// Registers the safety guards in the USER Pi settings (~/.pi/agent/settings.json) so they load
// in every Pi session, even when project trust is declined. Idempotent; preserves other settings.
// Usage: node .pi/guards/install.mjs [--check]
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const guards = ["safety-guard.ts", "checkpoint.ts"].map((f) => join(here, f));
const agentDir = process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent");
const file = join(agentDir, "settings.json");

const settings = existsSync(file) ? JSON.parse(readFileSync(file, "utf8")) : {};
const extensions = Array.isArray(settings.extensions) ? settings.extensions : [];
const missing = guards.filter((g) => !extensions.includes(g));

if (process.argv.includes("--check")) {
	console.log(missing.length ? `✗ Pi guards NOT registered in ${file}` : `✓ Pi guards registered in ${file}`);
	process.exit(missing.length ? 1 : 0);
}
if (missing.length === 0) {
	console.log(`✓ Pi guards already registered in ${file}`);
} else {
	settings.extensions = [...extensions, ...missing];
	settings.defaultProjectTrust ??= "ask";
	mkdirSync(agentDir, { recursive: true });
	if (existsSync(file)) writeFileSync(`${file}.bak`, readFileSync(file));
	writeFileSync(file, `${JSON.stringify(settings, null, 2)}\n`);
	console.log(`✓ Registered Pi guards in ${file}:\n  ${missing.join("\n  ")}`);
}
