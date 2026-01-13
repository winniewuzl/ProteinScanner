# ProteinScore

An iOS app that scans US nutrition labels using OCR and displays a protein-to-calorie ratio with color-coded feedback.

## Features

- **Instant Camera Launch**: Opens directly to camera view
- **Real-time OCR**: Uses Vision framework to read nutrition labels
- **Protein Scoring**: Calculates grams of protein per 100 calories
- **Color-Coded Feedback**: Visual rating from Excellent (green) to Poor (red)
- **Smooth Transitions**: Fade in/out animations for overlay

## Scoring System

The app calculates: `(protein grams / calories) × 100`

| Score | Rating | Color | Examples |
|-------|--------|-------|----------|
| 15+ | Excellent | Green | Greek yogurt, chicken breast |
| 10-15 | Good | Light green | Eggs, cottage cheese |
| 5-10 | Moderate | Yellow | Milk, protein bars |
| 2-5 | Low | Orange | Bread, pasta |
| <2 | Poor | Red | Chips, cookies |

## Technical Stack

- Swift + SwiftUI
- AVFoundation for camera
- Vision framework for OCR
- iOS 16+
- No external dependencies

## Project Structure

```
ProteinScore/
├── ProteinScoreApp.swift       # App entry point
├── ContentView.swift            # Root view
├── CameraView.swift             # Camera preview + overlay
├── CameraViewModel.swift        # Camera/OCR logic
├── NutritionParser.swift        # Text parsing
├── ProteinScore.swift           # Scoring system
├── NutritionOverlayView.swift   # Overlay UI
└── Info.plist                   # Camera permissions
```

## How It Works

1. Camera fills screen on launch
2. OCR processes center 70% of frame every 0.5 seconds
3. Parser looks for "Nutrition Facts" header to validate label
4. Extracts calories and protein values (handles OCR errors)
5. Calculates ratio and displays color-coded overlay
6. Overlay fades out after 3 seconds of no detection

## Building

1. Open `ProteinScore.xcodeproj` in Xcode
2. Select a target device or simulator
3. Build and run (⌘R)

**Note**: Camera functionality requires a physical iOS device.

## Implementation Phases

- ✅ Phase 1: Camera preview with OCR logging
- ✅ Phase 2: Parse nutrition values from OCR
- ✅ Phase 3: Overlay with ratio, score, and color
- ✅ Phase 4: Smooth transitions and edge case handling

## Future Enhancements (Not Implemented)

- Barcode scanning
- API lookups for products
- History/logging
- Settings panel
- Multiple language support
