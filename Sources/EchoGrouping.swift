// SPDX-License-Identifier: MIT
import Foundation

/// Header-only planning: no pixel reads, viewer handles, or changes to the database.
struct EchoDescriptor {
    let sop: String
    let frame: String
    let sequence: String
    let acquisition: String
    let te: Double
    let tesla: Double
    let repetition: Double
    let flip: Double
    let columns: Int
    let rows: Int
    let position: [Double]
    let orientation: [Double]
    let spacing: [Double]
    let thickness: Double

    init(header: DICOMHeader) throws {
        try header.verifySource()
        guard let sop = header.sop, let frame = header.frameOfReference,
              let sequence = header.sequence, let acquisition = header.acquisition,
              let te = header.echo, let tesla = header.tesla, FieldStrength(tesla: tesla) != nil,
              let repetition = header.repetition, let flip = header.flip,
              let columns = header.columns, let rows = header.rows, columns > 0, rows > 0,
              let position = header.position, let orientation = header.orientation,
              let spacing = header.spacing, spacing.allSatisfy({ $0 > 0 }),
              let thickness = header.thickness, thickness.isFinite, thickness > 0,
              abs(orientation[0] * orientation[4] - orientation[1] * orientation[3]) > 0.85 else {
            throw QuantificationError("errEchoGroup")
        }
        self.init(sop: sop, frame: frame, sequence: sequence, acquisition: acquisition,
                  te: te, tesla: tesla, repetition: repetition, flip: flip, columns: columns, rows: rows,
                  position: position, orientation: orientation, spacing: spacing, thickness: thickness)
    }

    init(sop: String, frame: String, sequence: String, acquisition: String, te: Double,
         tesla: Double, repetition: Double, flip: Double, columns: Int, rows: Int,
         position: [Double], orientation: [Double], spacing: [Double], thickness: Double) {
        self.sop = sop; self.frame = frame; self.sequence = sequence; self.acquisition = acquisition
        self.te = te; self.tesla = tesla; self.repetition = repetition; self.flip = flip
        self.columns = columns; self.rows = rows; self.position = position
        self.orientation = orientation; self.spacing = spacing; self.thickness = thickness
    }

    func sameProtocol(as other: Self) -> Bool {
        frame == other.frame && sequence == other.sequence && acquisition == other.acquisition &&
        abs(tesla - other.tesla) <= 0.01 && abs(repetition - other.repetition) <= 0.01 &&
        abs(flip - other.flip) <= 0.1 && columns == other.columns && rows == other.rows &&
        close(orientation, other.orientation, tolerance: 0.0001) &&
        close(spacing, other.spacing, tolerance: 0.001) && abs(thickness - other.thickness) <= 0.05
    }

    func samePlane(as other: Self) -> Bool {
        sameProtocol(as: other) && close(position, other.position, tolerance: 0.05)
    }

    private func close(_ a: [Double], _ b: [Double], tolerance: Double) -> Bool {
        a.count == b.count && sqrt(zip(a, b).reduce(0) { $0 + pow($1.0 - $1.1, 2) }) <= tolerance
    }
}

struct EchoSeriesCandidate {
    let uid: String // Database UID, not the possibly shared native SeriesInstanceUID.
    let images: [EchoDescriptor]

    var sortedImages: [EchoDescriptor] {
        images.sorted { $0.position.lexicographicallyPrecedes($1.position) }
    }

    var isSingleEchoVolume: Bool {
        guard let first = images.first, !images.isEmpty,
              Set(images.map(\.sop)).count == images.count else { return false }
        let sorted = sortedImages
        return images.allSatisfy { $0.sameProtocol(as: first) && abs($0.te - first.te) <= 0.001 } &&
            zip(sorted, sorted.dropFirst()).allSatisfy { !$0.samePlane(as: $1) }
    }

    func sameGrid(as other: Self) -> Bool {
        images.count == other.images.count &&
        zip(sortedImages, other.sortedImages).allSatisfy { $0.samePlane(as: $1) }
    }
}

struct EchoGroupPlan {
    let series: [EchoSeriesCandidate]
    var uids: [String] { series.map(\.uid) }
    var sops: Set<String> { Set(series.flatMap { $0.images.map(\.sop) }) }
    var z: Double { series[0].sortedImages[0].position[2] }
}

enum EchoGrouping {
    static func groups(_ candidates: [EchoSeriesCandidate], matching anchor: EchoDescriptor) -> [EchoGroupPlan] {
        var buckets: [[EchoSeriesCandidate]] = []
        for candidate in candidates.sorted(by: { $0.uid < $1.uid }) {
            guard candidate.isSingleEchoVolume, let first = candidate.images.first,
                  first.sameProtocol(as: anchor) else { continue }
            if let index = buckets.firstIndex(where: { $0[0].sameGrid(as: candidate) }) {
                buckets[index].append(candidate)
            } else { buckets.append([candidate]) }
        }
        return buckets.compactMap { bucket -> EchoGroupPlan? in
            let sorted = bucket.sorted { $0.images[0].te < $1.images[0].te }
            guard (LiverQuantification.minimumEchoCount...64).contains(sorted.count),
                  Set(sorted.map(\.uid)).count == sorted.count,
                  Set(sorted.flatMap { $0.images.map(\.sop) }).count == sorted.reduce(0, { $0 + $1.images.count }),
                  zip(sorted, sorted.dropFirst()).allSatisfy({ $1.images[0].te - $0.images[0].te > 0.001 }) else { return nil }
            return EchoGroupPlan(series: sorted)
        }.sorted { $0.z < $1.z }
    }
}
