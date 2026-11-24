// SPDX-License-Identifier: MIT
import Foundation
import IsiXPluginKit

struct PreparedEchoGroup: Identifiable {
    let viewer: IsiXViewer
    let z: Double
    let echoes: Int
    var id: IsiXViewerID { viewer.id }
}

@MainActor
enum Automatic4D {
    struct Preparation {
        var groups: [PreparedEchoGroup] = []
        var reference: IsiXViewer
        var roiSnapshots: [String: [IsiXROI]] = [:]
        var notice: LocalizedMessage?
    }

    static func prepare(context: IsiXPluginContext, reference: IsiXViewer,
                        cache: inout [[String]: IsiXViewer]) throws -> Preparation {
        var output = Preparation(reference: reference)
        let summary = try reference.series()
        let at = try reference.currentPosition()
        let attributes = try reference.attributes(slice: at.slice, phase: at.phase)
        guard let study = summary.studyInstanceUID, let sop = attributes.sopInstanceUID else {
            throw QuantificationError("errStudy")
        }
        let database = try context.database()
        guard let file = try database.images(withSOPInstanceUID: sop).first(where: {
            $0.studyInstanceUID == study && $0.file?.isFileURL == true
        })?.file else { throw QuantificationError("errSourceFile") }
        let anchor = try EchoDescriptor(header: DICOMHeader(url: file))
        let records = try database.series(inStudy: study).filter { $0.modality == "MR" }
        guard records.count <= 4096 else { throw QuantificationError("errTooMany") }
        var candidates: [EchoSeriesCandidate] = []
        for record in records where (1...512).contains(record.imageCount) {
            let images = try database.images(inSeries: record.seriesInstanceUID)
            guard images.count == record.imageCount else { continue }
            // A failed source check rejects the entire database series, never a subset.
            let descriptors = try? images.map { image -> EchoDescriptor in
                guard image.studyInstanceUID == study, image.numberOfFrames <= 1,
                      let file = image.file, file.isFileURL else { throw QuantificationError("errSourceFile") }
                let descriptor = try EchoDescriptor(header: DICOMHeader(url: file))
                guard descriptor.sop == image.sopInstanceUID else { throw QuantificationError("errSOP") }
                return descriptor
            }
            if let descriptors { candidates.append(EchoSeriesCandidate(uid: record.seriesInstanceUID, images: descriptors)) }
        }
        let plans = EchoGrouping.groups(candidates, matching: anchor)
        guard plans.contains(where: { $0.sops.contains(sop) }) else {
            // Already combined stacks continue through the existing phase/slice reader.
            output.notice = summary.phaseCount > 1 ? nil : LocalizedMessage("auto4DUnavailable")
            return output
        }

        // Capture value snapshots before opening viewers. No ROI is copied to another plane.
        let allSOPs = plans.reduce(into: Set<String>()) { $0.formUnion($1.sops) }
        for viewer in try context.openViewers() where viewer.isOpen {
            guard let series = try? viewer.series(), series.studyInstanceUID == study,
                  series.sliceCount > 0, series.phaseCount > 0,
                  series.sliceCount <= 4096 / series.phaseCount else { continue }
            for phase in 0..<series.phaseCount {
                for slice in 0..<series.sliceCount {
                    guard let uid = try? viewer.attributes(slice: slice, phase: phase).sopInstanceUID,
                          allSOPs.contains(uid), let rois = try? viewer.rois(slice: slice, phase: phase), !rois.isEmpty else { continue }
                    if output.roiSnapshots[uid] == nil || viewer.id == reference.id {
                        output.roiSnapshots[uid] = rois
                    }
                }
            }
        }
        cache = cache.filter { $0.value.isOpen }
        var failures = 0
        // Open the invoked image's group first; never silently select another height on failure.
        let ordered = plans.sorted { $0.sops.contains(sop) && !$1.sops.contains(sop) }
        for plan in ordered {
            do {
                let viewer: IsiXViewer
                if let existing = cache[plan.uids], existing.isOpen {
                    viewer = existing
                } else if summary.phaseCount == plan.series.count,
                          try containsExactly(reference, plan: plan) {
                    viewer = reference
                    cache[plan.uids] = viewer
                } else {
                    guard let opened = try database.open4DViewer(forSeries: plan.uids) else {
                        throw QuantificationError("auto4DOpenFailed")
                    }
                    viewer = opened
                    cache[plan.uids] = viewer
                }
                if plan.sops.contains(sop) {
                    let grid = try viewer.series()
                    for phase in 0..<grid.phaseCount {
                        for slice in 0..<grid.sliceCount {
                            if try viewer.attributes(slice: slice, phase: phase).sopInstanceUID == sop {
                                try viewer.setCurrentPhase(phase)
                                try viewer.setCurrentSlice(slice)
                            }
                        }
                    }
                    output.reference = viewer
                }
                output.groups.append(PreparedEchoGroup(viewer: viewer, z: plan.z, echoes: plan.series.count))
            } catch {
                if plan.sops.contains(sop) { throw error }
                failures += 1
            }
        }
        output.groups.sort { $0.z < $1.z }
        output.notice = failures > 0 ? LocalizedMessage("auto4DPartial", [String(output.groups.count), String(failures)]) :
            LocalizedMessage("auto4DReady", [String(output.groups.count)])
        return output
    }

    private static func containsExactly(_ viewer: IsiXViewer, plan: EchoGroupPlan) throws -> Bool {
        let summary = try viewer.series()
        guard summary.phaseCount == plan.series.count, summary.sliceCount == plan.series[0].images.count else { return false }
        for phase in 0..<summary.phaseCount {
            var found = Set<String>()
            for slice in 0..<summary.sliceCount {
                guard let sop = try viewer.attributes(slice: slice, phase: phase).sopInstanceUID else { return false }
                found.insert(sop)
            }
            if found != Set(plan.series[phase].images.map(\.sop)) { return false }
        }
        return true
    }
}
