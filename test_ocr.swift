#!/usr/bin/env swift

import Foundation
import Vision
import CoreImage
import AppKit

// Helper to group observations into rows (same logic as app)
struct TextItem {
    let text: String
    let midY: CGFloat
    let minX: CGFloat
}

func groupObservationsIntoRows(_ observations: [VNRecognizedTextObservation]) -> [String] {
    let items: [TextItem] = observations.compactMap { observation in
        guard let text = observation.topCandidates(1).first?.string else { return nil }
        let bounds = observation.boundingBox
        let midY = bounds.midY
        let minX = bounds.minX
        return TextItem(text: text, midY: midY, minX: minX)
    }

    guard !items.isEmpty else { return [] }

    let sortedByY = items.sorted { $0.midY > $1.midY }

    var rows: [[TextItem]] = []
    let verticalThreshold: CGFloat = 0.02

    for item in sortedByY {
        if let lastRow = rows.last,
           let lastItem = lastRow.first,
           abs(item.midY - lastItem.midY) < verticalThreshold {
            rows[rows.count - 1].append(item)
        } else {
            rows.append([item])
        }
    }

    let joinedRows = rows.map { row -> String in
        let sortedRow = row.sorted { $0.minX < $1.minX }
        return sortedRow.map { $0.text }.joined(separator: " ")
    }

    return joinedRows
}

func parseCalories(from lines: [String]) -> Int? {
    for (index, line) in lines.enumerated() {
        let patterns = [
            #"calories?\s*(\d+)"#,
            #"cal[o0]ries?\s*(\d+)"#,
            #"cal[o0]r[il1]es?\s*(\d+)"#,
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsRange = NSRange(line.startIndex..., in: line)
                if let match = regex.firstMatch(in: line, range: nsRange),
                   let numberRange = Range(match.range(at: 1), in: line) {
                    if let number = Int(line[numberRange]), number > 0, number < 10000 {
                        return number
                    }
                }
            }
        }

        // Check if current line says "Calories" without a number
        // and look at previous line for "Amount per serving XXX"
        if line.lowercased().contains("calories") || line.lowercased().contains("calorie") {
            if index > 0 {
                let previousLine = lines[index - 1]
                if previousLine.lowercased().contains("amount") && previousLine.lowercased().contains("serving") {
                    if let regex = try? NSRegularExpression(pattern: #"\d+"#, options: []) {
                        let nsRange = NSRange(previousLine.startIndex..., in: previousLine)
                        let matches = regex.matches(in: previousLine, range: nsRange)

                        var numbers: [Int] = []
                        for match in matches {
                            if let numberRange = Range(match.range, in: previousLine),
                               let number = Int(previousLine[numberRange]) {
                                numbers.append(number)
                            }
                        }

                        // Filter numbers that could be calories (typically 50-1000)
                        // and take the largest one
                        let calorieNumbers = numbers.filter { $0 >= 50 && $0 < 10000 }
                        if let largest = calorieNumbers.max() {
                            return largest
                        }
                    }
                }
            }
        }
    }
    return nil
}

func parseProtein(from lines: [String]) -> Int? {
    for line in lines {
        let patterns = [
            #"protein\s*(\d+)\s*g?"#,
            #"pr[o0]tein\s*(\d+)\s*g?"#,
            #"pr[o0]t[ei]in\s*(\d+)\s*g?"#,
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsRange = NSRange(line.startIndex..., in: line)
                if let match = regex.firstMatch(in: line, range: nsRange),
                   let numberRange = Range(match.range(at: 1), in: line) {
                    if let number = Int(line[numberRange]), number >= 0, number < 1000 {
                        return number
                    }
                }
            }
        }
    }
    return nil
}

func testImage(at path: String) {
    print("\n" + String(repeating: "=", count: 80))
    print("Testing: \(URL(fileURLWithPath: path).lastPathComponent)")
    print(String(repeating: "=", count: 80))

    guard let image = NSImage(contentsOfFile: path),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("❌ Failed to load image")
        return
    }

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.minimumTextHeight = 0.015

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

    do {
        try handler.perform([request])

        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            print("❌ No text recognized")
            return
        }

        print("\n📝 Raw OCR output (\(observations.count) items):")
        for (i, obs) in observations.enumerated() {
            if let text = obs.topCandidates(1).first?.string {
                print("  \(i): \(text)")
            }
        }

        let groupedRows = groupObservationsIntoRows(observations)
        print("\n🔄 Row-Grouped output (\(groupedRows.count) rows):")
        for (i, row) in groupedRows.enumerated() {
            print("  \(i): \(row)")
        }

        // Check for nutrition facts
        let hasNutrition = groupedRows.contains { line in
            let normalized = line.lowercased().replacingOccurrences(of: " ", with: "")
            return normalized.contains("nutrition")
        }

        print("\n🔍 Nutrition Facts detected: \(hasNutrition ? "✅ YES" : "❌ NO")")

        if let calories = parseCalories(from: groupedRows) {
            print("🔥 Calories: \(calories)")
        } else {
            print("❌ Calories: NOT FOUND")
        }

        if let protein = parseProtein(from: groupedRows) {
            print("💪 Protein: \(protein)g")
        } else {
            print("❌ Protein: NOT FOUND")
        }

        if let calories = parseCalories(from: groupedRows),
           let protein = parseProtein(from: groupedRows) {
            let ratio = (Double(protein) / Double(calories)) * 100
            print("\n✨ RESULT: \(String(format: "%.1f", ratio)) g protein / 100 cal")
        } else {
            print("\n❌ FAILED: Could not extract both values")
        }

    } catch {
        print("❌ Error performing OCR: \(error)")
    }
}

// Test all images
let basePath = "/Users/thomasriedl/Desktop/ProteinScore/test_images"
testImage(at: "\(basePath)/nutrition label.webp")
testImage(at: "\(basePath)/nutrition label1.webp")
testImage(at: "\(basePath)/nutrition label2.png")

print("\n" + String(repeating: "=", count: 80))
print("Testing complete!")
print(String(repeating: "=", count: 80))
