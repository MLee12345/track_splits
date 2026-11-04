# Product Requirement Document (PRD): TrackSplits

**Version:** 1.0

**Target Platform:** iOS 16.0+ (iPhone)

**Status:** Ready for Development

---

## 1. Executive Summary & Vision

**TrackSplits** is a zero-friction, single-screen multi-stopwatch app designed specifically for track, cross-country, and swim coaches. It replaces bulky physical stopwatches and complex apps with a clean, disposable interface that allows coaches to time multiple individual runners simultaneously in real time.

* **Core Value Proposition:** Open the app, name your runners, and time them instantly. No setup wizards, no menus, and no saved data cluttering the screen after track practice ends.

---

## 2. Product Principles

1. **Disposable by Design:** Practice data is ephemeral. There are no history logs, saved sessions, or cloud backups.
2. **Instant & Unobstructed:** Zero screen transitions. Every control is accessible on the main view.
3. **Tactile & Sunlight Optimized:** Touch targets are large and high-contrast, designed for reliable thumb taps outdoors while holding a clipboard or walking along the track.

---

## 3. Functional Requirements

### FR-01: Dynamic Runner Card List

* **Description:** A single-column, vertically scrollable list displaying timing cards for each runner.
* **Behavior:**
* App opens with 4 default runner cards.
* A persistent floating `+` button at the bottom right adds a new runner card to the end of the list.
* Swiping left on a card or tapping a compact `X` icon removes the card.



### FR-02: Inline Runner Naming

* **Description:** An inline text field on each card to identify athletes.
* **Behavior:**
* Defaults automatically to sequential labels ("Runner 1", "Runner 2", "Runner 3", etc.).
* Tapping the text opens the keyboard for instant inline editing.
* Tapping "Done" or outside the text field commits the name change.



### FR-03: Combined Start/Stop Controls

* **Description:** A single, prominent toggle button dedicated to each runner card.
* **Behavior:**
* **Stopped State:** Displays a green **Start** label. Tapping begins the stopwatch timer for that specific runner.
* **Running State:** Displays a red **Stop** label. Tapping pauses the stopwatch for that specific runner.
* Operates completely independently of all other runner cards on screen.



### FR-04: Independent Reset

* **Description:** A dedicated reset button for each runner card.
* **Behavior:**
* Resets the card’s live timer back to `00:00.00`.
* Can be tapped while the timer is running (resets to zero and keeps running) or while stopped (resets to zero and stays stopped).



### FR-05: High-Precision Display

* **Description:** Standard high-precision athletic timer display (`MM:SS.ss`).
* **Behavior:**
* Displays minutes, seconds, and hundredths of a second.
* Utilizes monospaced/tabular figures (`.monospacedDigit()`) so text does not jitter horizontally as digits change.



---

## 4. UI/UX Specifications

### Card Layout Architecture

Each runner card consists of a horizontal row structured as follows:

```
+---------------------------------------------------------------+
| [ Runner Name ]   00:12.45    [  START  ]  [ ↺ ]  [ X ]       |
+---------------------------------------------------------------+

```

* **Left Section:** Editable text label (Runner Name).
* **Center Section:** Large monospaced live stopwatch readout.
* **Right Section:**
* **Primary Action:** Large **Start/Stop** toggle button (Minimum touch target: 50x50 pt).
* **Secondary Actions:** Compact **Reset** icon button and **Delete Card** button.



### Visual States & Palette

* **Default / Stopped:** Neutral dark card background with high-contrast text. Start button highlighted in vibrant Green.
* **Active / Running:** Card background receives a subtle accent border. Stop button highlighted in high-visibility Red. Display readout pulses slightly or changes color (e.g., bright white/yellow) to signal active timing.
* **Dark Mode:** Native high-contrast dark theme by default to optimize outdoor sunlight readability and reduce battery burn during long track meets.

---

## 5. Technical Requirements

### Architecture & Frameworks

* **Language/Framework:** Native Swift using SwiftUI.
* **Minimum iOS Target:** iOS 16.0+
* **Device Focus:** iPhone Portrait view optimized for single-handed use.

### Timing Precision & Performance

* **Timing Engine:** Timers must **not** rely on standard repeating `Timer` publishers, which drift when UI rendering stalls. Instead, compute elapsed time using system time deltas (`Date()` differential calculated per frame via `TimelineView` or `CADisplayLink`).
* **UI Performance:** Continuous 60 FPS scrolling and rendering performance with up to 20 active timers simultaneously ticking.

### State & Persistence

* **State Scope:** All data is kept strictly in-memory (`@State` / `@StateObject`).
* **Data Persistence:** None. Terminating or restarting the app resets the workspace cleanly back to default state.

---

## 6. Out of Scope (Explicit Non-Goals)

* Global / Master controls ("Start All" or "Stop All").
* Lap split capture or intermediate lap time logging.
* Data export (CSV, text export, Share Sheet).
* Session saving, history tabs, or database integration.
* Cloud sync, user accounts, or iPad multi-column layouts.
