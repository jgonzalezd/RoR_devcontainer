/**
 * Non-invasive checkpoints.
 *
 * Git repos: tracked + untracked (non-ignored) files are written into a commit via a temporary
 * index, then pinned under refs/pi/checkpoints/<id>. The working tree, the real index, HEAD,
 * branches and stashes are never touched, and the ref protects the objects from `git gc`.
 *
 * Non-git directories: a tarball in the backups dir (excluding bulky regenerable dirs).
 */

import { execFileSync } from "node:child_process";
import { copyFileSync, existsSync, mkdirSync, readdirSync, rmSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, relative, resolve } from "node:path";

export const REF_PREFIX = "refs/pi/checkpoints/";
const LAST_REF = "refs/pi/last";
const IDENTITY = {
	GIT_AUTHOR_NAME: "pi-checkpoint",
	GIT_AUTHOR_EMAIL: "pi-checkpoint@localhost",
	GIT_COMMITTER_NAME: "pi-checkpoint",
	GIT_COMMITTER_EMAIL: "pi-checkpoint@localhost",
};

function git(repo: string, args: string[], env?: Record<string, string>): string {
	return execFileSync("git", ["-C", repo, ...args], {
		encoding: "utf8",
		env: { ...process.env, ...env },
		stdio: ["ignore", "pipe", "pipe"],
		maxBuffer: 64 * 1024 * 1024,
	}).trim();
}

function tryGit(repo: string, args: string[]): string | null {
	try {
		return git(repo, args);
	} catch {
		return null;
	}
}

export function repoRoot(dir: string): string | null {
	return tryGit(dir, ["rev-parse", "--show-toplevel"]);
}

/** Timestamp id, sortable and unique enough: 20260924-225601-123 */
export function newId(now = new Date()): string {
	const p = (n: number, w = 2) => String(n).padStart(w, "0");
	return `${now.getFullYear()}${p(now.getMonth() + 1)}${p(now.getDate())}-${p(now.getHours())}${p(now.getMinutes())}${p(now.getSeconds())}-${p(now.getMilliseconds(), 3)}`;
}

export interface SnapshotResult {
	repo: string;
	id?: string;
	sha?: string;
	skipped?: "unchanged";
	error?: string;
}

export function snapshotRepo(repo: string, label: string): SnapshotResult {
	const tmpIndex = join(tmpdir(), `pi-ckpt-index-${process.pid}-${Date.now()}-${Math.random().toString(36).slice(2)}`);
	try {
		const gitDir = git(repo, ["rev-parse", "--absolute-git-dir"]);
		const realIndex = join(gitDir, "index");
		if (existsSync(realIndex)) copyFileSync(realIndex, tmpIndex); // speeds up `add -A` (stat cache)
		const env = { GIT_INDEX_FILE: tmpIndex, ...IDENTITY };
		git(repo, ["add", "-A", "--", "."], env);
		const tree = git(repo, ["write-tree"], env);

		const lastTree = tryGit(repo, ["rev-parse", "-q", "--verify", `${LAST_REF}^{tree}`]);
		if (lastTree === tree) return { repo, skipped: "unchanged" };

		const head = tryGit(repo, ["rev-parse", "-q", "--verify", "HEAD"]);
		const id = newId();
		const msg = `pi checkpoint ${id}: ${label}`.slice(0, 300);
		const sha = git(repo, ["commit-tree", tree, ...(head ? ["-p", head] : []), "-m", msg], env);
		git(repo, ["update-ref", "-m", "pi checkpoint", REF_PREFIX + id, sha]);
		git(repo, ["update-ref", LAST_REF, sha]);
		return { repo, id, sha };
	} catch (e) {
		return { repo, error: (e as Error).message.split("\n")[0] };
	} finally {
		rmSync(tmpIndex, { force: true });
	}
}

/**
 * Repos affected by work started in `cwd`: the repo containing cwd, plus nested repos up to
 * two levels down (the workspace root gitignores projects_own/*, each of which is its own repo).
 */
export function reposInScope(cwd: string, maxDepth = 2): string[] {
	const found = new Set<string>();
	const own = repoRoot(cwd);
	if (own) found.add(own);
	const skip = new Set(["node_modules", "vendor", "tmp", "log", "storage", "coverage", "public"]);
	const walk = (dir: string, depth: number) => {
		if (depth > maxDepth || found.size > 40) return;
		let entries: string[];
		try {
			entries = readdirSync(dir);
		} catch {
			return;
		}
		if (depth > 0 && entries.includes(".git")) found.add(resolve(dir));
		for (const name of entries) {
			if (name.startsWith(".") || skip.has(name)) continue;
			const child = join(dir, name);
			try {
				if (statSync(child).isDirectory()) walk(child, depth + 1);
			} catch {}
		}
	};
	walk(cwd, 0);
	return [...found];
}

/** Tarball fallback for directories that are not inside any git repo. */
export function tarballBackup(dir: string, backupsDir: string, label: string): SnapshotResult {
	try {
		const id = newId();
		mkdirSync(backupsDir, { recursive: true });
		const out = join(backupsDir, `${id}-${dir.replace(/[^\w]+/g, "_").slice(-60)}.tar.gz`);
		execFileSync(
			"tar",
			["-czf", out, "--exclude=node_modules", "--exclude=tmp", "--exclude=log", "--exclude=vendor/bundle", "--exclude=.DB_data", "-C", dirname(dir), relative(dirname(dir), dir) || "."],
			{ stdio: ["ignore", "ignore", "pipe"], timeout: 120_000 },
		);
		return { repo: dir, id: `${id} (${label})`, sha: out };
	} catch (e) {
		return { repo: dir, error: (e as Error).message.split("\n")[0] };
	}
}

/** Snapshot everything in scope; tarball fallback when cwd has no repo at all. */
export function snapshotScope(cwd: string, label: string, backupsDir: string): SnapshotResult[] {
	const repos = reposInScope(cwd);
	if (repos.length === 0) return [tarballBackup(cwd, backupsDir, label)];
	return repos.map((r) => snapshotRepo(r, label));
}

export interface Checkpoint {
	id: string;
	sha: string;
	date: string;
	subject: string;
}

export function listCheckpoints(repo: string): Checkpoint[] {
	const out = tryGit(repo, ["for-each-ref", "--sort=-refname", "--format=%(refname)%09%(objectname:short)%09%(creatordate:iso)%09%(contents:subject)", REF_PREFIX]);
	if (!out) return [];
	return out.split("\n").map((line) => {
		const [ref, sha, date, subject] = line.split("\t");
		return { id: ref.slice(REF_PREFIX.length), sha, date, subject };
	});
}

export function resolveCheckpoint(repo: string, id: string): string | null {
	return tryGit(repo, ["rev-parse", "-q", "--verify", `${REF_PREFIX}${id}^{commit}`]);
}

/**
 * Restores files from a checkpoint into the working tree only (index untouched).
 * Files created after the checkpoint are left in place: restore never deletes.
 * Always takes a "pre-restore" checkpoint first, so a restore is itself undoable.
 */
export function restoreCheckpoint(repo: string, id: string, paths: string[] = ["."]): { before: SnapshotResult } {
	const sha = resolveCheckpoint(repo, id);
	if (!sha) throw new Error(`No checkpoint ${id} in ${repo}`);
	const before = snapshotRepo(repo, `pre-restore of ${id}`);
	if (before.skipped) before.id = listCheckpoints(repo)[0]?.id; // current state == newest checkpoint
	if (before.error) throw new Error(`Refusing to restore: could not checkpoint current state first (${before.error})`);
	git(repo, ["restore", `--source=${sha}`, "--worktree", "--", ...paths]);
	return { before };
}

export function diffCheckpoint(repo: string, id: string): string {
	const sha = resolveCheckpoint(repo, id);
	if (!sha) throw new Error(`No checkpoint ${id} in ${repo}`);
	return git(repo, ["diff", "--stat", sha]);
}

/** Deletes checkpoint refs older than `days`. Returns how many were pruned. */
export function pruneCheckpoints(repo: string, days = 14, now = new Date()): number {
	const cutoff = now.getTime() - days * 86_400_000;
	let pruned = 0;
	for (const c of listCheckpoints(repo)) {
		const m = c.id.match(/^(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})/);
		if (!m) continue;
		const t = new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]).getTime();
		if (t < cutoff && tryGit(repo, ["update-ref", "-d", REF_PREFIX + c.id]) !== null) pruned++;
	}
	return pruned;
}

/** Copies a file aside before it gets overwritten by the `write` tool. */
export function backupFile(absPath: string, backupsDir: string): string | null {
	if (!existsSync(absPath) || !statSync(absPath).isFile()) return null;
	const dest = join(backupsDir, "files", newId(), absPath.replace(/^\/+/, ""));
	mkdirSync(dirname(dest), { recursive: true });
	copyFileSync(absPath, dest);
	return dest;
}
