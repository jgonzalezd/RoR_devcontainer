/**
 * Pure risk classification for tool calls. No Pi imports, so it can be unit-tested
 * with `node --test --experimental-strip-types`.
 *
 * Philosophy: false positives cost one keypress, false negatives can cost days of work.
 * When in doubt, flag it and let the human decide.
 */

export interface Classification {
	risky: boolean;
	reasons: string[];
}

export interface ClassifyOptions {
	/** Returns true if the (cwd-relative or absolute) path exists as a regular file. */
	fileExists?: (path: string) => boolean;
}

type Rule = [RegExp, string];

// Matches the start of a shell "word" position: start, whitespace, or a command separator.
const W = String.raw`(?:^|[\s;&|()\x60$'"])`;
const GIT = String.raw`\bgit\b(?:\s+-[Cc]\s+\S+)*(?:\s+--?[\w-]+(?:=\S+)?)*\s+`;

const COMMAND_RULES: Rule[] = [
	// --- filesystem ---
	[new RegExp(`${W}(?:rm|rmdir|unlink|shred|srm)\\s`), "deletes files/directories"],
	[new RegExp(`${W}(?:rm|rmdir|unlink)$`), "deletes files/directories"],
	[/\bfind\b[^;&|]*\s-(?:delete\b|exec(?:dir)?\s+(?:\S*\/)?(?:rm|shred|unlink)\b)/, "find with delete"],
	[/\bxargs\b[^;&|]*\b(?:rm|shred|unlink)\b/, "xargs delete"],
	[new RegExp(`${W}truncate\\s`), "truncates files"],
	[new RegExp(`${W}mv\\s`), "moves/renames files (source disappears, target may be overwritten)"],
	[/\bdd\b[^;&|]*\bof=/, "dd writes raw data to a file/device"],
	[/\b(?:chmod|chown|chgrp)\s+(?:-\w*R\w*|--recursive)\b/, "recursive permission/ownership change"],
	[/\bsudo\b/, "runs as root"],
	[/\b(?:sed|perl)\b[^;&|]*\s-\w*i\w*\b[^;&|]*\s(?:-r|--recursive|\*\*|\$\(find)/, "bulk in-place rewrite across many files"],

	// --- git: anything that discards work, rewrites history, or leaves the machine ---
	[new RegExp(`${GIT}reset\\b[^;&|]*--(?:hard|merge|keep)\\b`), "git reset --hard discards uncommitted work"],
	[new RegExp(`${GIT}clean\\b`), "git clean deletes untracked files"],
	[new RegExp(`${GIT}checkout\\b[^;&|]*(?:\\s--(?:\\s|$)|\\s\\.(?:\\s|$)|\\s-f\\b|--force\\b)`), "git checkout discards working-tree changes"],
	[new RegExp(`${GIT}restore\\b`), "git restore discards working-tree changes"],
	[new RegExp(`${GIT}switch\\b[^;&|]*(?:--discard-changes|\\s-f\\b|--force\\b)`), "git switch discards changes"],
	[new RegExp(`${GIT}stash\\s+(?:drop|clear|pop)\\b`), "git stash drop/clear/pop can lose stashed work"],
	[new RegExp(`${GIT}branch\\b[^;&|]*(?:\\s-D\\b|--delete\\s+--force|-d\\b)`), "deletes a git branch"],
	[new RegExp(`${GIT}(?:rebase|filter-branch|filter-repo|replace)\\b`), "rewrites git history"],
	[new RegExp(`${GIT}commit\\b[^;&|]*--amend\\b`), "rewrites the last commit"],
	[new RegExp(`${GIT}push\\b`), "pushes to a remote (outward-facing)"],
	[new RegExp(`${GIT}(?:rm|mv)\\b`), "git rm/mv removes or moves tracked files"],
	[new RegExp(`${GIT}update-ref\\b[^;&|]*\\s-d\\b`), "deletes a git ref"],
	[new RegExp(`${GIT}(?:gc\\b[^;&|]*--prune|prune\\b|reflog\\s+(?:expire|delete))`), "prunes git objects/reflog (destroys recovery points)"],
	[new RegExp(`${GIT}worktree\\s+remove\\b`), "removes a git worktree"],
	[new RegExp(`${GIT}init\\b`), "git init (may nest a repo inside another)"],

	// --- Rails / database ---
	[/\bdb:(?:drop|reset|purge|setup|schema:load|structure:load|migrate:reset|migrate:redo|migrate:down|rollback|seed:replant|truncate_all)\b/, "destructive Rails DB task"],
	[/\brails\s+(?:destroy|d)\b/, "rails destroy deletes generated files"],
	[/\b(?:dropdb|dropuser|pg_ctl|pg_ctlcluster|pg_dropcluster|pg_resetwal|pg_restore)\b/, "Postgres admin command"],
	[/\b(?:DROP\s+(?:TABLE|DATABASE|SCHEMA|INDEX|COLUMN)|TRUNCATE\b|DELETE\s+FROM|ALTER\s+TABLE\s+\S+\s+DROP)\b/i, "destructive SQL"],
	[/\.(?:destroy_all|delete_all|update_all|delete_by|destroy_by)\b/, "bulk ActiveRecord mutation"],
	[/\b(?:RAILS_ENV|RACK_ENV|NODE_ENV)=["']?prod/i, "targets production"],
	[/\brails\b[^;&|]*\s(?:-e|--environment)[=\s]+["']?prod/i, "targets production"],

	// --- environment / services ---
	[/\bdocker\b[^;&|]*\b(?:rm|rmi|prune|kill)\b/, "removes docker containers/images/volumes"],
	[/\b(?:docker[\s-])?compose\b[^;&|]*\bdown\b[^;&|]*(?:\s-v\b|--volumes|--rmi)/, "compose down removes volumes (database data)"],
	[/\bbundle\s+clean\b/, "bundle clean removes installed gems"],
	[/\bgem\s+(?:uninstall|cleanup)\b/, "removes installed gems"],
	[/\brvm\s+(?:remove|uninstall|implode|gemset\s+(?:delete|empty))\b/, "removes Ruby installs/gemsets"],
	[/\b(?:pkill|killall)\b/, "kills processes by name (may kill the DB server)"],
	[/\b(?:curl|wget)\b[^;&]*\|\s*(?:sudo\s+)?(?:ba|z|da)?sh\b/, "pipes a remote script into a shell"],
	[/\bnpm\s+(?:uninstall|rm|prune)\b|\byarn\s+remove\b/, "removes packages"],

	// --- sensitive locations ---
	[/\.DB_(?:data|backups|logs)\b/, "touches the Postgres data/backup directories"],
	[/(?:^|[\s/'"=])\.devcontainer\b/, "touches the devcontainer config"],
	[/(?:^|[\s'"=])(?:\S*\/)?\.git\/(?!hooks\/\S+\.sample)/, "touches .git internals directly"],
];

// Secrets: reading them sends the content to the model provider.
const SECRET_FILE = /(?:^|\/)(?:\.env(?:\.(?!example\b|sample\b|template\b|dist\b)[\w.-]+)?|master\.key|[\w.-]+\.key|[\w.-]+\.pem|id_(?:rsa|ed25519|ecdsa)|credentials(?:\/[\w.-]+)?\.yml\.enc|\.netrc|\.pgpass|auth\.json)$/;
const SECRET_IN_COMMAND = /(?:^|[\s'"=/<])(?:\.env(?:\.(?!example\b|sample\b|template\b|dist\b)[\w.-]+)?|master\.key|[\w.-]+\.pem|id_(?:rsa|ed25519)|\.netrc|\.pgpass)(?=$|[\s'";|&)>])|\bcredentials:(?:show|edit)\b|\b(?:printenv|env)\s*(?:$|[|;&])/;

/** Split on shell separators; good enough for the heuristics below. */
function segments(command: string): string[] {
	return command.split(/\s*(?:&&|\|\||;|\||\n)\s*/).filter(Boolean);
}

function words(segment: string): string[] {
	return (segment.match(/"[^"]*"|'[^']*'|\S+/g) ?? []).map((w) => w.replace(/^["']|["']$/g, ""));
}

export function classifyCommand(command: string, opts: ClassifyOptions = {}): Classification {
	const reasons = new Set<string>();
	for (const [re, reason] of COMMAND_RULES) if (re.test(command)) reasons.add(reason);
	if (SECRET_IN_COMMAND.test(command)) reasons.add("may print secrets (.env / keys / credentials) into the model context");

	const exists = opts.fileExists;
	for (const seg of segments(command)) {
		const w = words(seg);
		// cp onto an existing file overwrites it silently.
		if (w[0] === "cp") {
			const args = w.slice(1).filter((a) => !a.startsWith("-"));
			const target = args[args.length - 1];
			const flags = w.slice(1).filter((a) => a.startsWith("-")).join(" ");
			if (/-\w*[rR]|--recursive/.test(flags)) reasons.add("recursive copy may overwrite many files");
			else if (target && args.length >= 2 && (!exists || exists(target) || /[*?]/.test(target)))
				reasons.add(`cp overwrites existing file ${target}`);
		}
		// `> file` truncates an existing file (>> appends, 2>/&> to /dev/null are fine).
		for (const m of seg.matchAll(/(?<![0-9&>])>(?![>&|])\s*("[^"]+"|'[^']+'|[^\s;&|<>]+)/g)) {
			const target = m[1].replace(/^["']|["']$/g, "");
			if (target === "/dev/null" || target.startsWith("/dev/std")) continue;
			if (!exists || exists(target)) reasons.add(`redirect overwrites existing file ${target}`);
		}
		// tee without -a overwrites
		if (/^tee$/.test(w[0] ?? "") || seg.match(/(?:^|\s)tee\s/)) {
			const teeArgs = words(seg.slice(seg.indexOf("tee") + 3));
			if (!teeArgs.some((a) => a === "-a" || a === "--append")) {
				const t = teeArgs.find((a) => !a.startsWith("-"));
				if (t && (!exists || exists(t))) reasons.add(`tee overwrites existing file ${t}`);
			}
		}
	}
	return { risky: reasons.size > 0, reasons: [...reasons] };
}

export function isSecretPath(path: string): boolean {
	return SECRET_FILE.test(path.replace(/\\/g, "/"));
}

export type PathVerdict = { kind: "secret" | "protected" | "generated" | "migration"; reason: string } | null;

/** Classifies a path targeted by write/edit. */
export function classifyWritePath(path: string): PathVerdict {
	const p = path.replace(/\\/g, "/");
	if (isSecretPath(p)) return { kind: "secret", reason: "secret/credential file" };
	if (/(?:^|\/)\.git(?:\/|$)/.test(p)) return { kind: "protected", reason: ".git internals" };
	if (/(?:^|\/)\.DB_(?:data|backups|logs)(?:\/|$)/.test(p)) return { kind: "protected", reason: "Postgres data/backups" };
	if (/(?:^|\/)\.devcontainer\//.test(p)) return { kind: "protected", reason: "devcontainer config" };
	if (/(?:^|\/)\.pi\/guards\//.test(p)) return { kind: "protected", reason: "the safety guard itself" };
	if (/(?:^|\/)db\/(?:schema\.rb|structure\.sql|\w+_schema\.rb)$/.test(p))
		return { kind: "generated", reason: "generated DB schema (change it via a migration)" };
	if (/(?:^|\/)db\/(?:\w+_)?migrate\/\d+_\w+\.rb$/.test(p)) return { kind: "migration", reason: "existing migration" };
	return null;
}
