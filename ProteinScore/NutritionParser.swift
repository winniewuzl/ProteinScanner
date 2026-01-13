import Foundation

struct NutritionData: Equatable {
    let calories: Int
    let protein: Int

    var ratio: Double {
        guard calories > 0 else { return 0 }
        return (Double(protein) / Double(calories)) * 100
    }
}

class NutritionParser {
    static func parse(from textLines: [String]) -> NutritionData? {
        // First, check if we have "Nutrition Facts" to validate this is a nutrition label
        let hasNutritionFacts = textLines.contains { line in
            let normalized = line.lowercased().replacingOccurrences(of: " ", with: "")
            let hasMatch = normalized.contains("nutritionfacts") ||
                          normalized.contains("nutritlonfacts") ||
                          normalized.contains("nutrition")
            if hasMatch {
                print("DEBUG: Found nutrition label indicator: '\(line)'")
            }
            return hasMatch
        }

        if !hasNutritionFacts {
            print("DEBUG: No 'Nutrition Facts' found in text")
            return nil
        }

        // Parse calories
        let calories = parseCalories(from: textLines)
        print("DEBUG: Parsed calories: \(calories?.description ?? "nil")")

        // Parse protein
        let protein = parseProtein(from: textLines)
        print("DEBUG: Parsed protein: \(protein?.description ?? "nil")")

        // Only return if we found both values
        guard let cal = calories, let prot = protein else {
            print("DEBUG: Missing calories or protein, cannot create NutritionData")
            return nil
        }

        print("DEBUG: Successfully created NutritionData")
        return NutritionData(calories: cal, protein: prot)
    }

    private static func parseCalories(from lines: [String]) -> Int? {
        for line in lines {
            print("DEBUG: Checking line for calories: '\(line)'")

            // Try multiple patterns with increasing flexibility
            let patterns = [
                #"calories?\s*(\d+)"#,           // Basic: "Calories 100" or "Calorie 100"
                #"cal[o0]ries?\s*(\d+)"#,        // "Cal0ries 100"
                #"cal[o0]r[il1]es?\s*(\d+)"#,    // "Calori1s 100"
            ]

            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let nsRange = NSRange(line.startIndex..., in: line)
                    if let match = regex.firstMatch(in: line, range: nsRange),
                       let numberRange = Range(match.range(at: 1), in: line) {
                        if let number = Int(line[numberRange]), number > 0, number < 10000 {
                            print("DEBUG: Found calories: \(number) using pattern: \(pattern)")
                            return number
                        }
                    }
                }
            }
        }
        return nil
    }

    private static func parseProtein(from lines: [String]) -> Int? {
        for line in lines {
            print("DEBUG: Checking line for protein: '\(line)'")

            // Try multiple patterns with increasing flexibility
            let patterns = [
                #"protein\s*(\d+)\s*g?"#,          // Basic: "Protein 10g" or "Protein 10"
                #"pr[o0]tein\s*(\d+)\s*g?"#,       // "Pr0tein 10g"
                #"pr[o0]t[ei]in\s*(\d+)\s*g?"#,    // "Protiin 10g"
            ]

            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let nsRange = NSRange(line.startIndex..., in: line)
                    if let match = regex.firstMatch(in: line, range: nsRange),
                       let numberRange = Range(match.range(at: 1), in: line) {
                        if let number = Int(line[numberRange]), number >= 0, number < 1000 {
                            print("DEBUG: Found protein: \(number)g using pattern: \(pattern)")
                            return number
                        }
                    }
                }
            }
        }
        return nil
    }

    private static func extractNumber(from text: String) -> Int? {
        let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Int(numbers)
    }
}
