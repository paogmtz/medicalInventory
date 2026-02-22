# UX Specification -- MedCabinet

**Agent:** D3 -- UX Spec Writer
**Date:** 2026-02-21
**Status:** Complete
**App Name:** MedCabinet (working title)

---

## Table of Contents

1. [Design System](#1-design-system)
2. [Navigation Structure](#2-navigation-structure)
3. [Screen Specifications](#3-screen-specifications)
4. [Interaction Patterns](#4-interaction-patterns)
5. [Accessibility Specifications](#5-accessibility-specifications)
6. [Empty States](#6-empty-states)
7. [Loading States](#7-loading-states)
8. [Error States](#8-error-states)
9. [Animations](#9-animations)
10. [Educational Micro-copy](#10-educational-micro-copy)

---

## 1. Design System

### 1.1 Color Palette

The app uses semantic system colors as a foundation to guarantee accessibility across light mode, dark mode, and high-contrast settings. Two custom accent colors provide brand identity without breaking platform conventions.

#### System Colors (Primary Use)

| Role | SwiftUI Token | Light Mode | Dark Mode | Usage |
|------|---------------|------------|-----------|-------|
| Primary text | `.primary` | Black | White | Headlines, body text |
| Secondary text | `.secondary` | Gray | Light gray | Subtitles, metadata, timestamps |
| Background | `Color(.systemBackground)` | White | Near-black | Screen backgrounds |
| Grouped background | `Color(.systemGroupedBackground)` | Light gray | Dark gray | Settings, grouped lists |
| Card surface | `Color(.secondarySystemGroupedBackground)` | White | Elevated dark | Card backgrounds |
| Separator | `Color(.separator)` | Light gray | Dark gray | Dividers between list items |

#### Custom Accent Colors

| Name | Hex (Light) | Hex (Dark) | SwiftUI Definition | Usage |
|------|-------------|------------|-------------------|-------|
| **Teal Accent** | `#2AA5A0` | `#3CC7C2` | `Color("AccentTeal")` in asset catalog | Primary accent: buttons, tab highlights, navigation tint |
| **Teal Light** | `#E6F5F4` | `#1A3A39` | `Color("AccentTealLight")` in asset catalog | Subtle teal backgrounds for selected states, chip backgrounds |

#### Status Colors

Status colors use system semantic colors to ensure Dark Mode and High Contrast compatibility. Each status is **never** conveyed by color alone -- always paired with an icon and text label.

| Status | Color Token | Light Mode | Dark Mode | SF Symbol | Text Label |
|--------|-------------|------------|-----------|-----------|------------|
| **Expired** | `Color(.systemRed)` | `#FF3B30` | `#FF453A` | `exclamationmark.triangle.fill` | "Expired" |
| **Expiring Soon** | `Color(.systemOrange)` | `#FF9500` | `#FF9F0A` | `clock.badge.exclamationmark` | "Expiring Soon" |
| **Low Stock** | `Color(.systemBlue)` | `#007AFF` | `#0A84FF` | `arrow.down.circle.fill` | "Low Stock" |
| **OK / Good** | `Color(.systemGreen)` | `#34C759` | `#30D158` | `checkmark.circle.fill` | "Good" |

#### Status Color Application

```
Status Badge:   [Icon] + [Label] on tinted background
                e.g., rounded rect with systemRed.opacity(0.15) background,
                systemRed icon and text

Status Chip:    Compact pill shape, same color scheme as badge
                Used in Today Dashboard alert area
```

### 1.2 Typography Scale

All text uses the system font (SF Pro / SF Pro Rounded) and **must** support Dynamic Type. No hardcoded font sizes. Every text element uses a `Font.TextStyle` so that the system can scale it according to the user's accessibility preferences.

| Style | SwiftUI Token | Default Size | Weight | Usage |
|-------|---------------|-------------|--------|-------|
| Large Title | `.largeTitle` | 34pt | Bold | Screen titles (Today, Medications) |
| Title | `.title` | 28pt | Bold | Section headers |
| Title 2 | `.title2` | 22pt | Bold | Card titles, medication names |
| Title 3 | `.title3` | 20pt | Semibold | Sub-section headers |
| Headline | `.headline` | 17pt | Semibold | Dose card medicine name |
| Body | `.body` | 17pt | Regular | Primary content text |
| Callout | `.callout` | 16pt | Regular | Supporting descriptive text |
| Subheadline | `.subheadline` | 15pt | Regular | Metadata, secondary info |
| Footnote | `.footnote` | 13pt | Regular | Timestamps, helper text |
| Caption | `.caption` | 12pt | Regular | Badge labels, status text |
| Caption 2 | `.caption2` | 11pt | Regular | Fine print, disclaimers |

**Implementation rule:** Never use `Font.system(size:)` for content text. Always use `Font.textStyle`. The only exception is decorative or fixed-layout elements (e.g., a large numeric counter), which must still be tested at the largest Dynamic Type size.

### 1.3 Spacing and Layout Grid

The app uses an 8-point spacing grid to ensure consistent rhythm across all screens.

| Token | Value | Usage |
|-------|-------|-------|
| `spacing-xs` | 4pt | Inline icon-to-text gap |
| `spacing-sm` | 8pt | Tight padding inside badges, between related items |
| `spacing-md` | 12pt | Intra-card padding |
| `spacing-base` | 16pt | Standard screen horizontal padding, inter-card spacing |
| `spacing-lg` | 20pt | Section spacing |
| `spacing-xl` | 24pt | Major section breaks |
| `spacing-2xl` | 32pt | Screen top/bottom safe padding |

**Layout constraints:**
- Screen horizontal padding: 16pt (`.padding(.horizontal, 16)`)
- Card corner radius: 12pt
- Card internal padding: 12pt
- Card shadow: `shadow(color: .black.opacity(0.06), radius: 8, y: 2)` (light mode only)
- Minimum interactive target: 44x44pt
- Card-to-card vertical spacing: 12pt
- Section-to-section vertical spacing: 24pt

### 1.4 SF Symbols Reference

All icons in the app use SF Symbols. No custom image assets are used for icons. This keeps the ZIP size minimal and ensures automatic support for Dynamic Type scaling, weight matching, and accessibility.

#### Navigation & Tab Bar

| Context | Symbol Name | Rendering | Notes |
|---------|-------------|-----------|-------|
| Today tab | `heart.text.clipboard` | Multicolor | Active tab uses accent teal tint |
| Medications tab | `pills.fill` | Monochrome | -- |
| Settings tab | `gearshape.fill` | Monochrome | -- |
| Back button | `chevron.left` | Monochrome | System default |
| Add button | `plus.circle.fill` | Hierarchical | Toolbar or floating |

#### Status Icons

| Context | Symbol Name | Rendering |
|---------|-------------|-----------|
| Expired | `exclamationmark.triangle.fill` | Palette (red) |
| Expiring soon | `clock.badge.exclamationmark` | Palette (orange) |
| Low stock | `arrow.down.circle.fill` | Palette (blue) |
| OK / good | `checkmark.circle.fill` | Palette (green) |

#### Medication Form Icons

| Form | Symbol Name |
|------|-------------|
| Tablet / pill | `pills.fill` |
| Capsule | `capsule.fill` |
| Liquid / syrup | `drop.fill` |
| Injection | `syringe.fill` |
| Cream / topical | `hand.raised.fill` |
| Inhaler | `wind` |
| Drops (eye/ear) | `eye.dropper.fill` |
| Patch | `bandage.fill` |
| Other / unknown | `cross.vial.fill` |

#### Action & Utility Icons

| Context | Symbol Name |
|---------|-------------|
| Taken (dose) | `checkmark.circle.fill` |
| Skip (dose) | `forward.fill` |
| Camera capture | `camera.fill` |
| Photo library | `photo.on.rectangle.angled` |
| Demo image | `photo.artframe` |
| Edit | `pencil` |
| Delete | `trash.fill` |
| Info / tooltip | `info.circle` |
| Search | `magnifyingglass` |
| Calendar | `calendar` |
| Clock / schedule | `clock.fill` |
| Quantity / count | `number.circle` |
| Scan text (OCR) | `doc.text.viewfinder` |
| Load demo data | `tray.and.arrow.down.fill` |
| Warning / disclaimer | `exclamationmark.shield.fill` |
| Privacy | `hand.raised.square.fill` |
| Confidence high | `checkmark.seal.fill` |
| Confidence low | `questionmark.diamond` |

---

## 2. Navigation Structure

### 2.1 Tab Bar (Root Navigation)

The app uses a `TabView` with three tabs. The tab bar is always visible at the root level of each tab.

```
+-----------------------------------------------+
|                                                 |
|              [Current Screen]                   |
|                                                 |
+---------+-----------+-----------+---------------+
|  heart  |   pills   |   gear    |               |
|  Today  |   Meds    |  Settings |               |
+---------+-----------+-----------+---------------+
```

| Tab | Label | SF Symbol | Badge |
|-----|-------|-----------|-------|
| 1 | Today | `heart.text.clipboard` | Red dot if expired items exist |
| 2 | Meds | `pills.fill` | Count of alert items (expired + expiring soon) |
| 3 | Settings | `gearshape.fill` | None |

**SwiftUI implementation pattern:**

```swift
TabView {
    TodayView()
        .tabItem {
            Label("Today", systemImage: "heart.text.clipboard")
        }
        .badge(expiredCount > 0 ? "!" : nil)

    MedicationsView()
        .tabItem {
            Label("Meds", systemImage: "pills.fill")
        }
        .badge(alertCount)

    SettingsView()
        .tabItem {
            Label("Settings", systemImage: "gearshape.fill")
        }
}
.tint(Color("AccentTeal"))
```

### 2.2 Navigation Stack (Drill-Down)

Each tab wraps its content in a `NavigationStack` for drill-down navigation:

```
Today (tab) ──> Medication Detail
Meds (tab)  ──> Medication Detail
                  ├──> Edit Medication (sheet)
                  └──> Dose Log (inline or sheet)
```

### 2.3 Sheet Presentations

Sheets are used for creation and editing flows. They slide up from the bottom and can be dismissed by swiping down or tapping a cancel/done button.

| Sheet | Trigger | Detents | Dismissal |
|-------|---------|---------|-----------|
| Add Medication (Scan Flow) | "+" button in Meds tab | `.large` | Cancel button or Save |
| Edit Medication | Edit button in Detail view | `.large` | Cancel or Save |
| Expiry Warning Explanation | Info button on status badge | `.medium` | Swipe down |
| Delete Confirmation | Delete button | `.height(200)` via `confirmationDialog` | Cancel or Confirm |

### 2.4 Full Navigation Map

```
TabView
├── Tab 1: Today
│   └── NavigationStack
│       ├── TodayDashboardView (root)
│       │   ├── [tap dose card] ──> MedicationDetailView (push)
│       │   └── [tap alert chip] ──> MedicationDetailView (push)
│       └── MedicationDetailView
│           ├── [tap Edit] ──> EditMedicationSheet (sheet, .large)
│           └── [tap Delete] ──> ConfirmationDialog
│
├── Tab 2: Meds
│   └── NavigationStack
│       ├── MedicationsListView (root)
│       │   ├── [tap card] ──> MedicationDetailView (push)
│       │   └── [tap "+"] ──> AddMedicationSheet (sheet, .large)
│       ├── MedicationDetailView (pushed)
│       └── AddMedicationSheet
│           ├── Step 1: CaptureView (photo/camera/demo)
│           ├── Step 2: OCRProcessingView (loading)
│           └── Step 3: ReviewEditView (form)
│
└── Tab 3: Settings
    └── NavigationStack
        └── SettingsView (root, grouped form)
```

---

## 3. Screen Specifications

### 3.A. Today Dashboard

**Purpose:** Give the user an at-a-glance summary of their medication day -- what doses are due, and what needs attention (expired, expiring soon, low stock).

**Layout:** Vertical scroll view with three logical sections.

#### ASCII Wireframe

```
+--------------------------------------------------+
| Today                                  Feb 21 (i) |
| ------------------------------------------------- |
|                                                    |
| [!] ALERTS (if any)                                |
| +----------+ +---------------+ +-----------+       |
| | Expired  | | Expiring Soon | | Low Stock |       |
| |    2     | |      3        | |     1     |       |
| +----------+ +---------------+ +-----------+       |
|                                                    |
| MORNING                            8:00 AM         |
| +------------------------------------------------+ |
| | pills.fill  Ibuprofen 200mg                    | |
| |             1 tablet                           | |
| |                         [Skip]  [Taken]        | |
| +------------------------------------------------+ |
| +------------------------------------------------+ |
| | capsule.fill  Amoxicillin 500mg                | |
| |               1 capsule                        | |
| |                         [Skip]  [Taken]        | |
| +------------------------------------------------+ |
|                                                    |
| AFTERNOON                          2:00 PM         |
| +------------------------------------------------+ |
| | pills.fill  Ibuprofen 200mg                    | |
| |             1 tablet                           | |
| |                         [Skip]  [Taken]        | |
| +------------------------------------------------+ |
|                                                    |
| EVENING                            8:00 PM         |
| +------------------------------------------------+ |
| | capsule.fill  Amoxicillin 500mg                | |
| |               1 capsule                        | |
| |                         [Skip]  [Taken]        | |
| +------------------------------------------------+ |
|                                                    |
|  [tray.and.arrow.down.fill  Load Demo Data]        |
|                                                    |
+---------+-----------+-----------+------------------+
|  Today  |   Meds    |  Settings |                  |
+---------+-----------+-----------+------------------+
```

#### Section 1: Header

- Title: "Today" in `.largeTitle` bold, left-aligned
- Date subtitle: "Friday, February 21" in `.subheadline`, `.secondary` color
- Positioned via `NavigationStack` with `.navigationTitle("Today")`

#### Section 2: Alert Chips Area

A horizontally scrolling row of status chips. Each chip is a compact, tappable pill shape.

**Chip design:**

```
+-------------------------------------+
| [icon]  Label                  [N]  |
+-------------------------------------+

Background: statusColor.opacity(0.12)
Icon + text: statusColor
Corner radius: 20pt (capsule)
Height: 36pt
Horizontal padding: 12pt
```

| Chip | Icon | Label | Action |
|------|------|-------|--------|
| Expired | `exclamationmark.triangle.fill` | "Expired" | Navigates to filtered meds list |
| Expiring Soon | `clock.badge.exclamationmark` | "Expiring Soon" | Navigates to filtered meds list |
| Low Stock | `arrow.down.circle.fill` | "Low Stock" | Navigates to filtered meds list |

- If there are zero alerts, this section is hidden entirely (not an empty row).
- Chips show the count of affected medications as a trailing badge number.

#### Section 3: Dose List

Doses are grouped by time-of-day sections: Morning, Afternoon, Evening, Night. Each section header shows the time slot label and the scheduled time.

**Dose card design:**

```
+--------------------------------------------------+
| [form icon]   Medicine Name            [status]   |
|               Dose amount (e.g., "1 tablet")      |
|               Scheduled: 8:00 AM                  |
|                                                   |
|              [forward.fill Skip]  [checkmark Taken]|
+--------------------------------------------------+

Card background: secondarySystemGroupedBackground
Corner radius: 12pt
Padding: 12pt
Shadow: subtle (0.06 opacity, 8pt radius)
```

| Element | Font | Color |
|---------|------|-------|
| Medicine name | `.headline` | `.primary` |
| Dose amount | `.subheadline` | `.secondary` |
| Schedule time | `.footnote` | `.secondary` |
| Skip button | `.subheadline` | `.secondary` |
| Taken button | `.subheadline` | `AccentTeal` (filled style) |

**Button styles:**
- **Skip:** Bordered, secondary color. Icon `forward.fill` + "Skip".
- **Taken:** Bordered prominent, accent teal. Icon `checkmark` + "Taken".
- Both buttons are minimum 44x44pt touch targets.

**Completed dose card:** When a dose is marked "Taken," the card dims (opacity 0.5), the Taken button changes to a filled green checkmark, and the text shows a strikethrough. The card moves to the bottom of its time section.

**Skipped dose card:** Similar to taken but uses `.secondary` color and the label changes to "Skipped."

#### Section 4: Load Demo Data Button

Placed at the bottom of the scroll view, below all dose sections. Only visible when the medication list is empty or when the app is in its initial state.

```
+--------------------------------------------------+
| [tray.and.arrow.down.fill]  Load Demo Data        |
+--------------------------------------------------+

Style: .bordered, .controlSize(.large)
Color: AccentTeal
Full-width within horizontal padding
```

When tapped, loads pre-populated sample medications and schedules so judges can immediately interact with a fully populated app.

---

### 3.B. Medications List

**Purpose:** Display all medications the user is tracking, with visual status indicators and quick access to add new ones.

#### ASCII Wireframe

```
+--------------------------------------------------+
| Medications                     [magnifyingglass]  |
| ------------------------------------------------- |
|                                                    |
| [Search field: "Search medications..."]            |
|                                                    |
| NEEDS ATTENTION (2)                                |
| +------------------------+ +----------------------+|
| | [photo/icon]           | | [photo/icon]         ||
| | Ibuprofen              | | Amoxicillin          ||
| | pills.fill  200mg      | | capsule.fill  500mg  ||
| | Qty: 5                 | | Qty: 12              ||
| | [!!! Expired]          | | [! Expiring Soon]    ||
| +------------------------+ +----------------------+|
|                                                    |
| ALL MEDICATIONS (6)                                |
| +------------------------+ +----------------------+|
| | [photo/icon]           | | [photo/icon]         ||
| | Acetaminophen          | | Loratadine           ||
| | pills.fill  500mg      | | pills.fill  10mg     ||
| | Qty: 24                | | Qty: 30              ||
| | [checkmark OK]         | | [checkmark OK]       ||
| +------------------------+ +----------------------+|
| +------------------------+ +----------------------+|
| | [photo/icon]           | | [photo/icon]         ||
| | Omeprazole             | | Cough Syrup          ||
| | capsule.fill 20mg      | | drop.fill  10ml      ||
| | Qty: 14                | | Qty: 1 bottle        ||
| | [checkmark OK]         | | [v Low Stock]        ||
| +------------------------+ +----------------------+|
|                                                    |
|                          [+ plus.circle.fill Add]  |
|                                                    |
+---------+-----------+-----------+------------------+
|  Today  |   Meds    |  Settings |                  |
+---------+-----------+-----------+------------------+
```

#### Layout: Adaptive Grid

Use `LazyVGrid` with adaptive columns:

```swift
let columns = [
    GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)
]
```

This produces a 2-column grid on iPhone and adapts to wider layouts on iPad.

#### Medication Card Component

```
+---------------------------+
| +---------------------+   |
| |                     |   |
| |   [Photo or         |   |
| |    SF Symbol         |   |
| |    placeholder]      |   |
| |                     |   |
| +---------------------+   |
| Medicine Name              |
| [form icon] Dose           |
| Qty: [number]              |
| [status badge]             |
+---------------------------+

Card dimensions:
  Width: adaptive (minimum 160pt)
  Aspect ratio: roughly 3:4
  Corner radius: 12pt
  Padding: 12pt
  Background: secondarySystemGroupedBackground
```

| Element | Font | Color | Position |
|---------|------|-------|----------|
| Photo/thumbnail | -- | -- | Top, aspect-fill, clipped to rounded rect (8pt radius) |
| Medicine name | `.headline` | `.primary` | Below photo, left-aligned |
| Form icon + dose | `.subheadline` | `.secondary` | Below name |
| Quantity | `.footnote` | `.secondary` | Below dose |
| Status badge | `.caption` bold | Status color | Bottom, full-width pill |

**Status badge within card:**

```
+---------------------------------+
| [icon] Status Label             |
+---------------------------------+

Background: statusColor.opacity(0.12)
Text + Icon: statusColor
Corner radius: 8pt
Height: 24pt
Font: .caption, weight: .semibold
```

**No-photo fallback:** If the medication has no photo, display a large SF Symbol for the medication form (e.g., `pills.fill`) centered on a tinted background (`AccentTeal.opacity(0.1)`).

#### Sections

The list is divided into two sections:
1. **Needs Attention** -- Medications with expired, expiring soon, or low stock status. This section only appears when there are items in it.
2. **All Medications** -- Every medication, sorted alphabetically by default.

#### Sort / Filter

Accessible via a toolbar menu (`.toolbar` with `Menu`):

```swift
Menu {
    Picker("Sort", selection: $sortOption) {
        Label("Name", systemImage: "textformat").tag(SortOption.name)
        Label("Expiration Date", systemImage: "calendar").tag(SortOption.expiration)
        Label("Quantity", systemImage: "number.circle").tag(SortOption.quantity)
        Label("Status", systemImage: "exclamationmark.circle").tag(SortOption.status)
    }
} label: {
    Label("Sort", systemImage: "arrow.up.arrow.down.circle")
}
```

#### Add Button

A toolbar button in the top-right area:

```swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Button {
            showAddSheet = true
        } label: {
            Label("Add Medication", systemImage: "plus.circle.fill")
        }
    }
}
```

This opens the Add Medication sheet (Section 3.C).

#### Search

A `Searchable` modifier on the list filters medications by name in real time:

```swift
.searchable(text: $searchText, prompt: "Search medications...")
```

Filtering is case-insensitive and matches substrings of the medication name. If search yields no results, show a contextual empty state: "No medications matching '[query]'."

---

### 3.C. Add Medication (Scan Flow)

**Purpose:** Allow the user to add a new medication by photographing the box/label, having OCR extract the text, and then reviewing/editing the auto-filled fields.

**Presentation:** Full-height sheet (`.large` detent).

The flow is a multi-step process presented within a single sheet. Navigation between steps uses an internal state machine, not a NavigationStack push (to avoid nested navigation stacks).

#### Step 1: Photo Capture / Selection

```
+--------------------------------------------------+
| [X Cancel]    Add Medication           Step 1/3   |
| ------------------------------------------------- |
|                                                    |
|                                                    |
|         +----------------------------+             |
|         |                            |             |
|         |    doc.text.viewfinder      |             |
|         |                            |             |
|         |   Scan your medicine box    |             |
|         |   or label to get started   |             |
|         |                            |             |
|         +----------------------------+             |
|                                                    |
|  Take a photo of the medicine box, select an       |
|  image from your library, or use a demo image.     |
|                                                    |
|  +----------------------------------------------+ |
|  | [camera.fill]  Take Photo                     | |
|  +----------------------------------------------+ |
|  +----------------------------------------------+ |
|  | [photo.on.rectangle.angled]  Choose Photo     | |
|  +----------------------------------------------+ |
|  +----------------------------------------------+ |
|  | [photo.artframe]  Use Demo Image              | |
|  +----------------------------------------------+ |
|                                                    |
|  +----------------------------------------------+ |
|  | [pencil]  Enter Manually (Skip Scan)          | |
|  +----------------------------------------------+ |
|                                                    |
+--------------------------------------------------+
```

| Button | Icon | Style | Action |
|--------|------|-------|--------|
| Take Photo | `camera.fill` | `.bordered`, `.controlSize(.large)`, full-width | Opens camera via `UIImagePickerController` or `AVCaptureSession` |
| Choose Photo | `photo.on.rectangle.angled` | `.bordered`, `.controlSize(.large)`, full-width | Opens `PhotosPicker` |
| Use Demo Image | `photo.artframe` | `.bordered`, `.controlSize(.large)`, full-width | Loads a bundled sample medicine box image |
| Enter Manually | `pencil` | `.borderless`, `.secondary` color | Skips to Step 3 with empty fields |

**Cancel button:** Top-left, dismisses the sheet entirely with a confirmation if an image has been selected.

**Camera unavailability:** If the device has no camera (e.g., simulator), the "Take Photo" button is hidden. A note appears: "Camera not available on this device."

#### Step 2: OCR Processing

```
+--------------------------------------------------+
| [X Cancel]    Add Medication           Step 2/3   |
| ------------------------------------------------- |
|                                                    |
|         +----------------------------+             |
|         |                            |             |
|         |   [Selected image preview] |             |
|         |                            |             |
|         +----------------------------+             |
|                                                    |
|              [ProgressView spinning]               |
|                                                    |
|           Analyzing medicine box...                |
|                                                    |
|    This may take a few seconds. We're reading      |
|    the text on your medicine to fill in the        |
|    details automatically.                          |
|                                                    |
+--------------------------------------------------+
```

| Element | Details |
|---------|---------|
| Image preview | The selected/captured photo, displayed at ~60% screen width, aspect-fit, rounded corners 12pt |
| Progress indicator | `ProgressView()` with default spinning style, tinted accent teal |
| Status text | "Analyzing medicine box..." in `.headline`, `.primary` |
| Helper text | Explanatory paragraph in `.callout`, `.secondary` |

**Behavior:** Vision framework `VNRecognizeTextRequest` runs asynchronously. On completion, the app parses the recognized text to attempt auto-filling: medication name, dosage, form, expiration date, quantity. Transitions automatically to Step 3 when done.

**Timeout:** If OCR takes more than 10 seconds, show a "Taking longer than expected..." message. After 20 seconds, auto-advance to Step 3 with whatever partial results exist plus a banner: "We couldn't read all the text. Please review and complete the fields below."

#### Step 3: Review & Edit

```
+--------------------------------------------------+
| [X Cancel]    Add Medication           Step 3/3   |
| ------------------------------------------------- |
|                                                    |
| SCANNED IMAGE                                      |
| +----------------------------------------------+  |
| | [Image thumbnail, small]         [Retake btn] |  |
| +----------------------------------------------+  |
|                                                    |
| MEDICATION DETAILS                                 |
| +----------------------------------------------+  |
| | Name *               [checkmark.seal.fill]   |  |
| | [Ibuprofen                              ]    |  |
| +----------------------------------------------+  |
| +----------------------------------------------+  |
| | Form                                         |  |
| | [Tablet  v]  (picker)                        |  |
| +----------------------------------------------+  |
| +----------------------------------------------+  |
| | Dose *                [checkmark.seal.fill]  |  |
| | [200 mg                                 ]    |  |
| +----------------------------------------------+  |
| +----------------------------------------------+  |
| | Quantity *                                   |  |
| | [24                                     ]    |  |
| +----------------------------------------------+  |
| +----------------------------------------------+  |
| | Expiration Date *     [questionmark.diamond] |  |
| | [March 2027  v]  (date picker)               |  |
| +----------------------------------------------+  |
|                                                    |
| v RECOGNIZED TEXT (collapsible)                    |
| +----------------------------------------------+  |
| | "IBUPROFEN 200 mg Tablets                    |  |
| |  24 tablets. Exp: 03/2027                    |  |
| |  Lot: ABC123 ..."                            |  |
| +----------------------------------------------+  |
|                                                    |
| SCHEDULE (optional)                                |
| +----------------------------------------------+  |
| | Frequency: [Daily  v]                        |  |
| | Times:     [8:00 AM] [+]                     |  |
| | Dose per intake: [1 tablet]                  |  |
| +----------------------------------------------+  |
|                                                    |
| +----------------------------------------------+  |
| |            [Save Medication]                 |  |
| +----------------------------------------------+  |
|                                                    |
+--------------------------------------------------+
```

#### Confidence Indicators

Each auto-filled field has a trailing confidence indicator:

| Icon | Meaning | Color |
|------|---------|-------|
| `checkmark.seal.fill` | High confidence (>80%) | `systemGreen` |
| `questionmark.diamond` | Low confidence (<80%) or guessed | `systemOrange` |
| (no icon) | Manually entered | -- |

The user can tap the confidence icon to see a tooltip: "This field was automatically filled from the scanned text. Please verify it is correct."

#### Recognized Text Section

A `DisclosureGroup` (collapsible) that shows the raw OCR output:

```swift
DisclosureGroup("Recognized Text") {
    Text(ocrRawText)
        .font(.caption)
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
}
```

Collapsed by default. Allows the user to see exactly what the OCR captured and copy text if needed.

#### Form Fields

| Field | Type | Required | Default | Validation |
|-------|------|----------|---------|------------|
| Name | `TextField` | Yes | OCR result or empty | Non-empty |
| Form | `Picker` (menu style) | Yes | "Tablet" | -- |
| Dose | `TextField` | Yes | OCR result or empty | Non-empty |
| Quantity | `TextField` (numeric keyboard) | Yes | OCR result or "0" | Integer >= 0 |
| Expiration Date | `DatePicker` (.date) | Yes | OCR result or today + 1 year | Must be a date |
| Frequency | `Picker` | No | "Daily" | -- |
| Times | List of `DatePicker` (.hourAndMinute) | No | [8:00 AM] | -- |
| Dose per intake | `TextField` | No | "1 tablet" | -- |

**Save button:** Full-width, `.borderedProminent`, accent teal. Disabled until all required fields are valid.

---

### 3.D. Medication Detail

**Purpose:** Show complete information about a single medication, its status, schedule, and dose history. Allow editing and deletion.

#### ASCII Wireframe

```
+--------------------------------------------------+
| [< Back]   Medication Detail     [pencil Edit]    |
| ------------------------------------------------- |
|                                                    |
| +----------------------------------------------+  |
| |                                              |  |
| |           [Hero image / large icon]          |  |
| |                                              |  |
| +----------------------------------------------+  |
|                                                    |
| Ibuprofen                                          |
| Nonsteroidal anti-inflammatory (NSAID)             |
|                                                    |
| STATUS                                             |
| +----------------------------------------------+  |
| | [clock.badge.exclamationmark] Expiring Soon  |  |
| |                                              |  |
| | This medicine expires on March 15, 2026.     |  |
| | That's 22 days from now. You set a warning   |  |
| | for 30 days before expiration.               |  |
| +----------------------------------------------+  |
|                                                    |
| DETAILS                                            |
| +----------------------------------------------+  |
| | Form          pills.fill   Tablet            |  |
| | Dose                       200 mg            |  |
| | Quantity                   5 remaining        |  |
| | Expiration                 Mar 15, 2026       |  |
| | Added                      Feb 1, 2026        |  |
| +----------------------------------------------+  |
|                                                    |
| SCHEDULE                                           |
| +----------------------------------------------+  |
| | Daily                                        |  |
| | 8:00 AM -- 1 tablet                          |  |
| | 8:00 PM -- 1 tablet                          |  |
| |                                   [Edit]     |  |
| +----------------------------------------------+  |
|                                                    |
| RECENT DOSE LOG                                    |
| +----------------------------------------------+  |
| | Today, 8:00 AM       [checkmark] Taken       |  |
| | Yesterday, 8:00 PM   [checkmark] Taken       |  |
| | Yesterday, 8:00 AM   [forward]   Skipped     |  |
| | Feb 19, 8:00 PM      [checkmark] Taken       |  |
| | Feb 19, 8:00 AM      [checkmark] Taken       |  |
| +----------------------------------------------+  |
|                                                    |
| +----------------------------------------------+  |
| |     [trash.fill  Delete Medication]          |  |
| +----------------------------------------------+  |
|                                                    |
+--------------------------------------------------+
```

#### Hero Image Section

- If a photo exists: display it as a hero image, aspect-fill, clipped to a rounded rectangle (16pt radius), max height 200pt.
- If no photo: display a large SF Symbol for the medication form centered on a tinted background (`AccentTeal.opacity(0.08)`), 120pt symbol size.

#### Name and Subtitle

| Element | Font | Color |
|---------|------|-------|
| Medication name | `.title` bold | `.primary` |
| Description/category | `.subheadline` | `.secondary` |

#### Status Card

A prominent card explaining the current status in human-readable language.

```
Background: statusColor.opacity(0.08)
Border: statusColor.opacity(0.3), 1pt
Corner radius: 12pt
Padding: 16pt
```

| Element | Font | Color |
|---------|------|-------|
| Status icon + label | `.headline` | Status color |
| Explanation text | `.body` | `.primary` |

**Explanation text templates:**

- **Expired:** "This medicine expired on [date]. Expired medications may lose effectiveness or become harmful. Consider disposing of it safely."
- **Expiring Soon:** "This medicine expires on [date]. That's [N] days from now. You set a warning for [M] days before expiration."
- **Low Stock:** "Based on your schedule, you have about [N] days of this medicine left. Consider refilling soon."
- **OK:** "This medicine is in good standing. Expires on [date] ([N] days from now) and you have [Q] doses remaining."

#### Details Card

A grouped list-style card with key-value rows:

| Row | Leading | Trailing |
|-----|---------|----------|
| Form | "Form" + form icon | Form name (e.g., "Tablet") |
| Dose | "Dose" | "200 mg" |
| Quantity | "Quantity" | "5 remaining" |
| Expiration | "Expiration" | "Mar 15, 2026" |
| Added on | "Added" | "Feb 1, 2026" |

Each row is separated by a system divider.

#### Schedule Section

Shows the dosing schedule. Each entry is a row: time + dose per intake. An "Edit" button in the trailing position opens the schedule editor (inline or sheet).

If no schedule is set, show: "No schedule set. Tap Edit to add a dosing schedule."

#### Dose Log History

A list of recent dose log entries (last 10), each showing:

```
[Date, Time]        [icon] [Status]
```

| Status | Icon | Color |
|--------|------|-------|
| Taken | `checkmark.circle.fill` | `systemGreen` |
| Skipped | `forward.circle.fill` | `systemOrange` |
| Missed | `xmark.circle.fill` | `systemRed` |

#### Delete Button

Positioned at the bottom of the scroll view, visually separated.

```
Style: .bordered
Color: .red
Full-width
Icon: trash.fill
Label: "Delete Medication"
```

Triggers a `confirmationDialog`:

```swift
.confirmationDialog("Delete Medication", isPresented: $showDeleteConfirm) {
    Button("Delete", role: .destructive) { deleteMedication() }
    Button("Cancel", role: .cancel) {}
} message: {
    Text("Are you sure you want to delete \(medication.name)? This cannot be undone.")
}
```

---

### 3.E. Settings

**Purpose:** Allow the user to configure alert thresholds, toggle demo mode, and access app information.

#### ASCII Wireframe

```
+--------------------------------------------------+
| Settings                                           |
| ------------------------------------------------- |
|                                                    |
| ALERT THRESHOLDS                                   |
| +----------------------------------------------+  |
| | Expiry Warning                                |  |
| | Warn me [30 v] days before expiration         |  |
| +----------------------------------------------+  |
| +----------------------------------------------+  |
| | Low Stock Warning                             |  |
| | Warn when less than [7 v] days of supply      |  |
| +----------------------------------------------+  |
|                                                    |
| DEMO                                               |
| +----------------------------------------------+  |
| | Demo Mode                       [Toggle ON]  |  |
| | Load sample medications for demonstration     |  |
| +----------------------------------------------+  |
|                                                    |
| ABOUT                                              |
| +----------------------------------------------+  |
| | About MedCabinet                          [>] |  |
| +----------------------------------------------+  |
| +----------------------------------------------+  |
| | Privacy                                   [>] |  |
| +----------------------------------------------+  |
|                                                    |
| SAFETY DISCLAIMER                                  |
| +----------------------------------------------+  |
| | exclamationmark.shield.fill                  |  |
| |                                              |  |
| | This app is a personal organization tool.    |  |
| | It does not provide medical advice. Always   |  |
| | consult a healthcare professional for        |  |
| | medication decisions.                        |  |
| +----------------------------------------------+  |
|                                                    |
| Made with care for the Swift Student Challenge     |
| 2026                                               |
|                                                    |
+---------+-----------+-----------+------------------+
|  Today  |   Meds    |  Settings |                  |
+---------+-----------+-----------+------------------+
```

#### Layout

`Form` with grouped sections (`Section` with headers).

#### Section: Alert Thresholds

**Expiry Warning Days:**

```swift
Picker("Expiry Warning", selection: $expiryWarningDays) {
    Text("7 days").tag(7)
    Text("14 days").tag(14)
    Text("30 days").tag(30)
    Text("60 days").tag(60)
    Text("90 days").tag(90)
}
```

Below the picker, a footer explains: "You'll see an 'Expiring Soon' alert for medications within this window."

**Low Stock Threshold Days:**

```swift
Picker("Low Stock Warning", selection: $lowStockDays) {
    Text("3 days").tag(3)
    Text("5 days").tag(5)
    Text("7 days").tag(7)
    Text("14 days").tag(14)
    Text("30 days").tag(30)
}
```

Footer: "Based on your dosing schedule, we'll warn you when supply runs low."

#### Section: Demo

**Demo Mode Toggle:**

```swift
Toggle(isOn: $isDemoMode) {
    Label("Demo Mode", systemImage: "tray.and.arrow.down.fill")
}
```

Footer: "When enabled, the app loads sample medications to demonstrate all features. Disable to start fresh with your own data."

#### Section: About

- **About MedCabinet:** Navigation link to an about screen with app name, version, a brief description, and credits for any third-party resources.
- **Privacy:** Navigation link to a privacy notice screen.

#### Privacy Notice Content

```
Your data stays on your device.

MedCabinet does not collect, transmit, or share any personal information.
All medication data is stored locally on this device only. No analytics,
no tracking, no cloud sync.

Photos you scan are processed entirely on-device using Apple's Vision
framework. They are never uploaded to any server.
```

#### Safety Disclaimer

Always visible at the bottom of the Settings screen. Uses a card with a yellow/orange tint:

```
Background: Color(.systemOrange).opacity(0.08)
Border: Color(.systemOrange).opacity(0.2)
Icon: exclamationmark.shield.fill, systemOrange
Text: .callout, .primary
```

Content: "This app is a personal organization tool. It does not provide medical advice, diagnosis, or treatment recommendations. Always consult a qualified healthcare professional before making any decisions about your medications."

---

## 4. Interaction Patterns

### 4.1 Swipe Actions on Dose Cards (Today View)

Dose cards in the Today view support swipe gestures as an alternative to the visible buttons:

```swift
.swipeActions(edge: .trailing, allowsFullSwipe: true) {
    Button {
        markAsTaken(dose)
    } label: {
        Label("Taken", systemImage: "checkmark.circle.fill")
    }
    .tint(.green)
}

.swipeActions(edge: .leading, allowsFullSwipe: false) {
    Button {
        skipDose(dose)
    } label: {
        Label("Skip", systemImage: "forward.fill")
    }
    .tint(.orange)
}
```

| Gesture | Direction | Full Swipe | Action |
|---------|-----------|------------|--------|
| Swipe left | Trailing | Yes (full swipe marks as taken) | Mark as Taken |
| Swipe right | Leading | No (must tap) | Skip dose |

### 4.2 Haptic Feedback

Haptic feedback is triggered for meaningful state changes:

| Action | Haptic Type | SwiftUI API |
|--------|-------------|-------------|
| Mark dose as Taken | `.success` notification | `UINotificationFeedbackGenerator().notificationOccurred(.success)` |
| Skip dose | `.warning` notification | `UINotificationFeedbackGenerator().notificationOccurred(.warning)` |
| Save new medication | `.success` notification | Same as above |
| Delete medication | `.error` notification | `UINotificationFeedbackGenerator().notificationOccurred(.error)` |
| Tap alert chip | Light impact | `UIImpactFeedbackGenerator(style: .light).impactOccurred()` |
| Load demo data | Medium impact | `UIImpactFeedbackGenerator(style: .medium).impactOccurred()` |

### 4.3 Pull to Refresh (Today View)

The Today view supports pull-to-refresh to recalculate statuses and re-sort doses:

```swift
.refreshable {
    await refreshTodayData()
}
```

This recalculates:
- Which doses are upcoming, due, or overdue
- Updated status badges (expiration checks against current date)
- Re-sorts the dose list by time

### 4.4 Confirmation Dialog on Delete

As specified in Section 3.D, deletion requires confirmation via a `confirmationDialog`. The dialog uses a destructive button style and a clear warning message.

### 4.5 Toast / Banner for Success Actions

After successful actions, a brief toast/banner appears at the top of the screen and auto-dismisses after 2 seconds:

| Action | Toast Message | Icon |
|--------|--------------|------|
| Medication saved | "Medication saved successfully" | `checkmark.circle.fill` |
| Dose marked as taken | "Dose recorded" | `checkmark.circle.fill` |
| Demo data loaded | "Demo data loaded" | `tray.and.arrow.down.fill` |
| Medication deleted | "Medication deleted" | `trash.fill` |

**Toast design:**

```
+--------------------------------------------------+
| [icon]  Message text                              |
+--------------------------------------------------+

Background: Color(.systemBackground) with shadow
Position: top of screen, below safe area
Animation: slide down from top, auto-dismiss after 2s
Corner radius: 12pt
Padding: 12pt horizontal, 8pt vertical
```

Implementation approach: A custom `ViewModifier` or overlay that animates in with `.transition(.move(edge: .top).combined(with: .opacity))`.

### 4.6 Long-Press Context Menu on Medication Cards

On the Medications list, long-pressing a card reveals a context menu:

```swift
.contextMenu {
    Button {
        // navigate to detail
    } label: {
        Label("View Details", systemImage: "info.circle")
    }
    Button {
        // open edit sheet
    } label: {
        Label("Edit", systemImage: "pencil")
    }
    Divider()
    Button(role: .destructive) {
        // delete with confirmation
    } label: {
        Label("Delete", systemImage: "trash")
    }
}
```

---

## 5. Accessibility Specifications

Accessibility is a core design pillar, not an afterthought. Apple explicitly judges on "inclusivity," and the medical nature of this app makes accessibility especially critical -- users may include elderly people, those with visual impairments, or people under stress.

### 5.1 VoiceOver Labels

Every interactive element must have an `accessibilityLabel` and, where appropriate, an `accessibilityHint`.

#### Today Dashboard

| Element | Label | Hint | Value |
|---------|-------|------|-------|
| Alert chip (Expired) | "Expired medications" | "Shows list of expired medications" | "[N] medications" |
| Alert chip (Expiring Soon) | "Expiring soon" | "Shows list of medications expiring soon" | "[N] medications" |
| Alert chip (Low Stock) | "Low stock medications" | "Shows list of medications running low" | "[N] medications" |
| Dose card | "[Name], [dose], scheduled for [time]" | "Double tap to view details" | "Not taken" / "Taken" / "Skipped" |
| Taken button | "Mark as taken" | "Records this dose as taken" | -- |
| Skip button | "Skip this dose" | "Marks this dose as skipped" | -- |
| Load Demo Data | "Load demo data" | "Loads sample medications to explore the app" | -- |

#### Medications List

| Element | Label | Hint | Value |
|---------|-------|------|-------|
| Medication card | "[Name], [form], [dose], [quantity] remaining, status: [status]" | "Double tap to view details" | -- |
| Add button | "Add medication" | "Opens the add medication form" | -- |
| Sort button | "Sort medications" | "Choose how to sort the medication list" | -- |
| Search field | "Search medications" | "Filter medications by name" | -- |

#### Add Medication Flow

| Element | Label | Hint |
|---------|-------|------|
| Take Photo | "Take photo of medicine box" | "Opens the camera to photograph your medicine" |
| Choose Photo | "Choose photo from library" | "Opens your photo library to select a medicine image" |
| Use Demo Image | "Use demo image" | "Uses a sample medicine box image for demonstration" |
| Enter Manually | "Enter details manually" | "Skip scanning and type medicine details yourself" |
| Confidence icon (high) | "Automatically detected with high confidence" | "This field was filled from the scanned image" |
| Confidence icon (low) | "Automatically detected with low confidence, please verify" | "This field may need correction" |
| Save button | "Save medication" | "Saves this medication to your inventory" |

#### Medication Detail

| Element | Label | Hint |
|---------|-------|------|
| Status card | "[Status]: [explanation text]" | -- |
| Edit button | "Edit medication" | "Opens the edit form for this medication" |
| Delete button | "Delete medication" | "Permanently removes this medication from your inventory" |
| Dose log entry | "[Date] at [time], [status]" | -- |

### 5.2 Dynamic Type Support

All text must use `Font.TextStyle` tokens (never hardcoded sizes). The layout must adapt gracefully at every Dynamic Type size from `xSmall` to `accessibility5` (the largest).

**Layout adaptation rules:**

| Dynamic Type Range | Layout Change |
|-------------------|---------------|
| `xSmall` to `xxxLarge` | Standard layouts, spacing scales proportionally |
| `accessibility1` to `accessibility5` | Medication cards switch from 2-column grid to single-column list. Dose cards expand vertically. Buttons stack vertically instead of side-by-side. |

**Implementation:**

```swift
@Environment(\.dynamicTypeSize) var dynamicTypeSize

var isAccessibilitySize: Bool {
    dynamicTypeSize >= .accessibility1
}

// In dose card:
if isAccessibilitySize {
    VStack { skipButton; takenButton }
} else {
    HStack { skipButton; takenButton }
}
```

### 5.3 Minimum Touch Targets

Every interactive element must have a minimum touch target of 44x44 points, per Apple Human Interface Guidelines.

```swift
.frame(minWidth: 44, minHeight: 44)
// or
.contentShape(Rectangle())
.frame(minHeight: 44)
```

### 5.4 Color Independence

Color is **never** the sole indicator of status. Every status is conveyed through three channels:

1. **Color** -- the tinted background and icon/text color
2. **Icon** -- a distinct SF Symbol for each status
3. **Text label** -- "Expired," "Expiring Soon," "Low Stock," "Good"

This ensures users with color vision deficiency, or those in high-contrast mode, can distinguish all statuses.

### 5.5 High Contrast Alternatives

The app inherits system high-contrast behavior automatically through the use of semantic system colors. Additionally:

- Status badge backgrounds use `statusColor.opacity(0.12)` in normal mode. In high-contrast mode (detected via `@Environment(\.colorSchemeContrast)`), increase to `statusColor.opacity(0.2)` and add a 1pt border.
- Card shadows are removed in high-contrast mode (they add visual noise).
- Focus/selection states use a prominent border rather than a subtle background change.

### 5.6 Reduce Motion

For users with "Reduce Motion" enabled:

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion
```

| Standard Animation | Reduced Motion Alternative |
|-------------------|---------------------------|
| Card slide-up entrance | Simple fade-in |
| Status badge pulse | Static display |
| Checkmark animation | Instant checkmark |
| Tab transitions | Cross-dissolve |
| Toast slide-in | Instant appear/disappear |

### 5.7 VoiceOver Grouping

Related elements should be grouped for efficient VoiceOver navigation:

```swift
// Dose card: group all elements into one accessible unit
.accessibilityElement(children: .combine)
.accessibilityLabel("Ibuprofen, 200 milligrams, 1 tablet, scheduled for 8 AM, not yet taken")
.accessibilityActions {
    AccessibilityActionItem(named: "Mark as taken") { markAsTaken() }
    AccessibilityActionItem(named: "Skip") { skipDose() }
}
```

---

## 6. Empty States

Every screen must handle the "no content" state gracefully. Empty states use an SF Symbol illustration, a title, a subtitle, and a call-to-action button.

### 6.1 Today Dashboard -- No Doses Scheduled

```
+--------------------------------------------------+
|                                                    |
|                                                    |
|              calendar.badge.checkmark              |
|                  (60pt, .secondary)                |
|                                                    |
|             All clear for today!                   |
|                                                    |
|    No doses are scheduled for today. Enjoy          |
|    your day, or add a medication with a             |
|    schedule to see your daily plan here.             |
|                                                    |
|    [+ Add Medication]                               |
|                                                    |
|    [tray.and.arrow.down.fill Load Demo Data]        |
|                                                    |
+--------------------------------------------------+
```

| Element | Font | Color |
|---------|------|-------|
| SF Symbol | 60pt | `.secondary` |
| Title | `.title2` bold | `.primary` |
| Subtitle | `.body` | `.secondary` |
| CTA button | `.borderedProminent` | AccentTeal |
| Demo button | `.bordered` | AccentTeal |

**SF Symbol:** `calendar.badge.checkmark`
**Title:** "All clear for today!"
**Subtitle:** "No doses are scheduled for today. Enjoy your day, or add a medication with a schedule to see your daily plan here."
**CTA:** "Add Medication" (opens the Meds tab or Add Medication sheet)

### 6.2 Medications List -- No Medications

```
+--------------------------------------------------+
|                                                    |
|                                                    |
|                 pills.circle                       |
|                 (60pt, .secondary)                 |
|                                                    |
|           Your medicine cabinet is empty            |
|                                                    |
|    Add your first medication by scanning the        |
|    box or entering the details manually.            |
|                                                    |
|    [+ Add Your First Medication]                    |
|                                                    |
|    [tray.and.arrow.down.fill Load Demo Data]        |
|                                                    |
+--------------------------------------------------+
```

**SF Symbol:** `pills.circle`
**Title:** "Your medicine cabinet is empty"
**Subtitle:** "Add your first medication by scanning the box or entering the details manually."
**CTA:** "Add Your First Medication" (opens Add Medication sheet)

### 6.3 Medications List -- No Search Results

```
+--------------------------------------------------+
|                                                    |
|              magnifyingglass.circle                |
|              (48pt, .secondary)                    |
|                                                    |
|           No results for "[query]"                 |
|                                                    |
|    Try a different search term or check the         |
|    spelling.                                        |
|                                                    |
+--------------------------------------------------+
```

**SF Symbol:** `magnifyingglass.circle`
**Title:** "No results for '[query]'"
**Subtitle:** "Try a different search term or check the spelling."
**CTA:** None (the search field is still active)

### 6.4 Medication Detail -- No Dose Log

```
+--------------------------------------------------+
|                                                    |
| RECENT DOSE LOG                                    |
|                                                    |
|              clock.arrow.circlepath                |
|              (36pt, .secondary)                    |
|                                                    |
|           No doses recorded yet                    |
|                                                    |
|    Dose history will appear here as you             |
|    track your daily intake.                         |
|                                                    |
+--------------------------------------------------+
```

**SF Symbol:** `clock.arrow.circlepath`
**Title:** "No doses recorded yet"
**Subtitle:** "Dose history will appear here as you track your daily intake."

### 6.5 Medication Detail -- No Schedule

```
+--------------------------------------------------+
|                                                    |
| SCHEDULE                                           |
|                                                    |
|              clock.badge.questionmark              |
|              (36pt, .secondary)                    |
|                                                    |
|           No schedule set                          |
|                                                    |
|    Add a dosing schedule to track when              |
|    to take this medication.                         |
|                                                    |
|    [+ Add Schedule]                                 |
|                                                    |
+--------------------------------------------------+
```

**SF Symbol:** `clock.badge.questionmark`
**Title:** "No schedule set"
**Subtitle:** "Add a dosing schedule to track when to take this medication."
**CTA:** "Add Schedule" (opens schedule editor)

### 6.6 Today Dashboard -- No Alerts

The alert chips area simply does not render (the section is hidden). There is no empty state for "no alerts" -- this is a positive condition and needs no messaging.

---

## 7. Loading States

### 7.1 OCR Processing

As described in Section 3.C Step 2:

```
[Image preview, smaller]

     ProgressView()   (spinning, tinted AccentTeal)

     "Analyzing medicine box..."
     (.headline, .primary)

     "This may take a few seconds. We're reading the
      text on your medicine to fill in the details
      automatically."
     (.callout, .secondary)
```

The ProgressView uses the default spinning style. No percentage/determinate progress (OCR does not report fractional progress).

### 7.2 Data Loading (App Launch)

On first launch or when loading persisted data:

- The app shows the Today tab immediately with a brief `ProgressView` if data loading takes more than 200ms.
- Skeleton views are not required for MVP due to the small dataset size. Data loads from local storage nearly instantly.
- If data loading exceeds 500ms (unlikely with local storage), show a centered `ProgressView` with "Loading your medications..." text.

### 7.3 Image Loading (Medication Photos)

When a medication card displays a user photo:

```swift
AsyncImage(url: photoURL) { phase in
    switch phase {
    case .empty:
        ProgressView()
    case .success(let image):
        image.resizable().aspectRatio(contentMode: .fill)
    case .failure:
        Image(systemName: "pills.fill") // fallback icon
    @unknown default:
        EmptyView()
    }
}
```

Since photos are stored locally, loading is near-instant, but the fallback handles edge cases.

### 7.4 Demo Data Loading

When the user taps "Load Demo Data":

```
1. Button becomes disabled
2. Button label changes to: ProgressView() + "Loading..."
3. After data is populated (~0.5s artificial delay for feel):
   - Toast appears: "Demo data loaded"
   - Haptic: medium impact
   - Screen refreshes with populated content
```

---

## 8. Error States

### 8.1 OCR Failed Completely

When the Vision framework returns no recognized text or throws an error:

```
+--------------------------------------------------+
|                                                    |
|         +----------------------------+             |
|         |   [Selected image, dimmed] |             |
|         +----------------------------+             |
|                                                    |
|         exclamationmark.triangle.fill              |
|         (systemOrange, 36pt)                       |
|                                                    |
|     Couldn't read the text                         |
|                                                    |
|     We weren't able to extract text from this      |
|     image. Please try a clearer photo, or enter    |
|     the details manually.                          |
|                                                    |
|     [camera.fill  Retake Photo]                    |
|     [pencil  Enter Manually]                       |
|                                                    |
+--------------------------------------------------+
```

| Element | Font | Color |
|---------|------|-------|
| Error icon | 36pt | `systemOrange` |
| Title | `.title3` bold | `.primary` |
| Subtitle | `.body` | `.secondary` |
| Retake button | `.bordered`, `.controlSize(.large)` | AccentTeal |
| Enter Manually button | `.bordered`, `.controlSize(.large)` | `.secondary` |

### 8.2 No Camera Available

When `AVCaptureDevice.default(for: .video)` returns nil:

- The "Take Photo" button in Step 1 is hidden entirely.
- A small notice appears in its place:

```
[camera.slash]  Camera not available on this device.
                Use "Choose Photo" or "Use Demo Image" instead.
```

Font: `.footnote`, color: `.secondary`.

This is not treated as an error -- it is a graceful degradation. The flow still works fully through the photo picker or demo image paths.

### 8.3 Photo Too Dark / Blurry (Low OCR Confidence)

When OCR returns text but the overall confidence is very low (below 30%):

```
+--------------------------------------------------+
|                                                    |
|     [info.circle]  Low quality scan                |
|                                                    |
|     The image may be too dark or blurry. We        |
|     found some text but it may not be accurate.    |
|     You can:                                       |
|                                                    |
|     [camera.fill  Retake Photo]                    |
|     [arrow.right  Continue with Results]           |
|                                                    |
+--------------------------------------------------+
```

This appears as a banner at the top of Step 3 (Review & Edit), not as a blocking error. The user can still proceed and manually correct the fields.

### 8.4 Photo Picker Permission Denied

If the user denies photo library access:

```
[photo.slash]  Photo library access denied.

To scan medicine boxes, MedCabinet needs access to your photos.
You can enable this in Settings > Privacy > Photos.

[Open Settings]
```

The "Open Settings" button opens the system Settings app via `UIApplication.openSettingsURLString`.

### 8.5 Save Validation Error

If the user tries to save with missing required fields:

- The Save button remains disabled (it only enables when all required fields are filled).
- Empty required fields show a red border and a helper message below: "This field is required."
- The first invalid field scrolls into view automatically.

### 8.6 Data Persistence Error

If saving to the local data store fails (extremely rare):

```
Toast (error style):
[xmark.circle.fill]  "Couldn't save. Please try again."

Color: systemRed background tint
Auto-dismiss: 3 seconds
```

---

## 9. Animations

All animations should be subtle and purposeful. They should reinforce meaning, not distract. Every animation must have a reduced-motion alternative (see Section 5.6).

### 9.1 Card Appearance (Fade + Slide Up)

When medication cards or dose cards first appear (on list load or after adding a new item):

```swift
.transition(.asymmetric(
    insertion: .opacity.combined(with: .move(edge: .bottom)),
    removal: .opacity
))
.animation(.easeOut(duration: 0.3), value: items)
```

- **Duration:** 0.3 seconds
- **Curve:** `.easeOut`
- **Effect:** Card fades in while sliding up 20pt from its final position
- **Reduced motion:** Simple `.opacity` transition (instant fade, no movement)

### 9.2 Status Badge Pulse on Change

When a medication's status changes (e.g., from "OK" to "Expiring Soon" due to date crossing the threshold):

```swift
.symbolEffect(.pulse, options: .repeating, value: statusChanged)
```

- **Effect:** The status icon pulses (brightens and dims) 3 times
- **Duration:** ~1.5 seconds total
- **Reduced motion:** No pulse, static display

### 9.3 Taken Checkmark Animation

When the user marks a dose as "Taken":

```swift
Image(systemName: "checkmark.circle.fill")
    .symbolEffect(.bounce, value: isTaken)
    .foregroundStyle(.green)
    .font(.title)
```

**Sequence:**
1. Button taps triggers haptic (`.success`)
2. Checkmark icon appears with a `.bounce` symbol effect
3. Card text gets a strikethrough with `.animation(.easeInOut(duration: 0.3))`
4. Card dims to `opacity(0.5)` and slides to the bottom of its section

- **Duration:** 0.5 seconds total
- **Reduced motion:** Instant state change, no bounce

### 9.4 Tab Transitions

Standard SwiftUI TabView transitions. No custom animation needed -- the system provides a smooth cross-fade by default.

### 9.5 Sheet Presentation

Sheets use the standard iOS presentation animation (slide up from bottom). No customization needed.

### 9.6 Alert Chip Appearance

When the Today view loads and alert chips are present:

```swift
ForEach(alerts.indices, id: \.self) { index in
    AlertChip(alert: alerts[index])
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.1), value: showAlerts)
}
```

- **Effect:** Chips scale in from 0 to 100% with a staggered delay (100ms between each)
- **Curve:** Spring with 0.8 damping
- **Reduced motion:** All appear instantly

### 9.7 Demo Data Loading

When demo data loads, new cards cascade in with staggered timing:

```swift
.animation(.easeOut(duration: 0.3).delay(Double(index) * 0.05), value: medications)
```

This creates a "filling up" effect where cards appear one after another quickly (50ms stagger).

### 9.8 Delete Animation

When a medication is deleted:

```swift
.transition(.asymmetric(
    insertion: .identity,
    removal: .opacity.combined(with: .scale(scale: 0.8))
))
```

Card shrinks slightly and fades out over 0.25 seconds.

---

## 10. Educational Micro-copy

Educational micro-copy helps users understand the app's calculations and recommendations without needing to read a manual. These appear contextually, at the moment the user encounters the concept.

### 10.1 "Why Low Stock?"

**Trigger:** Tap the `info.circle` icon next to a "Low Stock" badge, or VoiceOver reads this as part of the status card on the Medication Detail screen.

**Content:**

> "Based on your schedule of [N doses per day], you have approximately [X] days of [Medication Name] left. At this rate, you'll run out around [estimated date]. Consider refilling soon."

**Example:**

> "Based on your schedule of 2 doses per day, you have approximately 3 days of Ibuprofen left. At this rate, you'll run out around February 24. Consider refilling soon."

**Design:** Appears as an expandable section within the status card on the Medication Detail view, or as a `.popover` / `.sheet(.medium)` from the info button.

### 10.2 "Why Expiring Soon?"

**Trigger:** Tap the `info.circle` icon next to an "Expiring Soon" badge.

**Content:**

> "This medicine expires on [expiration date]. That's [N] days from now. You set a warning for [M] days before expiration in Settings. You can adjust this threshold in Settings > Alert Thresholds."

**Example:**

> "This medicine expires on March 15, 2026. That's 22 days from now. You set a warning for 30 days before expiration in Settings. You can adjust this threshold in Settings > Alert Thresholds."

### 10.3 "Why Expired?"

**Trigger:** Automatic display on the status card when a medication is expired.

**Content:**

> "This medicine expired on [date]. Expired medications may lose their effectiveness and, in rare cases, could be harmful. The FDA recommends not taking expired medications. Please consult your pharmacist about safe disposal."

### 10.4 Expiry Warning Threshold Explanation (Settings)

**Location:** Footer text below the Expiry Warning Days picker in Settings.

**Content:**

> "Medications will show an 'Expiring Soon' warning when they are within this many days of their expiration date. For example, setting this to 30 days means a medication expiring on April 1 will show a warning starting March 2."

### 10.5 Low Stock Threshold Explanation (Settings)

**Location:** Footer text below the Low Stock Threshold picker in Settings.

**Content:**

> "We estimate your remaining supply based on your dosing schedule. When the estimated days of supply drops below this threshold, the medication will show a 'Low Stock' warning. This helps you plan refills before you run out."

### 10.6 OCR Scan Guidance (Step 1)

**Location:** Below the action buttons on the Scan step.

**Content:**

> "For best results, photograph the front of the medicine box in good lighting. Hold the device steady and make sure the text is clearly visible. The app will try to read the medicine name, dose, and expiration date automatically."

### 10.7 Confidence Indicator Explanation

**Trigger:** Tap a confidence icon (`checkmark.seal.fill` or `questionmark.diamond`) in the Review & Edit form.

**Content (High confidence):**

> "This field was automatically filled from the scanned text with high confidence. It is likely correct, but please verify before saving."

**Content (Low confidence):**

> "This field was automatically filled from the scanned text, but the app is not very confident about this value. Please check it carefully and correct if needed."

### 10.8 Dose Tracking Explanation (First Use)

**Trigger:** First time the user sees the Today Dashboard with scheduled doses. Shown once as a dismissible banner at the top.

**Content:**

> "Tap 'Taken' when you take your dose, or 'Skip' if you choose not to take it. You can also swipe right to mark as taken. This helps you keep track of your medication routine."

**Design:** A tinted card (`AccentTeal.opacity(0.08)`) with a dismiss button (`xmark.circle`). Stored in UserDefaults so it only shows once.

### 10.9 Safety Disclaimer (First Launch)

**Trigger:** On very first app launch, before the main UI.

**Content:**

> "Welcome to MedCabinet. This app helps you organize and track your medications at home. It is not a substitute for medical advice. Always follow your healthcare provider's instructions."

**Design:** A single-screen card with the app icon, the welcome message, and a "Get Started" button. Shown once.

### 10.10 Demo Mode Explanation

**Trigger:** When the user loads demo data.

**Content (banner):**

> "Demo mode is active. You're seeing sample medications to explore the app. Go to Settings to turn off demo mode and start with your own medications."

**Design:** A persistent but dismissible banner at the top of the Today and Medications screens. Uses `AccentTeal.opacity(0.08)` background. Includes a "Dismiss" button and a "Go to Settings" link.

---

## Appendix A: Component Summary Table

| Component | Used On | Key Properties |
|-----------|---------|----------------|
| DoseCard | Today Dashboard | Medicine name, dose, time, Taken/Skip buttons, swipe actions |
| AlertChip | Today Dashboard | Status color, icon, label, count badge, tappable |
| MedicationCard | Medications List | Photo/icon, name, form, dose, quantity, status badge |
| StatusBadge | Cards, Detail | Icon + label on tinted background, three-channel status |
| StatusCard | Medication Detail | Expanded status with explanation text, tinted border |
| ConfidenceIndicator | Add Medication Step 3 | Checkmark seal (high) or question diamond (low) |
| Toast | Global overlay | Icon + message, auto-dismiss, slide from top |
| EmptyState | All screens | SF Symbol (large), title, subtitle, CTA button |
| FormField | Add/Edit Medication | Label, input, optional confidence indicator, validation |

## Appendix B: Data Model (UX-Relevant Fields)

These are the fields the UX layer needs to display and edit. Implementation details are left to the architecture spec.

| Field | Type | Display Location |
|-------|------|-----------------|
| `id` | UUID | Internal |
| `name` | String | Everywhere |
| `form` | Enum (tablet, capsule, liquid, etc.) | Card icon, detail |
| `dose` | String (e.g., "200 mg") | Cards, detail |
| `quantity` | Int | Cards, detail, low stock calculation |
| `expirationDate` | Date | Detail, status calculation |
| `photoData` | Data? (optional) | Card thumbnail, detail hero |
| `schedule` | Schedule? (optional) | Today doses, detail |
| `dateAdded` | Date | Detail |
| `notes` | String? (optional) | Detail |
| `ocrRawText` | String? (optional) | Add flow recognized text section |

## Appendix C: Demo Data Specification

Pre-loaded medications for judge demonstration. This data must make every feature visible immediately.

| Name | Form | Dose | Qty | Expiration | Status | Schedule |
|------|------|------|-----|------------|--------|----------|
| Ibuprofen | Tablet | 200 mg | 5 | Mar 15, 2026 | Expiring Soon | 8 AM, 8 PM |
| Amoxicillin | Capsule | 500 mg | 12 | Feb 10, 2026 | Expired | 8 AM, 2 PM, 8 PM |
| Acetaminophen | Tablet | 500 mg | 24 | Dec 2026 | OK | 8 AM (as needed) |
| Loratadine | Tablet | 10 mg | 30 | Sep 2027 | OK | 9 AM |
| Omeprazole | Capsule | 20 mg | 14 | Nov 2026 | OK | 7 AM (before breakfast) |
| Children's Cough Syrup | Liquid | 5 ml | 2 doses left | Jan 2027 | Low Stock | As needed |
| Hydrocortisone Cream | Cream | 1% | 1 tube | Apr 2026 | OK | As needed |
| Albuterol Inhaler | Inhaler | 90 mcg | 20 puffs | Feb 20, 2026 | Expired | As needed |

This set ensures:
- At least 2 expired items (Amoxicillin, Albuterol)
- At least 1 expiring soon (Ibuprofen)
- At least 1 low stock (Cough Syrup)
- Multiple OK items
- Variety of medication forms (tablet, capsule, liquid, cream, inhaler)
- Mix of scheduled and as-needed medications
- Multiple daily schedules for Today view population

---

*End of UX Specification Document*
