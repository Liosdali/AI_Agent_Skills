# AGENTS.md

This file is binding for all AI agents working in this project. The reasons and examples behind the rules are in `docs/ARCHITECTURE.md`. Read that file before writing code.

## This project

- Source root: `src/`
- Build: `<build command>`
- Test: `<test command>`
- Architecture check: `sh tools/check-architecture.sh`
- Architecture check in Windows PowerShell: `& "$env:ProgramFiles\Git\bin\sh.exe" tools/check-architecture.sh`

## Core rules

### 1. Think Before Coding

- Don't assume. If something is unclear, stop and ask.
- Don't hide confusion. Name what's confusing.
- Surface tradeoffs before you make the call.
- Restate the assumption back so we know we agree.

### 2. Simplicity First

- Minimum code that solves the problem.
- No speculative features. No flexibility nobody asked for.
- No abstractions for single-use code.
- No error handling for impossible scenarios.
- Test: would a senior engineer call this overcomplicated? If yes, simplify.

### 3. Surgical Changes

- Touch only what you must to satisfy the request.
- Don't reformat, refactor, or "improve" adjacent code.
- Match the existing style even if you would do it differently.
- If you notice unrelated dead code, mention it. Do not delete it.
- Test: every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

- Transform tasks into verifiable goals before you write any code.
- "Add validation" becomes "write tests for invalid inputs, then make them pass."
- "Fix the bug" becomes "write a test that reproduces it, then make it pass."
- For multi-step tasks, write the plan first. Attach a check to each step.
- Loop until the goal is verified. Do not declare done until it is.

## Before writing code

1. Find where the change belongs in `docs/ARCHITECTURE.md` Section 1.
2. Read similar files in the same folder and use the same pattern.
3. If the task does not fit the file structure, stop and ask the user.

## Strict rules

1. **Layout:** The source root contains only `app`, `shell`, `screens`, `business`, `jobs`, `shared` and `platform`. Do not create a new top-level folder.
2. **Dependency direction:** `app → shell, screens, jobs → business → platform`. `shell` and `screens` do not import each other. These two layers and `jobs` use only `logging` and `config` from `platform`.
3. **Names:** Folder and file names match the visible screen, section and row. The same data has the same name in every layer.
4. **Data gate:** Sections and rows do not use `Store` or `Service`. They get data through `XData`.
5. **Business rules:** Calculation and decision code goes in `business/`, not in screens.
6. **Shell:** `AppFrame` or its equivalent only sets up the window and regions. Do not use static access or a general event bus.
7. **Naming:** Do not create files or classes named `Manager`, `Helper` or `Utils`.
8. **Abstraction:** Add an interface, service, mapper or `shared/` code only when the condition in `docs/ARCHITECTURE.md` Section 11 is met.
9. **Design:** If the project has an md file that defines the design (for example `DESIGN.md`), read it before writing interface code and stay inside it. Do not add colors, fonts, sizes, components or interactions that are not in the file. If the task conflicts with the file or the file does not cover the task, stop and ask the user. Do not change the file unless the user asks.

## Do not do these without asking the user

- Create a new layer or top-level folder.
- Add a new dependency or framework.
- Move, rename or edit code outside the task.
- Change these files: `AGENTS.md`, `CLAUDE.md`, `docs/ARCHITECTURE.md`, `.claude/settings.json`, `.githooks/`, `.github/CODEOWNERS`, `.github/workflows/architecture.yml`, `tools/check-architecture.*`, `tools/architecture-baseline.txt`.
- Use `--update-baseline` or `--no-verify`.

## Legacy code

The project may be moving to this structure.

- Write new code in the new structure. You can edit existing files in legacy folders, but do not add new files there.
- Do not move legacy code the task does not require.
- If the task is a move, do not change behavior and make the move in its own commit.

## If the check fails

Fix the code to follow the rule. Do not try to pass by changing the check, the baseline or the rule. If the rule cannot be followed, stop and tell the user why.

## Before finishing

1. Run `sh tools/check-architecture.sh`.
2. Run the project's tests.
3. Tell the user: the files added, the check result, the test result and anything that does not fit the structure.
