# MouseFree2 – Codebase Understanding

## Purpose

MouseFree2 is a Windows desktop utility that lets users operate the mouse entirely from the keyboard.
It overlays a transparent grid (or an element view) on each monitor.  The user types keys to
navigate/narrow the grid and then issues a click — left, right, middle, single, double, triple, or
quad — without touching the mouse.

---

## Solution Structure

| Project | Type | Role |
|---|---|---|
| **MouseFree** | Win32 GUI application (`.exe`) | Entry point, message loop, YAML config loading |
| **MouseFreeLib** | Static library (`.lib`) | All application logic |
| **MouseFreeTests** | Google Test executable | Unit tests and stubs for the library |

---

## High-Level Architecture

```
┌────────────────────────────────────────────────────────────┐
│  MouseFree.cpp  (wWinMain)                                 │
│  • Loads YAML config → CashMan (parameters)                │
│  • Creates UserSystem → per-monitor UserMonitor objects    │
│  • Installs KeyboardHookService                            │
│  • Standard Win32 PeekMessage / DispatchMessage loop       │
└──────────────────┬─────────────────────────────────────────┘
                   │ creates
                   ▼
┌────────────────────────────────────────────────────────────┐
│  UserSystem                                                 │
│  • Enumerates monitors → vector<UserMonitor>               │
│  • Provides virtual-desktop dimension helpers              │
└──────────────────┬─────────────────────────────────────────┘
                   │ owns one per monitor
                   ▼
┌────────────────────────────────────────────────────────────┐
│  UserMonitor                                                │
│  • TopAppWindow + BottomAppWindow (transparent overlays)   │
│  • Grid (spatial subdivision)                              │
│  • Clickers (grid cells and element targets)               │
│  • WndProcData (shared pointer bag for WndProc callbacks)  │
└────────────────────────────────────────────────────────────┘
```

All application-wide singletons live in `Globals` (static members).

---

## Module Reference

### 1. Entry Point – `MouseFree/src/MouseFree.cpp`

The Win32 `wWinMain` function.

| Item | Description |
|---|---|
| `wWinMain` | Installs exception/signal handlers, loads YAML, creates `UserSystem`, runs message loop |
| `PerformEmergencyCleanup` | Called from every error path; stops keyboard hook, destroys overlay windows, saves config |
| `CustomTerminateHandler` | C++ terminate hook; cleans up before `std::abort()` |
| `CustomSEHTranslator` | SEH-to-C++ exception translator |
| `SignalHandler` | POSIX signal handler (SIGABRT, SIGSEGV, etc.) |
| `EmergencyKeyboardCleanup` | Exported `extern "C"` function for external cleanup tools |

---

### 2. Globals – `globals.h` / `globals.cpp`

Central application state — all members are `static`.

| Member | Type | Description |
|---|---|---|
| `running` | `bool` | Main loop sentinel |
| `viewType` | `ViewType` | `GRID` or `ELEMENT` |
| `gridType` | `GridType` | `FULL_GRID`, `HOMEROW_GRID`, or `ARROW_GRID` |
| `activeMonitor` | `int` | Zero-based index of the monitor receiving keyboard input |
| `monitorNumberToHMonitor` | `unordered_map<int,HMONITOR>` | Index → Win32 monitor handle |
| `wndProcDatas` | `unordered_map<HMONITOR,WndProcData*>` | Monitor → per-window-proc state |
| `elementClickers` | `Clickers` | All UI element click targets (element view) |
| `collisionDetector` | `CollisionDetector` | Prevents label placement overlap |
| `elementHelper` | `ElementClickersHelper` | Builds element clickers from UIA enumeration |
| `processedWindows` | `ProcessedWindows` | Tracks enumerated windows |
| `cashMan` / `parameters` | `CashMan` | Key-value stores (app data and YAML config) |
| `configData` | `ConfigMetadata` | Config dialog definition and values |
| `focusManager` | `FocusEventManager` | UIA focus-change monitoring (currently disabled) |
| `activationState` | `ActivationState` | `NOTACTIVE` / `ACTIVE` |
| `multiplePressInterval` | `DWORD` | Milliseconds between presses for multi-click detection |

**Key enums defined here:**
- `ViewType` (`GRID`, `ELEMENT`)
- `GridType` (`FULL_GRID`, `HOMEROW_GRID`, `ARROW_GRID`)
- `ClickType` (`NONE`, `LEFT`, `RIGHT`, `MIDDLE`)
- `ClickRepetition` (`NONE`, `S`, `D`, `T`, `Q` — single/double/triple/quad)
- `ActivationState`, `MonitorOrientation`

---

### 3. Window Layer – `AppWindow`, `TopAppWindow`, `BottomAppWindow`

**`AppWindow`** (`app_window.h/cpp`)  
Base class for transparent overlay windows.

| Member | Description |
|---|---|
| `AppWindow(...)` | Registers the window class, creates the HWND |
| `GetHWnd()` | Returns the window handle |

**`TopAppWindow`** (`top_app_window.h/cpp`)  
Topmost layered transparent window used for overlay painting and input capture.

**`BottomAppWindow`** (`bottom_app_window.h/cpp`)  
A child/sibling layered window painted below the top window; receives some drawing for the bottom portion of the grid overlay.

**`WndProcData`** (`MouseFree.h`)  
Plain-old-data struct passed via `GWLP_USERDATA` to both WndProcs.  Carries pointers to the per-monitor `Grid`, `Clickers`, `HPEN`, monitor info, and both HWNDs.

**`window_helpers.h/cpp`**  
Free functions for window creation, painting, and WndProc entry points.

| Function | Description |
|---|---|
| `WndProc` | Top overlay WndProc: handles keyboard, paint, timer, command, and click messages |
| `BottomWindowProc` | Bottom overlay WndProc: handles paint and structural messages |
| `MyRegisterClass` | Registers a WNDCLASS for the overlay |
| `CreateTopWindow` / `CreateBottomWindow` | Create the overlay HWNDs |
| `initializeGrid` / `loadGrid` | Set up or repaint a grid's clickers |
| `paintGridWindow` / `paintElements` | GDI painting entry points |
| `addLabelsOnScreen` | Draws key labels onto the overlay HDC |
| `ConfigDlgProc` / `HelpDlgProc` / `AboutDlgProc` | Dialog procedures |
| `ResetApplication` / `OpenApplication` | Tear-down and re-initialization helpers |
| `EnumPaintGrid` / `EnumPaintElements` | `EnumDisplayMonitors` callbacks for painting |
| `EnumProcessNavigateGrid` / `EnumProcessGridReset` / etc. | `EnumDisplayMonitors` callbacks for keyboard actions |

---

### 4. Grid – `Grid` (`grid.h/cpp`)

Manages the recursive spatial subdivision of a single monitor's screen.

**States:** `NORMAL → SMALL → TINY` as the user narrows down.

| Method | Description |
|---|---|
| `Grid(...)` | Constructed with screen dimensions and aspect ratio |
| `reset()` | Returns grid to full-screen `NORMAL` state |
| `navigateGrid(LPARAM)` | Moves the active region based on a directional key code |
| `nudgeGrid(LPARAM)` | Fine-tunes the center point of the current region |
| Getters | Expose `xMin/xMax/yMin/yMax`, `xStep/yStep`, `divisions`, `center`, orientation, state |

Grid types (FULL, HOMEROW, ARROW) control which keys correspond to which grid cells, configured in YAML.

---

### 5. Clicker / Clickers – `clicker.h`, `clickers.h`

Represent a labeled, clickable target on-screen.

**`Clicker`** — a single target:

| Field | Description |
|---|---|
| `name` | Element/window name |
| `label` | Keyboard shortcut string displayed on screen |
| `hWnd` / `hMonitor` | Owner window and monitor |
| `elementId` | UIA runtime element ID |
| `clickerType` | `Window` or `Taskbar` |
| `controlType` | UIA control type integer |
| Bounding box (`left/top/right/bottom`) | Element rect |
| `clickX/Y` | Actual coordinates sent for the click |
| `labelX/Y` | Where the key label is drawn |

**`Clickers`** — keyed map of `Clicker` objects:

| Method | Description |
|---|---|
| `add(clicker)` | Insert |
| `find(label)` | Lookup by label key |
| `remove(label)` | Erase |
| `clear()` | Reset |
| `contains(label)` | Membership test |
| `resetIterator()` / `hasNext()` / `getNext()` | Manual sequential iteration |
| Standard `begin/end/cbegin/cend` | Range-based iteration |

---

### 6. Element Enumeration – `Enumerater` (`enumerate.h/cpp`)

Walks the UI Automation tree to discover interactive elements and register them as `Clicker` entries.

| Method | Description |
|---|---|
| `EnumerateOpenWindows()` | Calls `EnumWindows`; for each window calls `InspectWindow2/3` |
| `EnumerateTaskBar()` | Specifically walks taskbar UIA elements |
| `InspectElementRecursive2/3(...)` | Recursive UIA tree walk; filters by interactability; calls `ElementClickersHelper::AddElementFromIteration` |
| `InspectTaskbarChildren(...)` | Taskbar-specific child enumeration |

`EnumWindowsData` carries the `IUIAutomation*` and `Enumerater*` across the `EnumWindows` callback boundary.

---

### 7. Element Clickers Helper – `ElementClickersHelper` (`clickers_helper.h/cpp`)

Bridges the UIA enumeration and the `Clickers` collection; handles label assignment and collision avoidance.

| Method | Description |
|---|---|
| `AddElementFromIteration(...)` | Calculates click/label coordinates; gets a label from `ElementLabels`; adds to `Clickers` via collision detection |
| `AddElementFromTaskbarIteration(...)` | Same for taskbar elements |
| `getClickers()` | Returns a copy of the current clickers |
| `SanitizeStringForLogging(...)` | Strips non-printable characters for safe log output |

---

### 8. Element Labels – `ElementLabels` (`element_labels.h/cpp`)

Static class managing pools of keyboard label strings for windows, elements, and taskbar items.

| Method | Description |
|---|---|
| `getNextWindowLabel()` | Pop next available window label |
| `getNextElementLabel(HWND)` | Pop next available element label for a given window |
| `getNextTaskbarLabel()` | Pop next available taskbar label |
| `returnWindowLabel(label)` | Return a label to the pool |
| `returnElementLabel(HWND, label)` | Return a per-window element label |
| `returnTaskbarLabel(label)` | Return a taskbar label |
| `reset()` | Reinitialize all label queues |
| `clearElementLabelsForHwnd(HWND)` | Free all labels for a closed window |

---

### 9. Collision Detector – `CollisionDetector` (`collision_detector.h/cpp`)

Spatial index that prevents label overlap on-screen.  Uses a 2D grid of buckets (each bucket is an `unordered_set<Point>`).

| Method | Description |
|---|---|
| `addPoint(x, y)` | Returns `true` if point does not collide; inserts it |
| `findClosestPoint(x, y)` | Nearest occupied point (for diagnostics) |
| `removePoint(x, y)` | Remove a registered point |
| `clear()` | Reset all buckets |
| `getCount()` | Number of registered points |

`Point` — simple `{long x, long y}` with equality and `std::hash` specialization.

---

### 10. Mouse – `Mouse` (`mouse.h`)

Static class that synthesizes mouse click events.

**Key design:** before sending input it temporarily sets the overlay window's `WS_EX_TRANSPARENT` extended style so the click passes through to the underlying application, then restores normal style afterward.

| Method | Description |
|---|---|
| `ClickMouse<Windler>(x, y, clickType, clickRepetition)` | Template function; `Windler` defaults to `Mouse` itself but can be substituted in tests.  Translates `ClickType × ClickRepetition` to `INPUT[]` arrays and calls `SendInput`. |
| `MouseSendInput` / `MouseSendInputSafe` | Wrappers over `SendInput` / `SetCursorPos` / `GetWindowLongPtr` / `SetWindowLongPtr` — separated so they can be mocked in tests |

---

### 11. Keyboard Hook Service – `KeyboardHookService` (`keyboard_hook_service.h/cpp`)

Singleton that installs a low-level (`WH_KEYBOARD_LL`) Windows keyboard hook and routes messages.

| Method | Description |
|---|---|
| `Instance()` | Meyer's singleton accessor |
| `Start(HWND)` | Install the hook; sets the target window |
| `Stop()` | Unhook, synchronize system keyboard state |
| `IsActive()` / `GetState()` | Hook lifecycle queries |
| `SetMessageCallback(fn)` | Register a `void(KeyboardMessage const&)` callback |
| `AddPassthroughKey(vk)` | Keys that are never suppressed |
| `IsShiftPressed()` / `IsCtrlPressed()` / `IsAltPressed()` / `IsWinPressed()` | Modifier state queries |
| `ForceEmergencyCleanup()` | Last-resort cleanup for abnormal termination |
| `ResetSystemKeyboardState()` | Synthesizes key-up events for stuck keys |

**`KeyboardMessage`** — carries `wParam`, `lParam`, `message`, and `suppress` flag.

---

### 12. Multiple Press Detector – `MultiplePressDetector` (`multiple_press_detector.h/cpp`)

Detects single, double, triple, and quadruple key presses within a configurable interval.

| Method | Description |
|---|---|
| `Check(clickType, messageTime, x, y)` | Feed a press event; returns `PressDetectorReturn` when a complete sequence is recognized |
| `CheckTimeout(currentTime)` | Call periodically; fires if the interval has elapsed without a second press |
| `Reset()` | Clear state |
| `SetInterval(ms)` | Configure the multi-press detection window |

**`PressDetectorReturn`** — `{clickType, repetition, x, y, ready}` — `ready` is `true` when a decision has been made.

---

### 13. Focus Context Tracker – `FocusContextTracker`, `FocusChangeHandler`, `FocusEventManager`

Monitors UI Automation focus events to track when the user enters menus, dialogs, or dropdowns.  
*(Currently wired up but not activated in the main message loop.)*

**`FocusContextTracker`** (`focus_context_tracker.h/cpp`)

| Item | Description |
|---|---|
| `OnFocusChanged(element)` | Main entry: classifies the new focused element and manages the context stack |
| `contextStack` | Stack of `Context` (type, targetId, pid, parentIndex) |
| `EmitEvent(...)` | Override in subclasses to act on open/close context events |
| `PushContext / PopContext` | Stack management |
| `Post(HWND, ...)` | Overridable Win32 `PostMessage` for testability |
| Debounce logic | `IsDuplicateEvent` suppresses rapid identical events within `DEBOUNCE_MS` |
| `IsMenuControl / IsDialogControl / IsDropdownControl / IsCustomControl` | Control-type classifiers |

**States:** `FCTUnknown`, `MenuState`, `DialogState`, `DropdownState`, `CustomControlState`

**`FocusChangeHandler`** (`focus_change_handler.h/cpp`) — COM object implementing `IUIAutomationFocusChangedEventHandler`. Forwards events to a `FocusContextTracker`.

**`FocusEventManager`** (`focus_change_manager.h/cpp`) — RAII wrapper: `Start()` creates the handler and registers it with `IUIAutomation`; `Stop()` unregisters.

---

### 14. Window Processing – `ProcessedWindow`, `ProcessedWindows`

Track windows that have been enumerated and assigned labels.

**`ProcessedWindow`** — stores `hwnd`, `hMonitor`, `zIndex`, `visibleRegion` (HRGN), `title`, `windowLabel`.

**`ProcessedWindows`** — `unordered_map<HWND, ProcessedWindow>` wrapper with `addWindow`, `findWindow`, `removeWindow`, `clear`, `isPointInRegion`.

---

### 15. Window / Element Tests

**`WindowsTests`** (`window_tests.h/cpp`) — per-instance tests on HWNDs.

| Method | Description |
|---|---|
| `IsWindowInteractable(hwnd)` | Master interactability gate |
| `IsMinimized / IsMaximized / IsWindowOnTop` | Geometry/state queries |
| `IsWindowCloaked / IsToolWindow / IsChildWindow` | Style/attribute queries |
| `IsSystemOrSpecialWindow / IsSystemProcessWindow` | Process-ownership checks (filters out system processes) |
| `IsMouseWindow(hwnd)` | Detects the application's own overlay windows |
| `ProcessWindow(hwnd)` | Full pipeline that builds visible HRGN for a window |
| `iterateAllWindows / iterateAllWindows2` | Debug/diagnostic enumeration helpers |

**`element_tests.h/cpp`** — free functions testing `IUIAutomationElement` interactability.

| Function | Description |
|---|---|
| `IsElementInteractable(pElement)` | Original heuristic |
| `IsElementInteractableNew / New2 / NewCache` | Revised heuristics (development variants) |
| `PrintElementTestStats()` | Dump stats when `ELEMENT_TEST_STATS` is defined |

---

### 16. CashMan – `CashMan` (`cash_man.h/cpp`)

A type-safe key-value store using `std::variant<int, float, bool, std::wstring>` as the value type.

Used in two ways:
- `Globals::parameters` — all YAML config values flattened to `wstring` keys
- `Globals::cashMan` — runtime application data

| Method | Description |
|---|---|
| `insert / insert_or_assign / emplace / try_emplace` | Insertion variants (mirror `std::unordered_map`) |
| `at(key)` / `get(key)` | Value retrieval (throws if missing) |
| `getInt / getFloat / getBool / getWString` | Type-specific extractors |
| `contains / find / erase / clear` | Membership and mutation |
| `enunciate(key)` | Returns a human-readable string representation of the stored value |
| `GetKey<T>(category, pointer)` | Generates a composite key from a category prefix and a pointer address |

---

### 17. Yamler – `Yamler` (`yamler.h/cpp`)

Reads and writes the YAML configuration file (`mousefree.yaml`) using **yaml-cpp** (via vcpkg).

- `loadFromFile(filename)` — parses the file; flattens nested YAML keys (e.g., `grid.linecolor`) into `CashMan` entries.
- `saveToFile(filename)` — rebuilds a nested YAML document from the flattened `CashMan` state and writes it to disk.

Config is stored under `%LOCALAPPDATA%` or beside the executable.

> Which config?

---

### 18. Configuration UI – `ConfigMetadata` (`config_metadata.h/cpp`)

Defines and manages the configuration dialog dynamically at runtime.

| Item | Description |
|---|---|
| `ControlMetadata` | Describes one control: key, display name, `ControlType`, options, default, group, modifier |
| `ConfigMetadata()` | Constructor populates the metadata map with all configurable settings |
| `CreateConfig / CreateHelp / CreateAbout` | Dynamically create Win32 controls in the respective dialogs |
| `HandleCommand(wParam, lParam)` | Routes `WM_COMMAND` from the dialogs |
| `GetControlValue / SetControlValue` | Read/write individual control values |
| `UpdateDefaults()` | Push default values into `Globals::parameters` |
| `SaveAllValues()` | Read all dialog controls back into `Globals::parameters` and call `Yamler::saveToFile` |
| `ReloadDefaults()` | Reset all controls to defaults |
| `GetValue<T>(key)` | Template getter for typed value extraction |

**`ControlType` enum:** `COMMENT`, `STATIC`, `EDIT_TEXT`, `EDIT_INT`, `EDIT_FLOAT`, `COMBOBOX`, `CHECKBOX`, `RADIO_GROUP`, `GROUP_BOX`, `HOTKEY`, `RICHEDIT`

---

### 19. Logger – `Logger` (`logger.h/cpp`)

Static, file- or console-based structured logger with source-location support (C++20).

**Log levels:** `Debug`, `Info`, `Warning`, `Error`, `Off`

| Method category | Description |
|---|---|
| `InitializeLogger / CloseLogger` | Lifecycle |
| `PurgeOldLogs(keepCount)` | Delete old log files from `%LOCALAPPDATA%`, keeping the most recent N |
| `Info / Debug / Warning / Error` | Heavily overloaded shorthand methods accepting `wstring`, `wchar_t*`, and numeric types |
| `LogString` | Lower-level overloaded log method |
| `LogAndSystemError / LogAndRuntimeError / LogAndInvalidArgumentError / LogAndOutOfRangeError` | Log then throw a corresponding C++ exception |
| `LogMessage(level, MSG)` | Logs a Win32 `MSG` struct |
| `LogUserMonitor(level, UserMonitor)` | Logs monitor information |
| `LogUIAutomationElement(...)` | Logs a `LoggedUIAutomationElement` or raw `IUIAutomationElement*` |
| `LogTrackerElement(...)` | Logs a `FocusContextTrackerElement` |
| `LogEventSequence(...)` | Logs a sequence of focus events |

**`logger_macros.h`** — provides `LOGGER_*` macros that map to `Logger::*` in production and to `MockLogger::*` in unit tests (controlled by the `_UNITTEST` preprocessor symbol).

**`logger_elements.h`** — structured data types used by the Logger:
- `LoggedUIAutomationElement` — captures all relevant UIA element properties for logging and replay.
- `LoggedFocusContextTrackerElement` — wraps a focus tracker element with test-scenario metadata.
- `LoggedEventSequence` — an ordered list of focus events for replay testing.

---

### 20. Lines – `Lines` (`lines.h`)

Header-only template class that draws the grid overlay lines.

- `drawLines<Drawer>(hdc, grid)` — iterates grid divisions and calls `Drawer::drawLine` for each vertical and horizontal line.  The `Drawer` template parameter allows the drawing primitive to be substituted in tests.

---

### 21. UserSystem / UserMonitor – `user_system.h/cpp`, `user_monitor.h/cpp`

**`UserSystem`** — top-level multi-monitor coordinator.
- Calls `EnumDisplayMonitors` → creates one `UserMonitor` per physical display.
- Provides `GetVirtualDesktopBounds / Dimensions / Width / Height` static helpers.

**`UserMonitor`** — owns all per-monitor resources.

| Member | Description |
|---|---|
| `hMonitor`, `mi`, `dd`, `dpiX/Y` | Win32 monitor identity and info |
| `topAppWindow / bottomAppWindow` | `optional<TopAppWindow/BottomAppWindow>` |
| `gridClickers` | `Clickers` for the grid key-cell mapping |
| `grid` | `Grid` instance |
| `wndProcData` | `WndProcData` passed to both WndProcs |
| `GetTopAppWindow() / GetBottomAppWindow()` | Accessors |

Private helpers compute usable screen dimensions, aspect ratio, and min/max coordinates from `MONITORINFOEX`.

---

### 22. Utility Functions – `utils.h/cpp`

Free functions for conversions, diagnostics, and lookup.

| Function | Description |
|---|---|
| `DecodeControlType / DecodeWMMessageType` | UIA control-type / Win32 message integer → `wstring` |
| `GetElementRuntimeId(pElement)` | Returns the `unsigned long long` UIA runtime ID |
| `ConvertViewTypeStringtoViewType / ConvertGridTypeStringtoGridType` | String → enum |
| `IsFontValid / IsValidViewType / IsValidGridType` | Validation helpers |
| `IntToViewType / IntToGridType` | Enum casting from int |
| `AwarenessToString / CheckProcessApiAwareness` | DPI awareness diagnostics |
| `LoadAcceleratorTable / RegisterHotKeys` | Load keyboard accelerators from config |
| `wstring_to_utf8 / utf8_to_wstring` | Encoding conversions |
| `containsIgnoreCase` | Case-insensitive substring search |
| `operator<<` overloads | Stream output for `GridType`, `ViewType`, `MonitorOrientation`, `ClickType`, `ClickRepetition` |

Also defines compile-time lookup tables: `colors`, `colorMap`, `lineStyles`, `lineStyleMap`, `textWeights`, `textWeightMap`, and `windowsMessageMap`.

---

### 23. Reentrancy Guard – `ReentrancyGuard` (`reentrancy_guard.h/cpp`)

RAII guard using `thread_local bool` to prevent nested entry into the message handler.

- Constructor throws if already in the handler.
- Destructor clears the flag.
- `IsInMessageHandler()` — static predicate.

---

### 24. UIA Constants – `uia_constants.h`

Defines or documents Windows UI Automation control-type and property ID constants used across the library.

---

### 25. Tests – `MouseFreeTests/`

Google Test–based test suite.

| File | What it tests |
|---|---|
| `CashManTests.cpp` | `CashMan` insert/get/erase/type extraction |
| `ClickerTests.cpp` | `Clicker` construction and getters |
| `ClickersTests.cpp` | `Clickers` map operations and iteration |
| `CollisionDetectorTests.cpp` | Spatial indexing, collision, and removal |
| `ElementLabelsTests.cpp` | Label queue management |
| `FocusChangeHandlerTests.cpp` | `FocusChangeHandler` COM behavior |
| `FocusContextTrackerTests.cpp` | Context stack, open/close events, debounce |
| `GlobalsTests.cpp` | Monitor increment/decrement helpers |
| `GridTests.cpp` | Grid navigation, nudge, boundary checks |
| `LinesTests.cpp` | Grid line drawing with a mock drawer |
| `MouseTests.cpp` | `Mouse::ClickMouse` with mock Win32 calls |
| `MultiplePressDetectorTests.cpp` | Single/double/triple/quad press detection |
| `UtilsTest.cpp` | String conversion, enum helpers |
| `ReplayFocusChangeEvents.cpp` | Replays logged `LoggedEventSequence` data |
| `MouseFreeTests2.cpp` | Integration-style tests |

**Test infrastructure:**

| File | Description |
|---|---|
| `StubUIAutomationElement.h/cpp` | Full `IUIAutomationElement9` stub — all methods return `E_NOTIMPL` by default; individual tests set properties via public fields |
| `mocklogger.h/cpp` | Drop-in `MockLogger` that captures log calls during tests |
| `TestHelpers.h` | Shared helper utilities |
| `GlobalTestSetup.cpp` | Google Test global fixture setup |

Tests compile with `_UNITTEST` defined, which activates `friend` declarations in production classes and routes all `LOGGER_*` macros to `MockLogger`.

---

## Configuration Files

| File | Description |
|---|---|
| `MouseFree/mousefree.yaml` | Live config (auto-updated by the config dialog; user should not edit directly) |
| `MouseFree/defaults.yaml` | Default values shipped with the application |

Key config areas: accelerator keys, view type, grid type, active monitor, multi-press interval, grid and element display styling (color, font, line style), and per-grid-type key mappings.

---

## Key Data Flows

### Grid Mode — Keyboard → Click

```
KeyboardHookService (WH_KEYBOARD_LL hook)
  → PostMessage to overlay HWND
    → WndProc (window_helpers.cpp)
      → EnumDisplayMonitors → EnumProcessNavigateGrid
        → Grid::navigateGrid / Grid::reset
          → InvalidateRect (repaint overlay)
            → WM_PAINT → paintGridWindow → Lines::drawLines + addLabelsOnScreen

[User presses Enter / click key]
  → WndProc detects click key
    → MultiplePressDetector::Check → PressDetectorReturn
      → Mouse::ClickMouse(x, y, clickType, repetition)
```

### Element View — Enumeration → Click

```
[Application refresh triggered]
  → Enumerater::EnumerateOpenWindows()
    → EnumWindows → InspectWindow3
      → InspectElementRecursive3 (UIA tree walk)
        → IsElementInteractableNew (filter)
          → ElementClickersHelper::AddElementFromIteration
            → ElementLabels::getNextElementLabel → assigns label
            → CollisionDetector::addPoint → checks overlap
            → Clickers::add(Clicker)
  → Globals::elementClickers populated

[User types label]
  → WndProc looks up label in Globals::elementClickers
    → Mouse::ClickMouse(clickX, clickY, ...)
```

### Config Persistence

```
Startup: Yamler::loadFromFile("mousefree.yaml") → CashMan (Globals::parameters)
Config dialog close: ConfigMetadata::SaveAllValues() → Yamler::saveToFile(...)
```
