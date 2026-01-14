# ProteinScore - Nutrition Label Scanner

## Project Overview

ProteinScore is an iOS app that uses real-time OCR to scan nutrition labels and calculate protein density ratios. The app opens directly to camera view and displays a color-coded overlay showing grams of protein per 100 calories.

**Repository**: https://github.com/winniewuzl/ProteinScanner
**Technology Stack**: Swift, SwiftUI, AVFoundation, Vision Framework
**Target**: iOS 16+
**Orientation**: Portrait-only

## Core Features

1. **Real-time OCR Scanning**
   - AVFoundation camera capture with macro mode support
   - Vision framework text recognition (accurate mode)
   - Processes frames every 0.5 seconds
   - Center 70% region of interest to reduce noise

2. **Nutrition Data Parsing**
   - Detects "Nutrition Facts" validation
   - Extracts calories (50-10000 range)
   - Extracts protein (0-1000g range)
   - Calculates ratio: `(protein / calories) × 100`

3. **Color-Coded Overlay**
   - **Excellent** (≥15 g/100cal): Green `#22C55E`
   - **Good** (10-15): Lime `#84CC16`
   - **Moderate** (5-10): Yellow `#EAB308`
   - **Low** (2-5): Orange `#F97316`
   - **Poor** (<2): Red `#EF4444`
   - Auto-fades after 3 seconds of no detection

4. **Anti-Jitter Smoothing**
   - Median filter over last 5 readings
   - Requires minimum 3 readings for smoothing
   - Clears buffer when overlay fades

## Architecture

### File Structure

```
ProteinScore/
├── Info.plist                    # Bundle config + camera permission
├── ProteinScoreApp.swift         # App entry point
├── ContentView.swift             # Root view (wrapper)
├── CameraView.swift              # Camera preview + overlay
├── CameraViewModel.swift         # Camera session + OCR pipeline
├── NutritionParser.swift         # Text parsing logic
├── ProteinScore.swift            # Rating enum + colors
└── NutritionOverlayView.swift    # Overlay UI component
```

### Key Components

#### CameraViewModel.swift
**Purpose**: Manages camera session and OCR processing

**Camera Setup**:
- Device selection chain: Triple Camera → Dual Camera → Wide Angle
- Continuous autofocus for close-up scanning
- Subject area change monitoring for automatic refocus
- Continuous auto-exposure for varying lighting

**OCR Configuration**:
```swift
request.recognitionLevel = .accurate
request.usesLanguageCorrection = true
request.minimumTextHeight = 0.015  // Filter fine print (1.5% of frame)
request.regionOfInterest = CGRect(x: 0.15, y: 0.15, width: 0.7, height: 0.7)
```

**Row-Grouping Algorithm**:
Groups OCR observations into horizontal rows to reconstruct lines from scattered text:
1. Extract text + bounding box coordinates (midY, minX)
2. Sort by Y-coordinate (top to bottom)
3. Group within 2% vertical threshold
4. Sort each row by X-coordinate (left to right)
5. Join with spaces

**Temporal Smoothing**:
- Maintains buffer of last 5 `NutritionData` readings
- Calculates median calories and median protein separately
- Returns new reading if fewer than 3 samples
- Prevents flickering from OCR variance

#### NutritionParser.swift
**Purpose**: Extracts calories and protein from text lines

**Validation**:
Requires "Nutrition Facts" keyword (handles OCR typos: "nutritlonfacts", "nutrition")

**Calorie Parsing Strategy** (Latest Refinement):
1. Find line containing word "Calories" using regex: `\bcalor[io0]e?s?\b`
2. Extract ALL numbers from that same line
3. Filter to calorie range (50-10000)
4. Return first valid number found
5. **Fallback**: Check previous line for numbers (handles "Amount per serving 250")
6. **Fallback**: Check next line for numbers

**Why This Works**:
- Handles "Calories 140" → finds 140 on same line
- Handles "Calories Trans Fat 0g..." → ignores 0, checks adjacent lines
- Handles "Amount per serving 250" + "Calories" on next line → finds 250 from previous
- Handles "130 % Daily Value*" + "Calories..." on next line → finds 130 from previous

**Protein Parsing Strategy**:
Pattern matching with OCR error tolerance:
```swift
#"protein\s*(\d+)\s*g?"#     // Basic: "Protein 10g" or "Protein 10"
#"pr[o0]tein\s*(\d+)\s*g?"#  // "Pr0tein 10g"
#"pr[o0]t[ei]in\s*(\d+)\s*g?"# // "Protiin 10g"
```

#### NutritionData.swift
```swift
struct NutritionData: Equatable {
    let calories: Int
    let protein: Int

    var ratio: Double {
        guard calories > 0 else { return 0 }
        return (Double(protein) / Double(calories)) * 100
    }
}
```

#### ProteinScore.swift
```swift
enum ProteinScore {
    case excellent  // 15+
    case good       // 10-15
    case moderate   // 5-10
    case low        // 2-5
    case poor       // <2

    static func from(ratio: Double) -> ProteinScore { ... }
    var color: Color { ... }
    var label: String { ... }
}
```

#### NutritionOverlayView.swift
**Layout**:
- Blur background (ultraThinMaterial)
- Large ratio number (72pt bold rounded)
- Unit text ("g protein / 100 cal")
- Color-coded circle + rating label
- 0.3s opacity transition animation

## Development History

### Phase 1: Initial Implementation
- Created Xcode project structure
- Set up AVFoundation camera capture
- Implemented Vision OCR pipeline
- Created basic SwiftUI views

### Phase 2: Nutrition Parsing
- Added regex-based calorie/protein extraction
- Implemented "Nutrition Facts" validation
- Created NutritionData model

### Phase 3: UI & Overlay
- Designed 5-tier color-coded rating system
- Created frosted glass overlay with smooth transitions
- Added 3-second auto-fade timer

### Phase 4: OCR Enhancements
**Row-Grouping Extraction**:
- Implemented Y-coordinate clustering (2% vertical threshold)
- Sorts by X-coordinate within each row
- Handles large gaps between label text and values

**Focus & Stability**:
- Added macro mode support (triple camera)
- Continuous autofocus + subject area monitoring
- Continuous auto-exposure

**OCR Precision Tuning**:
- Switched to `.accurate` recognition level
- Enabled language correction
- Set `minimumTextHeight = 0.015` to filter noise
- Focused region of interest to center 70%

**Temporal Smoothing**:
- Implemented median filter (5-reading buffer)
- Separate median calculation for calories and protein
- Eliminates jitter from OCR variance

### Phase 5: Parser Refinements

#### Issue 1: Ratio Wrong by Factor of 100
**Problem**: Parser extracted "1" from "1 bottle" instead of "250" from calorie value
**Fix**: Extract ALL numbers from "Amount per serving" line, filter to calorie range (50-10000), select largest

#### Issue 2: Daily Value Pattern Not Detected
**Problem**: "140 % Daily Value*" appeared on separate line from "Calories"
**Fix**: Check previous line when "Calories" found without number, extract leading number from "daily" or "value" pattern

#### Issue 3: Row-Grouped Lines with Multiple Nutrients (Latest Fix)
**Problem**: Row-grouping created lines like "Calories Trans Fat 0g Cholesterol 50mg..." where "Calories" existed but no number immediately followed. Previous regex patterns required `calories?\s*(\d+)` - number had to be adjacent.

**Solution**: Complete algorithm refactor
1. Find "Calories" as word boundary (not requiring adjacent number)
2. Scan entire line for ANY number in calorie range
3. Don't require number to immediately follow "Calories"
4. Check adjacent lines if same-line scan fails
5. Filter all found numbers to 50-10000 range

**Test Results After Fix**:
- `nutrition label.webp`: "Calories 140" → 140 cal, 20g → **14.3 g/100cal** ✅
- `nutrition label1.webp`: "Calories 130 Alanine 1231 mg" → 130 cal, 25g → **19.2 g/100cal** ✅
- `nutrition label2.png`: "Amount per serving 250" + "Calories" → 250 cal, 20g → **8.0 g/100cal** ✅

## Testing

### Test Script: test_ocr.swift
Standalone Swift script that tests OCR and parsing against static images without running the full app. Mirrors production logic for `groupObservationsIntoRows()`, `parseCalories()`, and `parseProtein()`.

**Usage**:
```bash
swift test_ocr.swift
```

**Test Images**:
- `test_images/nutrition label.webp` - Standard vertical layout
- `test_images/nutrition label1.webp` - Complex label with amino acid profile
- `test_images/nutrition label2.png` - Shake bottle with condensed layout

## Common OCR Challenges & Solutions

| Challenge | Solution |
|-----------|----------|
| Large gaps between text and numbers | Row-grouping by Y-coordinate |
| "Calories" and value on different rows | Check adjacent lines (previous + next) |
| Multiple nutrients on same line | Find "Calories" word first, then scan for any number |
| Serving size confused with calories | Filter to calorie range (50-10000) |
| OCR typos ("Cal0ries", "Protiin") | Regex character classes `[io0]`, `[ei]` |
| Flickering values | Median filter over 5 readings |
| Glossy packaging reflection | Continuous autofocus + subject area monitoring |
| Fine print noise | `minimumTextHeight = 0.015` |

## Git Repository

**URL**: https://github.com/winniewuzl/ProteinScanner
**Owner**: winniewuzl
**Branch**: main

**Commit History**:
1. Initial commit: Base iOS app structure
2. Implemented OCR enhancements (row-grouping, focus, smoothing)
3. Fixed ratio calculation (extract all numbers, filter to calorie range)
4. Added Daily Value pattern detection
5. Refactored calorie parsing (find word first, scan for number)

## Known Limitations

1. **US Nutrition Labels Only**: Parser assumes "Nutrition Facts" format
2. **Portrait Only**: UI designed for vertical phone orientation
3. **English Only**: OCR language correction set to English
4. **Single Serving**: Doesn't handle multi-serving calculations
5. **No Barcode Fallback**: Relies entirely on OCR (no API lookup)

## Future Enhancements (Not Implemented)

- Multi-language support (EU nutrition labels)
- Barcode scanning with API fallback
- History tracking / favorites
- Landscape orientation support
- iPad optimization
- Settings panel (units, thresholds)
- Haptic feedback on detection
- Export/share functionality

## Debug Logging

All debug prints follow this format:
```
DEBUG: [Context]: [Details]
```

**Examples**:
```
DEBUG: Found nutrition label indicator: 'Nutrition Facts'
DEBUG: Checking line for calories: 'Calories 140'
DEBUG: Found 'Calories' word on line
DEBUG: Found calories on same line: 140
DEBUG: Parsed calories: 140
DEBUG: Found protein: 20g using pattern: protein\s*(\d+)\s*g?
DEBUG: Successfully created NutritionData
```

**OCR Output Format**:
```
=== OCR Output (Row-Grouped) ===
0: Nutrition Facts
1: Serving Size 1 Scoop (35 g)
2: Amount Per Serving
3: Calories 140
...
==================================
```

**Parsed Nutrition Format**:
```
=== Parsed Nutrition ===
Calories: 140
Protein: 20g
Ratio: 14.3 g/100cal
========================
```

## Agent Handoff Notes

This document provides complete context for any AI agent working on this codebase. All core functionality is implemented and tested. The latest refinement (calorie parsing refactor) ensures robust detection across various nutrition label layouts by finding the "Calories" keyword first, then scanning for any valid number on that line or adjacent lines.

**Current Status**: Fully functional, all test cases passing, production-ready
**Last Updated**: 2026-01-14
**Model Used**: Claude Sonnet 4.5 (claude-sonnet-4-5-20250929)
