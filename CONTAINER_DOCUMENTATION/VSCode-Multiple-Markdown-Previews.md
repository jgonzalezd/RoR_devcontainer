# Simultaneous Markdown Previews in VS Code

This guide explains why VS Code allows only one Markdown preview open by default and how to enable multiple simultaneous Markdown previews using built-in configuration—**without installing third-party extensions**.

---

## The Problem

By default, VS Code's built-in Markdown preview is **dynamic**:
- When you open a preview (`Ctrl+Shift+V` or `Ctrl+K V`), a single preview panel tracks whichever Markdown document currently has editor focus.
- Switching to another `.md` file automatically replaces the contents of the existing preview tab.
- Attempting to open a preview for a second Markdown file simply updates or re-focuses the existing preview tab rather than opening a new one.

---

## Solutions (No Extensions Required)

### Option 1: Remap Keybinding to Open Locked Previews (Recommended)

VS Code contains a built-in command (`markdown.showLockedPreviewToSide`) that opens an independently locked preview tab. However, by default, VS Code does not assign a shortcut to it.

Once a preview is locked (`[Preview] filename.md`), it is pinned to that specific file and will not change when you navigate between files. Opening another preview creates a separate, new preview tab.

#### Setup:
1. Open Command Palette: `Ctrl+Shift+P` (or `Cmd+Shift+P` on macOS).
2. Run **Preferences: Open Keyboard Shortcuts (JSON)**.
3. Add the following keybinding:

```json
[
  {
    "key": "ctrl+k v",
    "mac": "cmd+k v",
    "command": "markdown.showLockedPreviewToSide",
    "when": "editorFocus && editorLangId == 'markdown'"
  }
]
```

#### How It Works:
- Pressing `Ctrl+K V` / `Cmd+K V` in any Markdown file opens a dedicated, locked preview to the side.
- Opening another Markdown file and pressing `Ctrl+K V` opens a *second* preview tab beside the first, allowing you to view 2 or more files side-by-side simultaneously.

---

### Option 2: Set Markdown Preview as the Default Editor for `.md` Files

If your primary goal is reading or referencing multiple documentation files at once, you can configure VS Code to treat Markdown preview mode as the default editor. Each `.md` file will open in its own independent tab.

#### Setup:
Add the following to your User Settings (`Ctrl+Shift+P` -> **Preferences: Open User Settings (JSON)**) or workspace settings (`.vscode/settings.json`):

```json
{
  "workbench.editorAssociations": {
    "*.md": "vscode.markdown.preview.editor"
  }
}
```

#### How It Works:
- Clicking any `.md` file in the File Explorer or Quick Open (`Ctrl+P`) opens it as a rendered static preview tab (`StaticMarkdownPreview`).
- You can open as many files as you like; each Markdown document gets its own tab.
- **To view/edit the raw Markdown source:**
  - Click the **"Show Source"** icon (`</>`) in the top-right corner of the editor tab, or
  - Press `Ctrl+Shift+V` / `Cmd+Shift+V`, or
  - Right-click the tab and choose **Reopen Editor With... -> Text Editor**.

---

### Option 3: Manual On-The-Fly Preview Locking (Zero Configuration)

If you only occasionally need to compare two Markdown files side-by-side without modifying configuration files:

1. Open your first Markdown file and open its preview (`Ctrl+K V`).
2. Focus the preview tab and click the **`...` (More Actions)** menu in the upper-right corner of the editor tab.
3. Select **Toggle Preview Locking** (or run `Markdown: Toggle Preview Locking` in the Command Palette).
   - The preview tab title will change from `Preview filename.md` to `[Preview] filename.md`.
4. Switch to your second Markdown file and open its preview.
5. The first preview will stay locked in place, and a second preview will open for the new file.

---

## Comparison Summary

| Method | Configuration Needed | Workflow Impact | Best For |
|---|---|---|---|
| **Option 1: `markdown.showLockedPreviewToSide`** | 1 keybinding in `keybindings.json` | Files open as code by default; preview shortcut opens independent pinned previews | Side-by-side editing & authoring multiple docs |
| **Option 2: `workbench.editorAssociations`** | 1 setting in `settings.json` | Files open directly as rendered previews; toggle back to code when needed | Heavy documentation reading & reference |
| **Option 3: Manual Toggle Lock** | None (Built-in UI/Command) | Requires clicking "Toggle Preview Locking" for each preview tab | Rare/one-off comparisons |
