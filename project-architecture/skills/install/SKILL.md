---
name: install
description: Installs the Project Architecture kit into the open project. Adds the file structure guide, AI agent rules and the automatic architecture check.
argument-hint: "[source root, import prefix or code owner]"
disable-model-invocation: true
---

# Install the Project Architecture kit

Extra information from the user: $ARGUMENTS

The kit files are in this folder: `${CLAUDE_PLUGIN_ROOT}`

## Steps

1. Read `${CLAUDE_PLUGIN_ROOT}/README.md`.
2. Confirm that the working folder is a Git repository. If it is not, stop and ask the user whether to run `git init`.
3. Look at the project and choose the `install.sh` options:
   - `--src-root`: The folder that holds, or will hold, the layer folders.
   - `--import-prefix`: That folder's name as it appears in imports. Required for Java and Kotlin.
   - `--extra-dirs`: Top-level folders the language or framework requires.
   - `--owner`: GitHub user or team. If you are not sure, ask the user. Do not guess.
   - `--scaffold`: Only if the source root does not exist yet.
4. Show the values you chose and the command you will run. Wait for the user's approval.
5. After approval, install the kit:

   ```sh
   sh "${CLAUDE_PLUGIN_ROOT}/install.sh" "<project root>" --src-root <path> [options]
   ```

   If Windows PowerShell does not recognize `sh`, use the PowerShell command in `README.md`.
6. Tell the user the "Remaining steps" list from the command's output. If the build and test commands are clear from the project, write them in `AGENTS.md`. If not, ask the user.

## Do not

- Commit or push without asking the user.
- Move or change existing code.
- Run `--update-baseline`. The install script does this itself on first install.
- Change an existing `AGENTS.md` or `.claude/settings.json` without asking the user.

## Result

Tell the user: the values used, the files added, the check result and the remaining steps.

The plugin does not protect the project by itself. Point out that the files that bind the team and other AI tools must be committed and that the GitHub rule must be turned on.
