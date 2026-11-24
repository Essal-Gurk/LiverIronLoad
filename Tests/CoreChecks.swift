// SPDX-License-Identifier: MIT
import Foundation

@main
struct CoreChecks {
    static func main() throws {
        checkEchoGrouping()
        try checkROIs()
        checkROIWorkflow()
        try checkTranslations()
        for (tesla, r2, fraction) in [(1.5, 65.0, 0.0), (1.5, 112.0, 0.24),
                                       (2.89, 305.0, 0.34), (3.0, 495.0, 0.11)] {
            let samples = signals(tesla: tesla, r2: r2, fat: fraction, interval: 0.9)
            let result = try LiverQuantification.fit(samples.reversed(), tesla: tesla)
            precondition(abs(result.r2 - r2) < 0.5)
            precondition(abs(result.fatFraction - fraction) < 0.002)
            precondition(result.residual < 0.002)
        }

        let dataset = signals(tesla: 1.5, r2: 95, fat: 0.14, interval: 0.9)
        try LiverQuantification.validate(dataset, tesla: 1.5)
        try expectRejection("preflight rejects masked noise ROI") {
            let masked = dataset.map { EchoSignal(milliseconds: $0.milliseconds, magnitude: $0.magnitude, background: 0) }
            try LiverQuantification.validate(masked, tesla: 1.5)
        }
        try expectRejection("preflight rejects insufficient usable echoes") {
            try LiverQuantification.validate(Array(dataset.prefix(5)), tesla: 1.5)
        }
        try expectRejection("insufficient echoes") {
            _ = try LiverQuantification.fit(Array(dataset.prefix(5)), tesla: 1.5)
        }
        try expectRejection("duplicate echo time") {
            _ = try LiverQuantification.fit(dataset + [dataset[0]], tesla: 1.5)
        }
        try expectRejection("all signal at noise level") {
            _ = try LiverQuantification.fit(dataset.map {
                EchoSignal(milliseconds: $0.milliseconds, magnitude: 3, background: 2)
            }, tesla: 1.5)
        }
        try expectRejection("insufficient water/fat encoding") {
            _ = try LiverQuantification.fit(signals(tesla: 3, r2: 55, fat: 0.18, first: 2.302, interval: 2.302), tesla: 3)
        }
        try expectRejection("decay too fast for TE1") {
            _ = try LiverQuantification.fit(signals(tesla: 3, r2: 620, fat: 0.21, first: 1.1, interval: 0.65), tesla: 3)
        }
        precondition(FieldStrength(tesla: 2) == nil)
        precondition(abs(FieldStrength.onePointFive.estimatedIron(r2: 100) - 2.443) < 1e-10)
        precondition(abs(FieldStrength.twoPointEightNine.estimatedIron(r2: 100) - 1.37) < 1e-10)
        precondition(abs(FieldStrength.three.estimatedIron(r2: 100) - 1.319) < 1e-10)

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("source.dcm")
        for syntax in ["1.2.840.10008.1.2.1", "1.2.840.10008.1.2"] {
            try dicom(syntax: syntax).write(to: url)
            let header = try DICOMHeader(url: url)
            try header.verifySource()
            precondition(header.echo == 2.3 && header.tesla == 1.5 && header.flip == 20)
            precondition(header.sop == "1.2.3.4" && header.frameOfReference == "1.2.3.5")
        }
        for (name, type, scan, mode, syntax) in [
            ("phase", "ORIGINAL\\PRIMARY\\P", "", "2D", "1.2.840.10008.1.2.1"),
            ("derived", "DERIVED\\PRIMARY\\M", "", "2D", "1.2.840.10008.1.2.1"),
            ("fat saturation", "ORIGINAL\\PRIMARY\\M", "FS", "2D", "1.2.840.10008.1.2.1"),
            ("3D", "ORIGINAL\\PRIMARY\\M", "", "3D", "1.2.840.10008.1.2.1"),
            ("lossy JPEG", "ORIGINAL\\PRIMARY\\M", "", "2D", "1.2.840.10008.1.2.4.50")
        ] {
            try dicom(syntax: syntax, imageType: type, scanOptions: scan, mode: mode).write(to: url)
            try expectRejection(name) { try DICOMHeader(url: url).verifySource() }
        }
        try Data(repeating: 0, count: 150).write(to: url)
        try expectRejection("invalid preamble") { _ = try DICOMHeader(url: url) }
        print("OK · synthetische Fits, Ausschlussfälle, Kalibrierung und klassische DICOM-Header")
    }

    static func checkTranslations() throws {
        let content = try String(contentsOfFile: "Resources/Translations.tsv", encoding: .utf8)
        let lines = content.split(whereSeparator: \.isNewline).filter { !$0.hasPrefix("#") }
        let catalog = TranslationCatalog(content)
        precondition(catalog.rows.count == lines.count, "Translation keys must be unique and every row must have ten columns")
        let placeholders = try Regex("\\{[0-9]+\\}")
        for (key, values) in catalog.rows {
            precondition(values.count == 10 && values.values.allSatisfy { !$0.isEmpty }, "Missing translation for \(key)")
            let expected = values[.de]?.matches(of: placeholders).map { String($0.0) }.sorted()
            for value in values.values {
                precondition(value.matches(of: placeholders).map { String($0.0) }.sorted() == expected,
                             "Placeholder mismatch for \(key)")
            }
        }
        precondition(UILanguage.preferred(from: ["nl-NL", "zh-TW", "en-US"]) == .zh)
        precondition(UILanguage.preferred(from: ["nl-NL"]) == .en)
        precondition(UILanguage.allCases.count == 10)
        precondition(UILanguage.preferred(from: ["tr-TR"]) == .tr)
        precondition(UILanguage.preferred(from: ["ar-SA"]) == .ar)
        precondition(catalog.text("roiL1", in: .tr) == "Karaciğer 1")
        precondition(catalog.text("roiL1", in: .ar) == "الكبد 1")
        precondition(catalog.text("errCount", in: .ja, values: ["6"]).contains("6個"))
        precondition(catalog.text("imageDetails", in: .en, values: ["Series {1}", "9", "3 T", "10", "120", "20"])
            .hasPrefix("Series {1} · Viewer image 9"))
        precondition(UILanguage.de.number(2.5).contains(","))
        precondition(UILanguage.en.number(2.5).contains("."))
        print("OK · Localization in ten languages, system fallback and placeholders")
    }

    static func checkROIWorkflow() {
        let expected: [Region] = [.liver1, .liver2, .liver3, .muscleRight, .muscleLeft, .spleen, .fat, .noise]
        var present: Set<Region> = []
        var active: Region?
        for next in expected {
            precondition(Region.next(after: active, occupied: present) == next)
            present.insert(next)
            active = next
        }
        precondition(Region.next(after: .noise, occupied: present) == nil)
        precondition(Region.next(after: .liver3, occupied: [.muscleRight, .muscleLeft]) == .spleen)
        precondition(Region.missingRequired(in: [.liver1, .liver2, .noise]) == [.liver3])
        precondition(Region.missingRequired(in: [.liver1, .liver2, .liver3, .noise]).isEmpty)
        precondition(Region(roiName: "ROI Leber 1") == .liver1)
        precondition(Region(roiName: "Läsion Leber 3") == .liver3)
        precondition(Region(roiName: "Bildrauschen") == .noise)
        print("OK · ROI progression, required regions and viewer labels")
    }

    static func checkROIs() throws {
        let aliases: [(String, Region)] = [("  Liver 1 ", .liver1), ("LEBER-2", .liver2), ("l3", .liver3),
            ("Muscle 1", .muscleRight), ("Muskel_2", .muscleLeft), ("spleen", .spleen), ("s1", .spleen),
            ("p", .pancreas), ("Herz", .heart), ("heart", .heart), ("Fat", .fat), ("n", .noise)]
        precondition(aliases.allSatisfy { Region(roiName: $0.0) == $0.1 })
        precondition(Region(roiName: "liver 10") == nil)
        let points = [CGPoint(x: 1, y: 1), CGPoint(x: 7, y: 1), CGPoint(x: 7, y: 7), CGPoint(x: 1, y: 7)]
        let box = CGRect(x: 1, y: 1, width: 6, height: 6)
        let rectangle = try ROIShape.rectangle(box).indices(width: 10, height: 10)
        let polygon = try ROIShape.polygon(points).indices(width: 10, height: 10)
        let oval = try ROIShape.oval(box).indices(width: 10, height: 10)
        precondition(polygon == rectangle && rectangle.count == 36 && oval.count < rectangle.count)
        try expectRejection("ROI outside image") {
            _ = try ROIShape.oval(CGRect(x: -2, y: 1, width: 5, height: 5)).indices(width: 10, height: 10)
        }
        let stats = try SignalStatistics.measure(pixels: [1, 2, 3, 4], indices: [1, 3])
        precondition(stats.mean == 3 && stats.sd == 1)

        let rows = zip(Region.liver, [50.0, 100.0, 150.0]).map { region, r2 in
            ROIResult(region: region, center: .zero, signals: [],
                      fit: LiverFit(r2: r2, fatFraction: 0.1, residual: 0, usedEchoes: 10),
                      ironMg: FieldStrength.onePointFive.estimatedIron(r2: r2), issue: nil)
        }
        let summary = LiverSummary(rows)
        precondition(summary?.r2 == 100 && abs((summary?.fatPercent ?? 0) - 10) < 1e-10)
        precondition(abs((summary?.ironMg ?? 0) - 2.443) < 1e-10)
        precondition(summary?.ironCategory == "ironBorder")
        precondition(LiverSummary(Array(rows.prefix(2))) == nil)
    }

    static func expectRejection(_ label: String, operation: () throws -> Void) throws {
        do {
            try operation()
            fatalError("Expected rejection: \(label)")
        } catch is QuantificationError {}
    }

    static func signals(tesla: Double, r2: Double, fat: Double, first: Double = 0.8, interval: Double) -> [EchoSignal] {
        (0..<16).map { index in
            let te = first + Double(index) * interval
            let t = te / 1000
            let angle = 2 * Double.pi * 42.57747892 * tesla * t
            let relativeShifts = [-3.8, -3.4, -2.6]
            let intensities = [8.8, 70.0, 12.0]
            let real = zip(relativeShifts, intensities).reduce(0.0) { $0 + $1.1 * cos(angle * $1.0) } / 90.8
            let imaginary = zip(relativeShifts, intensities).reduce(0.0) { $0 + $1.1 * sin(angle * $1.0) } / 90.8
            let signal = 1000 * hypot(1 - fat + fat * real, fat * imaginary) / exp(r2 * t)
            return EchoSignal(milliseconds: te, magnitude: max(3, signal), background: 3)
        }
    }

    static func dicom(syntax: String, imageType: String = "ORIGINAL\\PRIMARY\\M", scanOptions: String = "",
                      mode: String = "2D") -> Data {
        var data = Data(repeating: 0, count: 128)
        data.append(contentsOf: "DICM".utf8)
        func put16(_ value: UInt16) {
            data.append(UInt8(truncatingIfNeeded: value))
            data.append(UInt8(truncatingIfNeeded: value >> 8))
        }
        func put32(_ value: UInt32) {
            put16(UInt16(truncatingIfNeeded: value))
            put16(UInt16(truncatingIfNeeded: value >> 16))
        }
        func element(_ group: UInt16, _ key: UInt16, _ vr: String, _ text: String) {
            put16(group)
            put16(key)
            var contents = Data(text.utf8)
            if contents.count % 2 == 1 { contents.append(vr == "UI" ? 0 : 32) }
            if group == 2 || syntax != "1.2.840.10008.1.2" {
                data.append(contentsOf: vr.utf8)
                put16(UInt16(contents.count))
            } else { put32(UInt32(contents.count)) }
            data.append(contents)
        }
        element(2, 0x10, "UI", syntax)
        element(8, 8, "CS", imageType)
        element(8, 0x16, "UI", "1.2.840.10008.5.1.4.1.1.4")
        element(8, 0x18, "UI", "1.2.3.4")
        element(0x18, 0x20, "CS", "GR")
        element(0x18, 0x21, "CS", "SP")
        element(0x18, 0x22, "CS", scanOptions)
        element(0x18, 0x23, "CS", mode)
        element(0x18, 0x24, "SH", "gre")
        element(0x18, 0x80, "DS", "120")
        element(0x18, 0x81, "DS", "2.3")
        element(0x18, 0x87, "DS", "1.5")
        element(0x18, 0x1314, "DS", "20")
        element(0x20, 0x32, "DS", "0\\0\\1")
        element(0x20, 0x37, "DS", "1\\0\\0\\0\\1\\0")
        element(0x20, 0x52, "UI", "1.2.3.5")
        element(0x28, 0x30, "DS", "1.4\\1.4")
        element(0x28, 0x2110, "CS", "00")
        put16(0x7fe0)
        put16(0x10)
        put32(0)
        return data
    }
}
