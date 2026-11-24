// SPDX-License-Identifier: MIT
import Foundation

/// Reads only the top-level fields needed to screen classic MR source images.
struct DICOMHeader {
    private let values: [UInt32: String]

    var sop: String? { values[0x00080018] }
    var frameOfReference: String? { values[0x00200052] }
    var acquisition: String? { values[0x00200012] }
    var echo: Double? { number(0x00180081) }
    var repetition: Double? { number(0x00180080) }
    var flip: Double? { number(0x00181314) }
    var tesla: Double? { number(0x00180087) }
    var sequence: String? { values[0x00180024] }
    var columns: Int? { number(0x00280011).map(Int.init) }
    var rows: Int? { number(0x00280010).map(Int.init) }
    var position: [Double]? { numbers(0x00200032, count: 3) }
    var orientation: [Double]? { numbers(0x00200037, count: 6) }
    var spacing: [Double]? { numbers(0x00280030, count: 2) }
    var thickness: Double? { number(0x00180050) }

    private func numbers(_ tag: UInt32, count: Int) -> [Double]? {
        guard let parts = values[tag]?.split(separator: "\\"), parts.count == count else { return nil }
        let numbers = parts.compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        return numbers.count == count && numbers.allSatisfy(\.isFinite) ? numbers : nil
    }

    func verifySource() throws {
        let type = Set((values[0x00080008] ?? "").uppercased().split(separator: "\\"))
        let variant = Set((values[0x00180021] ?? "").uppercased().split(separator: "\\"))
        let options = Set((values[0x00180022] ?? "").uppercased().split(separator: "\\"))
        let complex = values[0x00089208]?.uppercased()
        guard values[0x00080016] == "1.2.840.10008.5.1.4.1.1.4",
              (values[0x00280008] ?? "1") == "1",
              values[0x00180023] == "2D",
              !options.contains("FS"), !variant.contains("FS"),
              type.contains("ORIGINAL"), type.contains("PRIMARY"),
              type.isDisjoint(with: ["P", "PHASE", "R", "REAL", "I", "IMAGINARY", "MOSAIC", "WATER", "FAT", "ADC", "T2_STAR_MAP"]),
              complex == nil || complex == "MAGNITUDE",
              values[0x00282110] != "01",
              values[0x00180010]?.isEmpty != false,
              vector(0x00200032, count: 3),
              vector(0x00200037, count: 6),
              vector(0x00280030, count: 2, positive: true),
              values[0x00180020]?.uppercased().split(separator: "\\").contains("GR") == true,
              frameOfReference?.isEmpty == false,
              let echo, echo.isFinite, echo > 0, echo < 100,
              let repetition, let flip, repetition.isFinite, flip.isFinite,
              repetition > echo, flip > 0, flip < 90
        else {
            throw QuantificationError("errMagnitude")
        }
    }

    private func number(_ key: UInt32) -> Double? { values[key].flatMap(Double.init) }

    private func vector(_ key: UInt32, count: Int, positive: Bool = false) -> Bool {
        guard let components = values[key]?.split(separator: "\\"), components.count == count else { return false }
        return components.allSatisfy {
            guard let number = Double($0.trimmingCharacters(in: .whitespaces)), number.isFinite else { return false }
            return !positive || number > 0
        }
    }

    init(url: URL) throws {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let data = try file.read(upToCount: 2 * 1024 * 1024) ?? Data()
        let bytes = Array(data)
        guard bytes.count >= 132, bytes[128..<132].elementsEqual([68, 73, 67, 77]) else {
            throw QuantificationError("errPreamble")
        }

        let wanted: Set<UInt32> = [
            0x00020010, 0x00080008, 0x00080016, 0x00080018, 0x00089208,
            0x00180010, 0x00180020, 0x00180021, 0x00180022, 0x00180023, 0x00180024,
            0x00180050, 0x00180080, 0x00180081, 0x00180087, 0x00181314,
            0x00200012, 0x00200032, 0x00200037, 0x00200052, 0x00280008, 0x00280010, 0x00280011, 0x00280030, 0x00282110
        ]

        var found: [UInt32: String] = [:]
        var cursor = 132
        var inMeta = true
        var explicit = true
        var undefinedContainers: [UInt16] = []
        var hasPixelData = false

        func u16(_ i: Int) -> UInt16 {
            UInt16(bytes[i]) | (UInt16(bytes[i + 1]) << 8)
        }
        func u32(_ i: Int) -> UInt32 {
            UInt32(u16(i)) | (UInt32(u16(i + 2)) << 16)
        }

        while cursor + 8 <= bytes.count {
            let group = u16(cursor)
            let element = u16(cursor + 2)
            if inMeta && group != 2 {
                inMeta = false
                switch found[0x00020010] {
                case "1.2.840.10008.1.2": explicit = false
                case "1.2.840.10008.1.2.1", "1.2.840.10008.1.2.5": break
                case "1.2.840.10008.1.2.4.57", "1.2.840.10008.1.2.4.70",
                     "1.2.840.10008.1.2.4.80", "1.2.840.10008.1.2.4.90",
                     "1.2.840.10008.1.2.4.201", "1.2.840.10008.1.2.4.202": break
                default: throw QuantificationError("errSyntax")
                }
            }
            if group == 0x7fe0 && element == 0x0010 && undefinedContainers.isEmpty {
                hasPixelData = true
                break
            }

            let length: UInt32
            let vr: String
            if explicit && group != 0xfffe {
                vr = String(decoding: bytes[(cursor + 4)..<(cursor + 6)], as: UTF8.self)
                if ["OB", "OD", "OF", "OL", "OV", "OW", "SQ", "SV", "UC", "UN", "UR", "UT", "UV"].contains(vr) {
                    guard cursor + 12 <= bytes.count else { break }
                    length = u32(cursor + 8)
                    cursor += 12
                } else {
                    length = UInt32(u16(cursor + 6))
                    cursor += 8
                }
            } else {
                vr = ""
                length = u32(cursor + 4)
                cursor += 8
            }

            if group == 0xfffe && (element == 0xe00d || element == 0xe0dd) {
                guard length == 0, undefinedContainers.last == element else { break }
                undefinedContainers.removeLast()
                continue
            }
            if length == UInt32.max {
                if group == 0xfffe && element == 0xe000 {
                    undefinedContainers.append(0xe00d)
                } else if !explicit || vr == "SQ" || vr == "UN" {
                    undefinedContainers.append(0xe0dd)
                } else { break }
                continue
            }
            let count = Int(length)
            guard count <= bytes.count - cursor else { break }
            let tag = UInt32(group) << 16 | UInt32(element)
            if undefinedContainers.isEmpty && wanted.contains(tag) {
                guard count <= 1024, found[tag] == nil else { break }
                if [UInt32(0x00280010), 0x00280011].contains(tag), count == 2 {
                    found[tag] = String(u16(cursor))
                } else {
                    found[tag] = String(decoding: bytes[cursor..<(cursor + count)], as: UTF8.self)
                        .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.controlCharacters))
                }
            }
            cursor += count
        }

        guard hasPixelData else { throw QuantificationError("errHeader") }
        values = found
    }
}
