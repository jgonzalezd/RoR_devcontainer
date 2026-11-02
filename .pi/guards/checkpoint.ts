/**
 * Checkpoint: automatic, non-invasive snapshots of every repo in scope before each agent run.
 *
 * Commands:
 *   /checkpoints [repo]             list checkpoints (newest first)
 *   /diff-checkpoint <id> [repo]    `git diff --stat` between a checkpoint and the working tree
 *   /restore <id> [paths...]        restore files from a checkpoint (asks; snapshots current state first)
 *
 * `repo` defaults to the repo containing the current directory. From the workspace root, pass a
 * project path, e.g. `/checkpoints projects_own/secure_notes`.
 */

import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import {
	diffCheckpoint,
	listCheckpoints,
	pruneCheckpoints,
	reposInScope,
	repoRoot,
	restoreCheckpoint,
	snapshotScope,
} from "./lib/snapshot.ts";

const BACKUPS_DIR = resolve(dirname(fileURLToPath(import.meta.url)), "..", "backups");
const RETENTION_DAYS = 14;

export default function checkpoint(pi: ExtensionAPI) {
	/** Finds the repo holding checkpoint `id` (searching everything in scope). */
	function findRepoFor(ctx: ExtensionContext, id: string): string | undefined {
		return reposInScope(ctx.cwd).find((r) => listCheckpoints(r).some((c) => c.id === id));
	}

	pi.on("session_start", async (_event, ctx) => {
		let pruned = 0;
		for (const repo of reposInScope(ctx.cwd)) pruned += pruneCheckpoints(repo, RETENTION_DAYS);
		if (pruned && ctx.hasUI) ctx.ui.notify(`Pruned ${pruned} checkpoints older than ${RETENTION_DAYS} days`, "info");
	});

	pi.on("before_agent_start", async (event, ctx) => {
		const prompt = String(event.prompt ?? "").replace(/\s+/g, " ").slice(0, 120);
		const results = snapshotScope(ctx.cwd, `before prompt: ${prompt}`, BACKUPS_DIR);
		const made = results.filter((r) => r.id).length;
		const failed = results.filter((r) => r.error);
		if (!ctx.hasUI) return;
		if (failed.length) ctx.ui.notify(`Checkpoint FAILED for: ${failed.map((f) => `${f.repo} (${f.error})`).join(", ")}`, "warning");
		ctx.ui.setStatus("checkpoint", made ? `⏺ ckpt ${results.find((r) => r.id)?.id}` : "⏺ ckpt up to date");
	});

	pi.registerCommand("checkpoints", {
		description: "List Pi checkpoints for the current (or given) repo",
		handler: async (args, ctx) => {
			const repo = repoRoot(resolve(ctx.cwd, args.trim() || "."));
			if (!repo) return ctx.ui.notify("Not inside a git repo (pass a project path)", "warning");
			const list = listCheckpoints(repo).slice(0, 30);
			if (!list.length) return ctx.ui.notify(`No checkpoints in ${repo}`, "info");
			await ctx.ui.select(
				`Checkpoints in ${repo} (use /restore <id> or /diff-checkpoint <id>)`,
				list.map((c) => `${c.id}  ${c.subject.replace(/^pi checkpoint \S+: /, "")}`),
			);
		},
	});

	pi.registerCommand("diff-checkpoint", {
		description: "Show what changed since a checkpoint: /diff-checkpoint <id>",
		handler: async (args, ctx) => {
			const id = args.trim().split(/\s+/)[0];
			const repo = id && findRepoFor(ctx, id);
			if (!repo) return ctx.ui.notify(`Checkpoint ${id || "<id>"} not found`, "warning");
			const stat = diffCheckpoint(repo, id) || "(no differences in tracked paths)";
			await ctx.ui.select(`Changes since ${id} in ${repo}`, stat.split("\n"));
		},
	});

	pi.registerCommand("restore", {
		description: "Restore files from a checkpoint: /restore <id> [paths...] (never deletes files)",
		handler: async (args, ctx) => {
			const [id, ...paths] = args.trim().split(/\s+/).filter(Boolean);
			const repo = id && findRepoFor(ctx, id);
			if (!repo) return ctx.ui.notify(`Checkpoint ${id || "<id>"} not found. Try /checkpoints`, "warning");
			const stat = diffCheckpoint(repo, id);
			const ok = await ctx.ui.confirm(
				`Restore ${paths.length ? paths.join(" ") : "ALL files"} from ${id}?`,
				`Repo: ${repo}\n\nCurrent state is checkpointed first, so this is undoable.\nFiles created after the checkpoint are kept.\n\n${stat.split("\n").slice(-25).join("\n")}`,
			);
			if (!ok) return ctx.ui.notify("Restore cancelled", "info");
			try {
				const { before } = restoreCheckpoint(repo, id, paths.length ? paths : ["."]);
				ctx.ui.notify(`Restored from ${id}. Undo with /restore ${before.id ?? "(state unchanged)"}`, "info");
			} catch (e) {
				ctx.ui.notify(`Restore failed: ${(e as Error).message}`, "error");
			}
		},
	});
}
