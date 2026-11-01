# Project Architecture

This structure has two goals:

1. Someone new to the project can find the code behind a line on a screen by following the folder hierarchy.
2. Dependencies can be traced top-down in one direction.

The goal is not to create many layers. A layer, folder or class is added only if it makes the code easier to read.

The binding rules for AI agents are in `AGENTS.md`. Some of the rules are checked automatically by `tools/check-architecture.sh`.

## 1. Where code goes

| Code | Location |
|---|---|
| App startup, object setup | `app/` |
| Screen list and route mapping | `app/Routes` |
| Window, shared regions, switching screens | `shell/` |
| Screen skeleton | `screens/<menu-section>/<screen>/XScreen` |
| Data shown on the screen | `XData` |
| Clicks and input handling | `XActions` |
| Screen sections and rows | `<screen>/sections/` |
| Tabs and popups | `<screen>/tabs/`, `<screen>/dialogs/` |
| Business pieces used on several screens | `screens/common/` |
| Calculations, rules, workflows | `business/<topic>/` |
| Reading and writing data | `business/<topic>/XStore` |
| Business state shared across screens | `business/session/` |
| Background work with no screen | `jobs/` |
| Components with no business knowledge | `shared/ui/` |
| Money, date and number formats | `shared/format/` |
| Database, HTTP, auth, logging, settings | `platform/` |
| Screen text | `resources/text/` |
| Tests | Same path under `tests/` |

## 2. File structure

The order screens are only an example. Spelling (`order-detail`, `orderdetail`) follows the standard of the language in use.

```text
project/
├─ AGENTS.md                      # Rules for AI agents
├─ docs/
│  └─ ARCHITECTURE.md             # This file
├─ tools/                         # Architecture check
├─ src/
│  ├─ app/
│  │  ├─ Main                     # Entry point
│  │  ├─ Wiring                   # The one place objects are set up
│  │  └─ Routes                   # List of all screens
│  │
│  ├─ shell/                      # The shell around all screens
│  │  ├─ AppFrame                 # Window and region layout
│  │  ├─ ScreenHost               # Center area, switches the active screen
│  │  ├─ ShellState               # Is the sidebar open, which tab is active
│  │  ├─ input/
│  │  │  └─ GlobalShortcuts       # App-wide shortcuts
│  │  └─ regions/                 # Regions visible on every screen
│  │     ├─ header/
│  │     │  ├─ HeaderRegion
│  │     │  └─ HeaderData
│  │     ├─ sidebar/
│  │     └─ status-bar/
│  │
│  ├─ screens/                    # The screens the user sees
│  │  ├─ orders/                  # Menu section
│  │  │  ├─ order-list/           # Screen: Orders
│  │  │  └─ order-detail/         # Screen: Order Detail
│  │  │     ├─ OrderDetailScreen  # Skeleton: which section goes where
│  │  │     ├─ OrderDetailData    # All data shown on the screen
│  │  │     ├─ OrderDetailActions # Clicks and input handling
│  │  │     ├─ sections/
│  │  │     │  ├─ summary/        # Section: Summary
│  │  │     │  │  ├─ SummarySection
│  │  │     │  │  ├─ TotalAmountRow   # Row: Total Amount
│  │  │     │  │  └─ DeliveryDateRow  # Row: Delivery Date
│  │  │     │  └─ items/          # Section: Items
│  │  │     ├─ tabs/              # If the screen has tabs
│  │  │     └─ dialogs/           # Popups opened from this screen
│  │  ├─ editor/
│  │  │  └─ drawing/              # Example of a complex screen
│  │  │     ├─ DrawingScreen
│  │  │     ├─ DrawingData
│  │  │     └─ sections/canvas/
│  │  │        ├─ CanvasSection
│  │  │        ├─ input/          # Mouse and keyboard
│  │  │        └─ render/         # Drawing
│  │  └─ common/                  # Business pieces used on several screens
│  │
│  ├─ business/                   # Business topics, does not know screens
│  │  ├─ orders/
│  │  │  ├─ Order                 # Model
│  │  │  ├─ OrderTotal            # Calculation rule
│  │  │  ├─ OrderService          # Operations: create, cancel
│  │  │  └─ OrderStore            # Reading and writing
│  │  ├─ customers/
│  │  └─ session/                 # Business state shared across screens
│  │     ├─ CurrentUser
│  │     └─ ActiveCustomer
│  │
│  ├─ jobs/                       # Work with no screen: timers, sync
│  ├─ shared/                     # Shared pieces with no business knowledge
│  │  ├─ ui/                      # Button, table, theme
│  │  ├─ format/                  # Money, date and number formats
│  │  ├─ navigation/
│  │  │  ├─ Route                 # Screen identifiers
│  │  │  └─ Navigator             # Interface for opening screens
│  │  └─ feedback/
│  │     └─ Feedback              # Interface for showing messages to the user
│  └─ platform/                   # The outside world
│     ├─ database/
│     ├─ http/
│     ├─ auth/
│     ├─ logging/
│     └─ config/
├─ resources/
│  └─ text/                       # Screen text
└─ tests/                         # Same hierarchy as src
```

Files the language or framework requires (for example an entry file at the root) stay where they are and pass straight to `app/`.

## 3. Dependency direction

```text
app → shell, screens, jobs → business → platform
```

- `app/` knows everything and connects the pieces.
- `shell/` and `screens/` do not know each other. Both use the `shared/navigation` and `shared/feedback` interfaces.
- `business/` does not know screens, and `platform/` does not know business topics.
- `shared/` can be used from anywhere, but it does not know business topics.
- The `shell/`, `screens/` and `jobs/` layers use only `logging` and `config` from `platform/`.
- A business topic depends on the class another topic exposes, not on its internal files. If two topics need each other, the shared part is split out.

Dependencies are passed through the constructor and set up in `app/Wiring`. That way, what a class depends on is visible at first glance.

## 4. Required rules

1. **Names follow the screen:** Folders and files match the visible screen, section and row. The same data has the same name in every layer (`totalAmount`).
2. **Each screen has one data gate:** Sections and rows do not fetch data. They get it through `XData`.
3. **Business rules are not written in screens:** Calculations and decisions stay in `business/`.
4. **Dependencies go down:** The direction in Section 3 is not broken, and no cycles are created.
5. **No hidden access:** Static access such as `AppFrame.getInstance()` and a general event bus are not used.
6. **The design file is not left:** If the project has an md file that defines the design (for example `DESIGN.md`), the interface follows that file. If something that is not in the file is needed, a person updates the file first.

## 5. Finding the data on a screen

Example question: "Why is the Total Amount on the Order Detail screen wrong?"

| Step | Question | Location | What you see there |
|---|---|---|---|
| 1 | Which screen? | `screens/orders/order-detail/` | Screen name, `app/Routes` if needed |
| 2 | Which section? | `sections/summary/` | Summary section |
| 3 | Which row? | `TotalAmountRow` | Shows `data.totalAmount` |
| 4 | Where does the value come from? | `OrderDetailData` | `totalAmount = OrderTotal.of(order)` |
| 5 | How is it calculated? | `business/orders/OrderTotal` | Calculation rule |
| 6 | Where does the raw data come from? | `business/orders/OrderStore` | Query |

The text file is a shortcut. Search for the text on the screen and the key tells you the location:

```text
orderDetail.summary.totalAmount = "Total Amount"
  screen    section     row

shell.header.userName = "User"
shell region   row
```

Where to look, by problem:

| Problem | Location |
|---|---|
| Appearance or layout is wrong | `screens/.../sections/` |
| The screen gets the wrong value | `XData` |
| A calculation or business rule is wrong | `business/<topic>/` |
| A record does not arrive or is not written | `business/<topic>/XStore` |
| A click does the wrong thing | `XActions` |
| The top bar, menu or status bar is wrong | `shell/regions/` |
| Text is wrong | `resources/text/` |
| A money or date format is wrong | `shared/format/` |
| Connection or auth error | `platform/` |

## 6. File names

| Suffix | Purpose |
|---|---|
| `XScreen` | Screen skeleton |
| `XData` | Data given to a screen or region |
| `XActions` | User actions |
| `XSection` | Screen section |
| `XRow` | A single row |
| `XRegion` | Shared region in the shell |
| `XDialog` | Popup |
| `XService` | Business operations |
| `XStore` | Reading and writing data |
| `XTool` | Changeable behavior such as a mouse mode |

The names `Manager`, `Helper` and `Utils` are not used. Pick a name that describes the job in one sentence.

## 7. Shared areas

| Shared area | Example | Location |
|---|---|---|
| Region visible on every screen | Top bar, sidebar, status bar | `shell/regions/` |
| Business piece used on several screens | Customer card | `screens/common/` |
| Component with no business knowledge | Button, table | `shared/ui/` |
| Business state across screens | Active user, selected customer | `business/session/` |
| Shell view state | Is the sidebar open | `shell/ShellState` |
| State of a single screen | Filter, sort order | `XData` |
| Environment setting | Server address | `platform/config/` |
| Theme | Color, font | `shared/ui/theme/` |

Each topic in `business/session/` is its own small class. Do not create a single `AppState` class with many fields. Data used by only one screen stays in that screen.

## 8. The shell and AppFrame

`AppFrame` only sets up the window and places the regions. It contains no business rules, no screen names and no `getInstance()`. `AppLayout` on the web and `HomeShell` on mobile play the same role.

```java
public final class AppFrame extends JFrame {
    public AppFrame(HeaderRegion header, SidebarRegion sidebar,
                    ScreenHost screenHost, StatusBarRegion statusBar) {
        add(header, BorderLayout.NORTH);
        add(sidebar, BorderLayout.WEST);
        add(screenHost, BorderLayout.CENTER);
        add(statusBar, BorderLayout.SOUTH);
    }
}
```

Panels do not call each other directly:

| Need | How |
|---|---|
| Go to another screen | `navigator.open(Route.ORDER_DETAIL)` |
| Update other places when shared data changes | Listen to the `business/session/` class |
| Show a message | `feedback.show(...)` |

```java
// Wrong: the class depends on AppFrame and every panel
AppFrame.getInstance().getHeader().setCustomer(customer);
AppFrame.getInstance().getOrdersPanel().reload();

// Right: the class knows only what it needs
activeCustomer.set(customer);        // The header and order screen listen to this
feedback.show("Customer selected");  // The status bar shows it
```

A general event bus is not used, because you cannot trace where an event comes from or where it goes. With named classes such as `ActiveCustomer`, "Find Usages" finds the listeners.

## 9. Multiple entry points

- Each real entry point is a separate file in `app/` (`EditorMain`, `ViewerMain`).
- An entry point only sets up objects and opens the app.
- Trial entry points move to `tests/manual/`, and unused ones are deleted.
- Move to a separate build module only if the apps ship as separate products with different dependencies.

## 10. Complex screens

Technical layers such as mouse, keyboard and drawing do not sit at the top level. They go inside the section they belong to.

```text
Mouse → input/CanvasMouseHandler → active Tool → state or model changes
      → refresh requested → render/CanvasRenderer draws
```

- Mouse code does not draw, and drawing code does not change data.
- The `Tool` interface is created only when there are at least two mouse modes.
- Long drawing code moves to `render/`, and long input code moves to `input/`.

## 11. When to add an abstraction

| What to add | Condition |
|---|---|
| Service | There is a real rule or more than one data source |
| Interface | There are two real implementations, or an external system is replaced by a fake in tests |
| `shared/` | The code is used a third time and has no business knowledge |
| DTO or mapper | The data shapes really differ |
| `domain/` subfolder | Only in a business topic with very heavy rules |

Calculation and decision code is written as pure functions where possible, so it can be tested without a database or network.

## 12. Limiting the number of files

- A row with no logic or custom appearance of its own does not get a separate file. It stays in the section file.
- On a small screen, `Screen`, `Data` and `Actions` can stay in one file.
- `sections/`, `tabs/` and `dialogs/` are created only if the screen has them.
- Consider a subfolder when a folder passes 7-8 files.
- Review files over 400 lines and functions over 40 lines. These are signals, not hard limits.

## 13. Finding unnecessary code

| Sign | Check | Action |
|---|---|---|
| Pass-through class | Do its methods only forward to another class? | Merge it into the caller and delete the class |
| Interface with one implementation | Does it also have no fake in tests? | Delete the interface |
| Unused code | Do tools and search find no references? Also check reflection, DI and route usage. | Delete it |
| Helper called from one place | Does it have only one user? | Move it next to that user |
| Vague class | Can you not describe its job in one sentence? | Split it by responsibility |
| Duplicate code | Is it the same rule, or a coincidence? | Merge if it is the same rule, otherwise leave it |
| Unused flexibility | Does a parameter or flag always get the same value? | Remove it |

## 14. Other project types

| Project type | `screens/` equivalent | Sub-parts |
|---|---|---|
| Web, mobile | Page or screen | Section, row |
| Desktop | Window | Panel, row, canvas |
| Backend API | `endpoints/` | Endpoint, response field |
| Command-line tool | `commands/` | Command, output field |

`business/` and `platform/` stay the same in all of these. If another name replaces `screens/`, also update the layer lists in `tools/check-architecture.sh` and `tools/check-architecture.awk`.

## 15. Moving an existing project

1. **Protect it:** Write a few end-to-end tests for the critical flows.
2. **Record old violations:** Run `sh tools/check-architecture.sh --update-baseline`. From then on, only new violations are blocked. Existing files in legacy folders can be edited, but new files cannot be added there.
3. **Delete:** Remove dead code and pass-through classes.
4. **Sort the entry points:** Mark each one as real, trial or dead.
5. **Gather the setup:** Turn static access into constructor parameters and move setup into `app/Wiring`.
6. **Split AppFrame:** Separate screen switching, messages and shared data, in that order. During the move, old methods can forward to the new classes.
7. **Move the screens:** Start with the screen that changes most. Legacy folders can sit beside the new structure during the move.

Two rules apply at every step:

- Structure and behavior changes do not go in the same commit.
- Rarely touched, working modules are not moved just to fit this structure.

## 16. Automatic check and exceptions

`tools/check-architecture.sh` checks the following:

| Rule code | What it checks |
|---|---|
| `FOLDER` | Was an undefined top-level folder created, or a new file added to a legacy folder |
| `DEPENDENCY` | Do imports follow the direction in Section 3 |
| `SECTION_DATA` | Do sections and rows use `Store` or `Service` |
| `STATIC_SHELL` | Is there static access to the shell |
| `FILE_NAME` | Was the name `Manager`, `Helper` or `Util` used |

The check reads Java, Kotlin, Dart, JavaScript, TypeScript and Python imports. It cannot see usage by full name or dependencies between business topics, so code review covers these. For other languages, use the language's own tool for the layer rules.

If you need an exception:

- A decision that changes the structure changes this file in a PR first, and then the code is written.
- `tools/architecture-baseline.txt` is updated only by a person's decision and goes through code owner approval.
- When a rule changes, `docs/ARCHITECTURE.md`, `AGENTS.md` and the check script are updated together.

## 17. PR checklist

- [ ] Is the new code in its place from Section 1?
- [ ] Can the code be reached from the visible screen, section and row by following the hierarchy?
- [ ] Does each new class or interface meet the condition in Section 11?
- [ ] Are there no moves or renames unrelated to the task?
- [ ] Are structure and behavior changes in separate commits?
- [ ] If the interface changed, does it follow the design md file?
- [ ] Do the architecture check and tests pass?
