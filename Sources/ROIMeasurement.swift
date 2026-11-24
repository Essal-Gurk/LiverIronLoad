// SPDX-License-Identifier: MIT
import CoreGraphics
import Foundation

enum Region: String, CaseIterable, Identifiable {
    case liver1 = "L1", liver2 = "L2", liver3 = "L3"
    case muscleRight = "M1", muscleLeft = "M2"
    case spleen = "S", fat = "F", noise = "N", pancreas = "P", heart = "H"

    var id: String { rawValue }
    static let liver: [Self] = [.liver1, .liver2, .liver3]
    static let required: [Self] = liver + [.noise]
    static let drawingOrder: [Self] = liver + [.muscleRight, .muscleLeft, .spleen, .fat, .noise]

    static func next(after region: Self? = nil, occupied: Set<Self>) -> Self? {
        guard let region else { return drawingOrder.first { !occupied.contains($0) } }
        guard let index = drawingOrder.firstIndex(of: region) else { return nil }
        return drawingOrder[(index + 1)...].first { !occupied.contains($0) }
    }

    static func missingRequired(in occupied: Set<Self>) -> [Self] {
        required.filter { !occupied.contains($0) }
    }

    func label(in language: UILanguage) -> String { language.text("roi" + rawValue) }
    func tooltip(in language: UILanguage) -> String { language.text(Self.liver.contains(self) ? "tipROILiver" : "tipROI" + rawValue) }

    init?(roiName: String) {
        let normalized = Self.normalized(roiName)
        let key = normalized.hasPrefix("roi") ? String(normalized.dropFirst(3)) : normalized
        switch key {
        case "l1", "leber1", "liver1", "lasionleber1": self = .liver1
        case "l2", "leber2", "liver2", "lasionleber2": self = .liver2
        case "l3", "leber3", "liver3", "lasionleber3": self = .liver3
        case "m1", "muskel1", "muscle1", "mr": self = .muscleRight
        case "m2", "muskel2", "muscle2", "ml": self = .muscleLeft
        case "s", "s1", "milz", "spleen": self = .spleen
        case "p", "p1", "pankreas", "pancreas": self = .pancreas
        case "h", "h1", "herz", "heart": self = .heart
        case "f", "f1", "fett", "fat": self = .fat
        case "n", "n1", "rauschen", "noise", "hintergrundrauschen", "bildrauschen": self = .noise
        default:
            guard let region = Self.localizedAliases[key] else { return nil }
            self = region
        }
    }

    private static let localizedAliases: [String: Self] = {
        var aliases: [String: Self] = [:]
        for region in allCases {
            guard let translations = TranslationCatalog.plugin.rows["roi" + region.rawValue] else { continue }
            for name in translations.values {
                aliases[normalized(name)] = region
            }
        }
        return aliases
    }()

    private static func normalized(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                     locale: Locale(identifier: "de_DE"))
            .filter { !$0.isWhitespace && $0 != "-" && $0 != "_" }
    }
}

enum ROIShape {
    case oval(CGRect)
    case rectangle(CGRect)
    case polygon([CGPoint])

    var bounds: CGRect {
        switch self {
        case .oval(let rect), .rectangle(let rect): rect
        case .polygon(let points): Self.boundingBox(points)
        }
    }

    static func boundingBox(_ points: [CGPoint]) -> CGRect {
        guard !points.isEmpty, points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return .null }
        let x = points.map(\.x)
        let y = points.map(\.y)
        guard let left = x.min(), let right = x.max(), let top = y.min(), let bottom = y.max() else { return .null }
        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }

    func indices(width: Int, height: Int) throws -> [Int] {
        let rect = bounds
        guard !rect.isNull, rect.width >= 2, rect.height >= 2, rect.minX >= 0, rect.minY >= 0,
              rect.maxX <= Double(width), rect.maxY <= Double(height) else {
            throw QuantificationError("errROIOutside")
        }
        let polygon: CGPath?
        if case .polygon(let points) = self {
            let outline = CGMutablePath()
            outline.addLines(between: points)
            outline.closeSubpath()
            polygon = outline
        } else {
            polygon = nil
        }
        var output: [Int] = []
        for y in Int(floor(rect.minY))..<Int(ceil(rect.maxY)) {
            for x in Int(floor(rect.minX))..<Int(ceil(rect.maxX)) {
                let point = CGPoint(x: Double(x) + 0.5, y: Double(y) + 0.5)
                let enclosed: Bool
                switch self {
                case .oval:
                    let dx = (point.x - rect.midX) / (rect.width / 2)
                    let dy = (point.y - rect.midY) / (rect.height / 2)
                    enclosed = dx * dx + dy * dy <= 1
                case .rectangle:
                    enclosed = rect.contains(point)
                case .polygon:
                    enclosed = polygon?.contains(point, using: .evenOdd) == true
                }
                if enclosed { output.append(y * width + x) }
            }
        }
        guard output.count >= 12 else { throw QuantificationError("errROISize") }
        return output
    }
}

struct SignalStatistics {
    let mean: Double
    let sd: Double

    static func measure(pixels: [Float], indices: [Int]) throws -> Self {
        guard !indices.isEmpty else { throw QuantificationError("errROIEmpty") }
        var mean = 0.0
        var m2 = 0.0
        for (index, pixel) in indices.enumerated() {
            let value = Double(pixels[pixel])
            guard value.isFinite, value >= 0 else { throw QuantificationError("errROIPixel") }
            let delta = value - mean
            mean += delta / Double(index + 1)
            m2 += delta * (value - mean)
        }
        return Self(mean: mean, sd: sqrt(max(0, m2) / Double(indices.count)))
    }
}

struct ROIResult: Identifiable {
    let region: Region
    let center: CGPoint
    let signals: [SignalStatistics]
    let fit: LiverFit?
    let ironMg: Double?
    let issue: LocalizedMessage?
    var id: Region { region }
}

struct LiverSummary {
    let r2: Double
    let fatPercent: Double
    let ironMg: Double?

    init?(_ rows: [ROIResult]) {
        let liver = rows.filter { Region.liver.contains($0.region) }
        guard Set(liver.map(\.region)).count == 3, liver.count == 3 else { return nil }
        let fits = liver.compactMap(\.fit)
        guard fits.count == 3 else { return nil }
        r2 = fits.map(\.r2).reduce(0, +) / 3
        fatPercent = fits.map(\.fatFraction).reduce(0, +) * 100 / 3
        let iron = liver.compactMap(\.ironMg)
        ironMg = iron.count == 3 ? iron.reduce(0, +) / 3 : nil
    }

    var ironCategory: String? {
        guard let ironMg else { return nil }
        switch ironMg {
        case ..<1.8: return "ironNormal"
        case ..<3.2: return "ironBorder"
        case ..<7: return "ironMild"
        case ...15: return "ironModerate"
        default: return "ironHigh"
        }
    }
}

