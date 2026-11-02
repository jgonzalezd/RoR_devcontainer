/**
 * Safety Guard: human-in-the-loop for anything that can destroy work.
 *
 * Loaded from USER settings (~/.pi/agent/settings.json "extensions"), not from .pi/extensions,
 * so it stays active even when project trust is declined and is never loaded twice.
 *
 * - bash:        risky commands (see lib/classify.ts) → checkpoint affected repos → ask.
 * - read:        secret files (.env, *.key, ...) → ask (content would go to the model provider).
 * - write/edit:  secrets, .git, DB data, devcontainer, generated schema, committed migrations → ask.
 *                `write` over an existing file → backup copy first.
 * - No UI (print/json mode) → risky calls are blocked, never silently allowed.
 * - Handler errors make Pi block the tool call (fail closed).
 */

import { execFileSync } from "node:child_process";
import { existsSync, statSync } from "node:fs";
import { dirname, isAbsolute, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { classifyCommand, classifyWritePath, isSecretPath } from "./lib/classify.ts";
import { backupFile, repoRoot, type SnapshotResult, snapshotScope } from "./lib/snapshot.ts";

const BACKUPS_DIR = resolve(dirname(fileURLToPath(import.meta.url)), "..", "backups");
const ALLOW_ONCE = "Allow once";
const ALLOW_SESSION = "Allow this exact action for the rest of this session";
const BLOCK = "Block";

function describeSnapshots(results: SnapshotResult[]): string {
	return results
		.map((r) => {
			const name = r.repo.split("/").slice(-2).join("/");
			if (r.error) return `  ✗ ${name}: checkpoint FAILED (${r.error})`;
			if (r.skipped) return `  ✓ ${name}: unchanged since last checkpoint`;
			return `  ✓ ${name}: checkpoint ${r.id}`;
		})
		.join("\n");
}

/** Is this file committed in git with no local modifications? (i.e. an already-shared migration) */
function isCommittedAndClean(absPath: string): boolean {
	const root = repoRoot(dirname(absPath));
	if (!root) return false;
	try {
		execFileSync("git", ["-C", root, "ls-files", "--error-unmatch", "--", absPath], { stdio: "ignore" });
		execFileSync("git", ["-C", root, "diff", "--quiet", "HEAD", "--", absPath], { stdio: "ignore" });
		return true;
	} catch {
		return false;
	}
}

export default function safetyGuard(pi: ExtensionAPI) {
	const sessionAllowed = new Set<string>();

	async function ask(ctx: ExtensionContext, key: string, title: string, detail: string) {
		if (sessionAllowed.has(key)) return undefined;
		if (!ctx.hasUI) {
			return {
				block: true,
				reason: `Blocked by safety guard (no human available to approve): ${title}. Do not try to work around this; tell the user what you wanted to do and why.`,
			};
		}
		const choice = await ctx.ui.select(`🛡  ${title}\n\n${detail}\n`, [BLOCK, ALLOW_ONCE, ALLOW_SESSION]);
		if (choice === ALLOW_ONCE) return undefined;
		if (choice === ALLOW_SESSION) {
			sessionAllowed.add(key);
			return undefined;
		}
		return {
			block: true,
			reason: `The user declined: ${title}. Do NOT retry it or achieve the same effect another way (different command, script, or tool). Explain what you intended and ask the user how to proceed.`,
		};
	}

	pi.on("tool_call", async (event, ctx) => {
		const abs = (p: string) => (isAbsolute(p) ? p : resolve(ctx.cwd, p.replace(/^@/, "")));

		if (event.toolName === "bash") {
			const command = String(event.input.command ?? "");
			const verdict = classifyCommand(command, {
				fileExists: (p) => {
					try {
						return statSync(abs(p)).isFile();
					} catch {
						return false;
					}
				},
			});
			if (!verdict.risky) return undefined;
			if (sessionAllowed.has(`bash:${command}`)) return undefined;
			const snaps = snapshotScope(ctx.cwd, `before: ${command}`, BACKUPS_DIR);
			return ask(
				ctx,
				`bash:${command}`,
				"Risky shell command",
				`  $ ${command.length > 600 ? `${command.slice(0, 600)}…` : command}\n\nWhy flagged:\n${verdict.reasons.map((r) => `  • ${r}`).join("\n")}\n\nSafety net (restore with /restore <id>):\n${describeSnapshots(snaps)}`,
			);
		}

		if (event.toolName === "read") {
			const path = String(event.input.path ?? "");
			if (isSecretPath(path))
				return ask(ctx, `read:${abs(path)}`, `Read secret file ${path}`, "Its contents would be sent to the model provider (OpenRouter).");
			return undefined;
		}

		if (event.toolName === "write" || event.toolName === "edit") {
			const path = String(event.input.path ?? "");
			const target = abs(path);
			const shown = relative(ctx.cwd, target) || path;
			const verdict = classifyWritePath(target);
			let result: { block: boolean; reason: string } | undefined;

			if (verdict?.kind === "migration") {
				// New / still-uncommitted migrations are fine to iterate on; committed ones may already be run elsewhere.
				if (isCommittedAndClean(target))
					result = await ask(ctx, `${event.toolName}:${target}`, `${event.toolName} committed migration ${shown}`, "Committed migrations may already have run. Prefer a NEW migration instead of editing this one.");
			} else if (verdict) {
				result = await ask(ctx, `${event.toolName}:${target}`, `${event.toolName} ${verdict.reason}: ${shown}`, "This path is protected by the safety guard.");
			}
			if (result) return result;

			if (event.toolName === "write" && existsSync(target)) {
				const saved = backupFile(target, BACKUPS_DIR);
				if (saved && ctx.hasUI) ctx.ui.notify(`Backed up ${shown} → ${relative(ctx.cwd, saved)}`, "info");
			}
			return undefined;
		}

		return undefined;
	});

	pi.on("session_start", async (_event, ctx) => {
		if (ctx.hasUI) ctx.ui.setStatus("safety-guard", "🛡 guard on");
	});
}
