import Foundation

struct UnitConverter {

    // MARK: - Main

    static func applyConversion(to text: String) -> String {
        var output = text

        // 길이
        output = convert(in: output, pattern: #"(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:miles|mile)\b"#, unit: "miles") { miles in
            let km = miles * 1.60934
            return formatNumber(km) + "km"
        }
        output = convert(in: output, pattern: #"(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:inches|inch|in\.)\b"#, unit: "inch") { inches in
            let cm = inches * 2.54
            return formatNumber(cm) + "cm"
        }
        output = convert(in: output, pattern: #"(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:feet|foot|ft)\b"#, unit: "ft") { feet in
            let m = feet * 0.3048
            return formatNumber(m) + "m"
        }
        output = convert(in: output, pattern: #"(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:yards|yard|yd)\b"#, unit: "yd") { yards in
            let m = yards * 0.9144
            return formatNumber(m) + "m"
        }

        // 무게
        output = convert(in: output, pattern: #"(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:pounds|pound|lbs|lb)\b"#, unit: "lb") { lb in
            let kg = lb * 0.453592
            return formatNumber(kg) + "kg"
        }
        output = convert(in: output, pattern: #"(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:ounces|ounce|oz)\b"#, unit: "oz") { oz in
            let g = oz * 28.3495
            return formatNumber(g) + "g"
        }

        // 온도
        output = convertTemperature(in: output)

        // 면적
        output = convert(in: output, pattern: #"(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:square feet|sq\.?\s*ft|sqft)\b"#, unit: "sqft") { sqft in
            let pyeong = sqft * 0.0281
            return formatNumber(pyeong) + "평"
        }
        output = convert(in: output, pattern: #"(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:square meters|square meter|sq\.?\s*m|m²|㎡)"#, unit: "sqm") { sqm in
            let pyeong = sqm * 0.3025
            return formatNumber(pyeong) + "평"
        }
        output = convert(in: output, pattern: #"(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:acres|acre)\b"#, unit: "acre") { acre in
            let pyeong = acre * 1224.17
            return formatNumber(pyeong) + "평"
        }

        // 부피
        output = convert(in: output, pattern: #"(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:gallons|gallon|gal)\b"#, unit: "gal") { gal in
            let liter = gal * 3.78541
            return formatNumber(liter) + "L"
        }

        return output
    }

    // MARK: - Generic Converter

    private static func convert(
        in text: String,
        pattern: String,
        unit: String,
        converter: (Double) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return text
        }

        var output = text
        let nsText = output as NSString
        let matches = regex.matches(in: output, range: NSRange(location: 0, length: nsText.length))

        for match in matches.reversed() {
            let fullMatch = nsText.substring(with: match.range)

            let afterIndex = match.range.location + match.range.length
            if afterIndex < nsText.length {
                let nextChar = nsText.character(at: afterIndex)
                if nextChar == Character("(").asciiValue! {
                    continue
                }
            }

            let beforeText = nsText.substring(to: match.range.location)
            let openCount = beforeText.filter({ $0 == "(" }).count
            let closeCount = beforeText.filter({ $0 == ")" }).count
            if openCount > closeCount {
                continue
            }

            let numberRange = match.range(at: 1)
            let numberStr = nsText.substring(with: numberRange).replacingOccurrences(of: ",", with: "")

            guard let value = Double(numberStr) else { continue }

            let converted = converter(value)
            let replacement = "\(fullMatch)(\(converted))"

            output = (output as NSString).replacingCharacters(in: match.range, with: replacement)
        }

        return output
    }

    // MARK: - Temperature

    private static func convertTemperature(in text: String) -> String {
        var output = text

        if let regex = try? NSRegularExpression(pattern: #"(\d+(?:,\d+)*(?:\.\d+)?)\s*°?\s*(?:fahrenheit|F)\b"#, options: .caseInsensitive) {
            let nsText = output as NSString
            let matches = regex.matches(in: output, range: NSRange(location: 0, length: nsText.length))

            for match in matches.reversed() {
                let afterIndex = match.range.location + match.range.length
                if afterIndex < nsText.length && nsText.character(at: afterIndex) == Character("(").asciiValue! {
                    continue
                }

                let numberStr = nsText.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "")
                guard let f = Double(numberStr) else { continue }
                let c = (f - 32) * 5.0 / 9.0
                let fullMatch = nsText.substring(with: match.range)
                let replacement = "\(fullMatch)(\(formatNumber(c))°C)"
                output = (output as NSString).replacingCharacters(in: match.range, with: replacement)
            }
        }

        if let regex = try? NSRegularExpression(pattern: #"(\d+(?:,\d+)*(?:\.\d+)?)\s*°?\s*(?:celsius|C)\b"#, options: .caseInsensitive) {
            let nsText = output as NSString
            let matches = regex.matches(in: output, range: NSRange(location: 0, length: nsText.length))

            for match in matches.reversed() {
                let afterIndex = match.range.location + match.range.length
                if afterIndex < nsText.length && nsText.character(at: afterIndex) == Character("(").asciiValue! {
                    continue
                }

                let beforeText = (output as NSString).substring(to: match.range.location)
                let openCount = beforeText.filter({ $0 == "(" }).count
                let closeCount = beforeText.filter({ $0 == ")" }).count
                if openCount > closeCount {
                    continue
                }

                let numberStr = nsText.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "")
                guard let c = Double(numberStr) else { continue }
                let f = c * 9.0 / 5.0 + 32
                let fullMatch = nsText.substring(with: match.range)
                let replacement = "\(fullMatch)(\(formatNumber(f))°F)"
                output = (output as NSString).replacingCharacters(in: match.range, with: replacement)
            }
        }

        return output
    }

    // MARK: - Number Formatting

    private static func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","

        if value < 10 && value != value.rounded() {
            formatter.maximumFractionDigits = 1
        } else {
            formatter.maximumFractionDigits = 0
        }

        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }
}
