// SPDX-License-Identifier: MIT
import Foundation

extension CoreChecks {
    static func checkEchoGrouping() {
        func image(_ id: String, te: Double, z: Double, acquisition: String = "1", rows: Int = 224) -> EchoDescriptor {
            EchoDescriptor(sop: id, frame: "frame", sequence: "fl2d10", acquisition: acquisition,
                           te: te, tesla: 1.5, repetition: 120, flip: 20, columns: 256, rows: rows,
                           position: [0, 0, z], orientation: [1, 0, 0, 0, 1, 0], spacing: [1.484375, 1.484375], thickness: 10)
        }
        func series(_ prefix: String, z: Double, slices: [Double]? = nil) -> [EchoSeriesCandidate] {
            (0..<10).map { echo in
                EchoSeriesCandidate(uid: "\(prefix)-\(echo)", images: (slices ?? [z]).enumerated().map {
                    image("\(prefix)-\(echo)-\($0.offset)", te: 2.38 * Double(echo + 1), z: $0.element)
                })
            }
        }
        let levels = [-17.75, -2.51, 14.76, 31.02]
        let all = levels.enumerated().flatMap { series("height\($0.offset)", z: $0.element) }
        let anchor = all[20].images[0]
        let groups = EchoGrouping.groups(Array(all.reversed()), matching: anchor)
        precondition(groups.count == 4 && groups.map(\.z) == levels)
        precondition(groups.allSatisfy { $0.series.count == 10 })
        precondition(groups[2].sops.contains(anchor.sop))
        precondition(groups.allSatisfy { $0.series.map { $0.images[0].te } == (1...10).map { Double($0) * 2.38 } })

        let repeatEcho = EchoSeriesCandidate(uid: "duplicateTE", images: [image("anotherSOP", te: 2.38, z: 14.76)])
        precondition(EchoGrouping.groups(all + [repeatEcho], matching: anchor).count == 3,
                     "A repeated acquisition must not be silently selected by series number")
        precondition(EchoGrouping.groups(Array(all[20..<25]), matching: anchor).isEmpty)
        let mismatch = EchoSeriesCandidate(uid: "wrongMatrix", images: [image("wrong", te: 2.38, z: 14.76, rows: 200)])
        let unrelated = EchoSeriesCandidate(uid: "wrongAcquisition", images: [image("other", te: 2.38, z: 14.76, acquisition: "2")])
        precondition(EchoGrouping.groups(all + [mismatch, unrelated], matching: anchor).count == 4)
        let mixed = EchoSeriesCandidate(uid: "mixedEchoes", images: [image("a", te: 2.38, z: 0), image("b", te: 4.76, z: 0)])
        precondition(!mixed.isSingleEchoVolume)
        let duplicatePlane = EchoSeriesCandidate(uid: "duplicatePlane", images: [image("a", te: 2.38, z: 0), image("b", te: 2.38, z: 0)])
        precondition(!duplicatePlane.isSingleEchoVolume)
        let volumes = series("volume", z: 0, slices: [-10, 0, 10])
        precondition(EchoGrouping.groups(volumes, matching: volumes[0].images[1]).count == 1)
        let incomplete = volumes.dropLast() + [EchoSeriesCandidate(uid: "incomplete", images: [image("short", te: 23.8, z: 0)])]
        precondition(EchoGrouping.groups(Array(incomplete), matching: volumes[0].images[1]).first?.series.count == 9)
        print("OK · 4×10 echo grouping, TE ordering, ambiguity, geometry and multi-slice volumes")
    }
}
