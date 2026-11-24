// SPDX-License-Identifier: MIT
import Foundation

/// Optional local integration check. Input JSON: [{"uid": databaseSeriesUID, "file": localDICOMPath}].
/// Does not print or copy patient metadata, paths, or identifiers.
@main struct RealGroupingChecks {
    struct Source: Decodable { let uid: String; let file: String }
    static func main() throws {
        let sources = try JSONDecoder().decode([Source].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
        let records = Dictionary(grouping: sources, by: \.uid)
        let candidates = try records.map { uid, files in
            EchoSeriesCandidate(uid: uid, images: try files.map { try EchoDescriptor(header: DICOMHeader(url: URL(fileURLWithPath: $0.file))) })
        }
        guard let anchor = candidates.first?.images.first else { fatalError("No source images") }
        let groups = EchoGrouping.groups(candidates, matching: anchor)
        precondition(groups.count == 4 && groups.allSatisfy { $0.series.count == 10 })
        precondition(groups.reduce(0, { $0 + $1.sops.count }) == 40)
        for group in groups {
            let tes = group.series.map { String(format: "%.2f", $0.images[0].te) }.joined(separator: ", ")
            print(String(format: "Z %.2f mm", group.z) + " · \(group.series.count) phases · TE: " + tes)
        }
        print("OK · all 40 original files grouped into four unique 10-echo plans")
    }
}
