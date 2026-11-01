# Project Architecture Kit

This kit installs a shared architecture into a project and keeps both the team and AI agents from leaving that structure.

It has two goals:

- **Findability:** Someone new to the project can find the code behind a line on a screen by following folders.
- **Traceability:** Dependencies read top-down in one direction.

The full structure is in [template/docs/ARCHITECTURE.md](template/docs/ARCHITECTURE.md).

## How it protects the structure

| Protection | File | Effect |
|---|---|---|
| Rules | `docs/ARCHITECTURE.md`, `AGENTS.md`, `CLAUDE.md` | The team and AI learn the structure here. Following them is not guaranteed. |
| Immediate warning | `.claude/settings.json` | Claude Code runs the check after every edit and reports violations to the agent. It does not undo the file. It also blocks edits to the architecture files. |
| Commit block | `.githooks/pre-commit` | New violations cannot be committed, whichever tool is used. It can be skipped with `--no-verify`. |
| Merge block | `.github/workflows/architecture.yml`, `.github/CODEOWNERS` | Even if the hook is skipped, a PR with violations cannot be merged. Changes to the architecture files need code owner approval. |

The check's rules are in `tools/check-architecture.sh`. In existing projects, old violations are recorded and only new ones are blocked. Files in legacy folders can be edited, but new files cannot be added there.

## Requirements

- **Git:** On Windows, [Git for Windows](https://git-scm.com/download/win), which includes Git Bash.
- **Git repository:** The project that gets the kit must be a Git repository.
- **GitHub:** Only needed for the merge block. The main branch rule is not available for private repositories on GitHub Free.
- **Language:** Import checks work for Java, Kotlin, Dart, JavaScript, TypeScript and Python.

## Choose an install path

Both paths install the same files into the project.

| Path | For |
|---|---|
| [Claude Code plugin](#install-as-a-claude-code-plugin) | Claude Code users |
| [Install script](#install-with-the-script) | Users of other tools and anyone who prefers to install by hand |

The plugin does not replace the kit. It only works in the Claude Code of the person who installed it. The files that bind the team and other AI tools are still committed to the project.

## Install as a Claude Code plugin

Requires Claude Code 2.1.275 or later. Install the plugin:

```text
/plugin install project-architecture --marketplace Liosdali/AI_Agent_Skills
```

On older versions:

```text
/plugin marketplace add Liosdali/AI_Agent_Skills
/plugin install project-architecture@ai-agent-skills
```

Open Claude Code in the project that gets the kit and start the install:

```text
/project-architecture:install
```

Claude works out the settings from the project, shows the command it chose and asks for your approval. It does not commit or push. When the install finishes, continue from [step 4](#4-check-existing-files) below.

## Install with the script

### 1. Download the kit

```sh
git clone https://github.com/Liosdali/AI_Agent_Skills.git
cd AI_Agent_Skills/project-architecture
```

### 2. Choose the settings

`--src-root` is the folder that holds, or will hold, the layer folders (`app`, `screens`, `business` ...). `--import-prefix` is that folder's name as it appears in imports.

| Project | `--src-root` | `--import-prefix` |
|---|---|---|
| Java | `src/main/java/com/acme/app` | `com.acme.app` (required) |
| Kotlin | `src/main/kotlin/com/acme/app` | `com.acme.app` (required) |
| Flutter | `lib` | `package:app_name` |
| TypeScript, JavaScript | `src` | `@` if you use an alias, otherwise empty |
| Python | `src/app_name` | `app_name` |

If the prefix is empty, only relative imports are checked. The prefix is required for Java and Kotlin because all their imports use full names.

### 3. Install

An existing project:

```sh
sh install.sh /path/to/project --src-root src/main/java/com/acme/app --import-prefix com.acme.app --owner @username
```

A new, empty project:

```sh
git init /path/to/project
sh install.sh /path/to/project --src-root src --scaffold --owner @username
```

If Windows PowerShell does not recognize `sh`, open Git Bash or call Git's shell directly:

```powershell
& "$env:ProgramFiles\Git\bin\sh.exe" install.sh "C:\path\to\project" --src-root src --owner "@username"
```

`sh install.sh --help` lists all the options.

The script does the following:

- Copies the files in `template/` to the project root.
- Writes the settings to `tools/check-architecture.sh`, `AGENTS.md` and `.github/CODEOWNERS`.
- Records old violations in `tools/architecture-baseline.txt`.
- Sets `core.hooksPath` to `.githooks`.
- Adds `.githooks/pre-commit` to Git as executable.

It does not commit, push or move code.

### 4. Check existing files

The script never overwrites a file. The "Remaining steps" section of its output lists what to do by hand.

| Existing file | What the script does | What you do |
|---|---|---|
| `CLAUDE.md` | Adds the `@AGENTS.md` line | Nothing |
| `.gitattributes` | Adds the missing lines | Nothing |
| `AGENTS.md` | Leaves it alone | Add the rules from `template/AGENTS.md` |
| `.claude/settings.json` | Leaves it alone | Add the `hooks` and `permissions` sections from `template/.claude/settings.json` |
| `core.hooksPath` or a `pre-commit` hook | Leaves it alone | Add the line `sh tools/check-architecture.sh` to the existing hook |
| Others | Leaves them alone | Merge the content yourself |

### 5. Finish the remaining steps

1. **Fill in the commands:** Add the build and test commands to `AGENTS.md`.
2. **Commit:** Review the added files, commit and push.
3. **Enforce it on GitHub:** After the workflow has run once, create a rule for the main branch in the repository settings. Require the `architecture` check and code owner approval.

If you skip the last step the hooks still run, but they can be skipped with `--no-verify`.

### 6. Verify

Add an import of `screens/` to a file under `business/` and run the check:

```sh
sh tools/check-architecture.sh
```

You should see `[DEPENDENCY]` in the output. If you use Claude Code, have it make the same change and confirm that it receives the check message. Project settings only apply after you trust the folder, and `/hooks` shows the hooks. Then undo the change.

## Teammates

Everyone who clones a project with the kit installed runs this once in their copy:

```sh
git config core.hooksPath .githooks
```

## Having other AI agents install it

Start an agent other than Claude Code in the project folder and paste this:

```text
Clone https://github.com/Liosdali/AI_Agent_Skills to a temporary folder and read
project-architecture/README.md. Work out the --src-root and --import-prefix values
for this project, show me the values you chose and get my approval. Then install the
kit with install.sh. Follow the "Remaining steps" list, but ask me before you commit
or push. Do not move or change existing code.
```

If a tool does not read `AGENTS.md`, add a line to that tool's instruction file telling it to read `AGENTS.md`.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `sh` is not recognized | You are in PowerShell. Open Git Bash or use the PowerShell command above. |
| `... is not a Git repository` | Run `git init` in the project folder. |
| `Source root not found` | Check the `--src-root` value. In a new project, add `--scaffold`. |
| `--import-prefix is required` | Give the package name for Java or Kotlin. |
| The check finds no violations | `--import-prefix` may not match your imports. Fix the value in `tools/check-architecture.sh`. |
| A commit is blocked | Fix the violation in the output. If it is a generated folder, add it to `EXTRA_DIRS`. |
| A rule really did change | The code owner runs `sh tools/check-architecture.sh --update-baseline` and proposes the result in a PR. |
| Claude Code cannot edit a protected file | This is expected. Make the change by hand or temporarily remove the matching `deny` line from `.claude/settings.json`. |

## Limits of the automatic check

- **Checked:** Folder layout, dependency direction, rows using `Store` or `Service`, static access to the shell and `Manager`, `Helper`, `Utils` file names.
- **Not checked:** Names matching the screen, business rules written in screens, unnecessary abstractions and whether the interface follows the design file. The PR list in `docs/ARCHITECTURE.md` Section 17 covers these.

## Updating the kit

The script leaves existing files alone, so running it again does not update a project. To get a new version, run `git pull` or update the plugin. Then copy the changed `template/` files into the project by hand. Keep the settings in `tools/check-architecture.sh` and the `tools/architecture-baseline.txt` file.

Version 2 renames the rule codes in the baseline. A project that installed version 1 runs `sh tools/check-architecture.sh --update-baseline` once after copying the new check.

To update the plugin:

```text
/plugin marketplace update ai-agent-skills
/plugin update project-architecture@ai-agent-skills
```

## Working on the kit

```text
project-architecture/
├─ .claude-plugin/  # Plugin definition
├─ README.md        # This guide
├─ install.sh       # Install script
├─ skills/          # The plugin's install command
├─ template/        # Files copied into the project
└─ tests/           # Kit tests
```

Tests run in CI on Ubuntu, macOS and Windows. To run them locally:

```sh
bash tests/test-kit.sh
claude plugin validate .
```

Increase `version` in `.claude-plugin/plugin.json` whenever the kit changes. Otherwise users may not receive the update.
