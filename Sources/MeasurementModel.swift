// SPDX-License-Identifier: MIT
import AppKit
import Combine
import IsiXPluginKit

@MainActor
final class MeasurementModel: ObservableObject {
    struct SeriesOption: Identifiable {
        let viewer: IsiXViewer
        let description: String?
        let suffix: String
        var id: IsiXViewerID { viewer.id }
    }

    struct Result {
        let rows: [ROIResult]
        let summary: LiverSummary?
    }

    private let context: IsiXPluginContext
    private var reference: IsiXViewer
    var viewerID: IsiXViewerID { reference.id }
    @Published private(set) var groups: [PreparedEchoGroup] = []
    @Published private(set) var activeGroup: IsiXViewerID
    @Published private(set) var automaticNotice: LocalizedMessage?
    private var roiSnapshots: [String: [IsiXROI]] = [:]
    private struct SavedPlacement {
        let sop: String
        let rois: [Region: ROIShape]
        let imported: Set<Region>
    }
    private var savedPlacements: [IsiXViewerID: SavedPlacement] = [:]

    @Published private(set) var input: MeasurementInput?
    @Published private(set) var options: [SeriesOption] = []
    @Published private(set) var selected: Set<IsiXViewerID> = []
    @Published private(set) var rois: [Region: ROIShape] = [:]
    @Published private(set) var viewerRegions: Set<Region> = []
    @Published private(set) var result: Result?
    @Published private(set) var error: LocalizedMessage?
    @Published private(set) var roiImportIssues: [Region: LocalizedMessage] = [:]
    @Published private(set) var calculationIssue: LocalizedMessage? = LocalizedMessage("needEchoes")
    private var echoSelectionDirty = false
    private var referenceUnavailable = false
    @Published var activeRegion: Region = .liver1
    @Published var echoIndex = 0
    @Published var fixedWindow = true

    init(context: IsiXPluginContext, reference: IsiXViewer, preparation: Automatic4D.Preparation) {
        self.context = context
        self.reference = reference
        activeGroup = reference.id
        groups = preparation.groups
        roiSnapshots = preparation.roiSnapshots
        automaticNotice = preparation.notice
        refreshOptions()
        capture()
    }

    func selectGroup(_ id: IsiXViewerID) {
        guard id != reference.id, let group = groups.first(where: { $0.id == id }), group.viewer.isOpen else { return }
        if let input {
            savedPlacements[reference.id] = SavedPlacement(sop: input.reference.sop, rois: rois, imported: viewerRegions)
        }
        reference = group.viewer
        activeGroup = id
        referenceUnavailable = false
        selected = []
        input = nil
        removeAllROIs()
        refreshOptions()
        capture()
        if let input, let saved = savedPlacements[id], saved.sop == input.reference.sop {
            rois = saved.rois
            viewerRegions = saved.imported
            activeRegion = Region.next(occupied: Set(rois.keys)) ?? .liver1
            updateCalculationAvailability()
        }
    }

    func viewerWillClose(_ id: IsiXViewerID) {
        groups.removeAll { $0.id == id }
        savedPlacements.removeValue(forKey: id)
        if id == reference.id {
            referenceUnavailable = true
            input = nil
            options = []
            selected = []
            removeAllROIs()
            error = LocalizedMessage("errViewerClosed")
            calculationIssue = LocalizedMessage("errViewerClosed")
        } else {
            options.removeAll { $0.id == id }
            if selected.remove(id) != nil {
                echoSelectionDirty = true
                result = nil
                updateCalculationAvailability()
            }
        }
    }

    func refreshOptions() {
        guard !referenceUnavailable else { return }
        do {
            let study = try reference.series().studyInstanceUID
            options = try context.openViewers().compactMap { viewer in
                guard viewer.id != reference.id, let study, let series = try? viewer.series(),
                      series.studyInstanceUID == study, series.modality == "MR" else { return nil }
                let suffix = String(series.seriesInstanceUID?.suffix(12) ?? "Viewer")
                return SeriesOption(viewer: viewer, description: series.seriesDescription, suffix: suffix)
            }
            let before = selected
            selected.formIntersection(Set(options.map(\.id)))
            if selected != before {
                echoSelectionDirty = true
                result = nil
                updateCalculationAvailability()
            }
        } catch {
            self.error = LocalizedMessage(error)
        }
    }

    func selectSeries(_ id: IsiXViewerID, included: Bool) {
        if included { selected.insert(id) } else { selected.remove(id) }
        echoSelectionDirty = true
        result = nil
        error = nil
        updateCalculationAvailability()
    }

    func capture() {
        result = nil
        echoIndex = 0
        error = nil
        do {
            guard !referenceUnavailable, reference.isOpen else { throw QuantificationError("errViewerClosed") }
            let included = options.filter { selected.contains($0.id) }.map(\.viewer)
            let captured = try IsiXInput.capture(context: context, reference: reference, additional: included)
            if input?.reference.sop != captured.reference.sop || input?.geometry != captured.geometry {
                removeAllROIs()
            }
            input = captured
            echoSelectionDirty = false
            importViewerROIs(reportEmpty: false)
        } catch {
            input = nil
            removeAllROIs()
            self.error = LocalizedMessage(error)
            updateCalculationAvailability()
        }
    }

    func setROI(_ rect: CGRect) {
        guard let input else { return }
        do {
            let shape = ROIShape.oval(rect)
            let pixels = Set(try input.indices(in: shape))
            for (region, existing) in rois where region != activeRegion {
                guard try pixels.isDisjoint(with: input.indices(in: existing)) else {
                    throw QuantificationError("errOverlap")
                }
            }
            rois[activeRegion] = shape
            viewerRegions.remove(activeRegion)
            roiImportIssues.removeValue(forKey: activeRegion)
            result = nil
            error = nil
            activeRegion = Region.next(after: activeRegion, occupied: Set(rois.keys)) ?? activeRegion
            updateCalculationAvailability()
        } catch {
            self.error = LocalizedMessage(error)
        }
    }

    func removeROI(_ region: Region) {
        rois.removeValue(forKey: region)
        viewerRegions.remove(region)
        roiImportIssues.removeValue(forKey: region)
        result = nil
        error = nil
        activeRegion = region
        updateCalculationAvailability()
    }

    private func removeAllROIs() {
        rois = [:]
        viewerRegions = []
        roiImportIssues = [:]
        result = nil
        activeRegion = .liver1
    }

    func importViewerROIs() { importViewerROIs(reportEmpty: true) }

    private func importViewerROIs(reportEmpty: Bool) {
        guard let input else { return }
        result = nil
        error = nil
        roiImportIssues = [:]
        var updated = rois.filter { !viewerRegions.contains($0.key) }
        var importedRegions: Set<Region> = []
        do {
            let current = input.reference
            guard try reference.attributes(slice: current.slice, phase: current.phase).sopInstanceUID == current.sop else {
                throw QuantificationError("errViewerChanged")
            }
            var candidates: [Region: [IsiXROI]] = [:]
            for frame in [current] + input.otherROIFrames {
                let source: [IsiXROI]
                if frame.sop == current.sop {
                    source = try reference.rois(slice: frame.slice, phase: frame.phase)
                } else {
                    guard let attributes = try? reference.attributes(slice: frame.slice, phase: frame.phase),
                          attributes.sopInstanceUID == frame.sop,
                          let fallback = try? reference.rois(slice: frame.slice, phase: frame.phase) else { continue }
                    source = fallback
                }
                var named = Dictionary(grouping: source.compactMap { roi -> (Region, IsiXROI)? in
                    guard let region = Region(roiName: roi.name) ?? Region(roiName: roi.comment) else { return nil }
                    return (region, roi)
                }, by: { $0.0 })
                let inherited = Dictionary(grouping: (roiSnapshots[frame.sop] ?? []).compactMap { roi -> (Region, IsiXROI)? in
                    guard let region = Region(roiName: roi.name) ?? Region(roiName: roi.comment) else { return nil }
                    return (region, roi)
                }, by: { $0.0 })
                for (region, entries) in inherited where named[region] == nil { named[region] = entries }
                for (region, entries) in named where candidates[region] == nil {
                    candidates[region] = entries.map { $0.1 }
                }
            }
            if candidates.isEmpty && reportEmpty { error = LocalizedMessage("noNamedROIs") }

            // Check required ROIs first. A malformed optional ROI must not remove valid liver ROIs.
            let order = Region.required + Region.allCases.filter { !Region.required.contains($0) }
            for region in order {
                guard let matches = candidates[region] else { continue }
                do {
                    guard matches.count == 1, let roi = matches.first else {
                        throw QuantificationError("errDuplicateROI", region.rawValue)
                    }
                    let shape = try viewerShape(roi, region: region)
                    let pixels = Set(try input.indices(in: shape))
                    for (other, existing) in updated where other != region {
                        guard try pixels.isDisjoint(with: input.indices(in: existing)) else {
                            throw QuantificationError("errOverlapROI", region.rawValue)
                        }
                    }
                    updated[region] = shape
                    importedRegions.insert(region)
                } catch {
                    roiImportIssues[region] = LocalizedMessage(error)
                }
            }
        } catch {
            self.error = LocalizedMessage(error)
        }

        rois = updated
        viewerRegions = importedRegions
        activeRegion = Region.next(occupied: Set(updated.keys)) ?? activeRegion
        updateCalculationAvailability()
    }

    private func viewerShape(_ roi: IsiXROI, region: Region) throws -> ROIShape {
        // SDK coordinates place the first pixel center at (0,0).
        let points = roi.points.map { CGPoint(x: $0.x + 0.5, y: $0.y + 0.5) }
        switch roi.kind {
        case .oval where points.count == 2: return .oval(ROIShape.boundingBox(points))
        case .rectangle where points.count == 2: return .rectangle(ROIShape.boundingBox(points))
        case .polygon, .rectangle, .oval:
            guard points.count >= 3 else { throw QuantificationError("errOpenROI", region.rawValue) }
            return .polygon(points)
        default: throw QuantificationError("errShape", region.rawValue)
        }
    }

    private func updateCalculationAvailability() {
        calculationIssue = nil
        if referenceUnavailable {
            calculationIssue = LocalizedMessage("errViewerClosed")
            return
        }
        if echoSelectionDirty {
            calculationIssue = LocalizedMessage("reloadEchoes")
            return
        }
        guard let input else {
            calculationIssue = LocalizedMessage("needEchoes")
            return
        }
        if let issue = input.echoIssue {
            calculationIssue = issue
            return
        }
        let missing = Region.missingRequired(in: Set(rois.keys))
        if !missing.isEmpty {
            calculationIssue = LocalizedMessage("missingRequired", [missing.map(\.rawValue).joined(separator: ", ")])
            return
        }

        var current = Region.noise
        do {
            guard let noiseROI = rois[.noise] else { throw QuantificationError("errNoiseROI") }
            let noise = try sample(noiseROI, in: input)
            guard noise.allSatisfy({ $0.mean > 0 }) else { throw QuantificationError("zeroNoiseROI") }
            for region in Region.liver {
                current = region
                guard let shape = rois[region] else { return }
                let liver = try sample(shape, in: input)
                try LiverQuantification.validate(echoSignals(liver, noise: noise, input: input), tesla: input.tesla)
            }
        } catch {
            calculationIssue = LocalizedMessage(error).prefixed(by: current.rawValue)
        }
    }

    private func sample(_ shape: ROIShape, in input: MeasurementInput) throws -> [SignalStatistics] {
        let indices = try input.indices(in: shape)
        return try input.echoes.map { try $0.statistics(at: indices) }
    }

    private func echoSignals(_ liver: [SignalStatistics], noise: [SignalStatistics], input: MeasurementInput) -> [EchoSignal] {
        input.echoes.indices.map {
            EchoSignal(milliseconds: input.echoes[$0].te, magnitude: liver[$0].mean, background: noise[$0].mean)
        }
    }

    func measure() {
        error = nil
        result = nil
        updateCalculationAvailability()
        guard calculationIssue == nil, let input else { return }
        var signals: [Region: [SignalStatistics]] = [:]
        var issues: [Region: LocalizedMessage] = [:]
        for (region, roi) in rois {
            do {
                signals[region] = try sample(roi, in: input)
            } catch {
                issues[region] = LocalizedMessage(error)
            }
        }

        let noise = signals[.noise]
        let rows: [ROIResult] = Region.allCases.compactMap { region in
            guard let roi = rois[region] else { return nil }
            let samples = signals[region] ?? []
            let liver = Region.liver.contains(region)
            var fit: LiverFit?
            var ironMg: Double?
            var issue = issues[region]
            if issue == nil && (liver || region == .spleen || region == .pancreas) {
                if let noise {
                    let echoes = echoSignals(samples, noise: noise, input: input)
                    do {
                        let value = try LiverQuantification.fit(echoes, tesla: input.tesla)
                        fit = value
                        if liver {
                            let iron = input.strength.estimatedIron(r2: value.r2)
                            if iron >= 0 { ironMg = iron }
                            else { issue = LocalizedMessage("errLICRange") }
                        }
                    } catch {
                        issue = LocalizedMessage(error)
                    }
                } else {
                    issue = LocalizedMessage("errNoiseROI")
                }
            }
            return ROIResult(region: region, center: CGPoint(x: roi.bounds.midX - 0.5, y: roi.bounds.midY - 0.5),
                             signals: samples, fit: fit, ironMg: ironMg, issue: issue)
        }
        let summary = LiverSummary(rows)
        result = Result(rows: rows, summary: summary)
    }

    func assessment(_ result: Result, input: MeasurementInput, language: UILanguage) -> String {
        let liverRows = result.rows.filter { Region.liver.contains($0.region) }
        let fits = liverRows.compactMap(\.fit)
        var paragraphs: [String] = []
        if let summary = result.summary {
            let fatText = language.text(summary.fatPercent >= 5 ? "reportFatHigh" : "reportFatLow")
            paragraphs.append(language.text("reportSummary", input.strength.display(in: language),
                language.number(summary.r2), language.number(1000 / summary.r2, digits: 2),
                language.number(summary.fatPercent), fatText))
            if let iron = summary.ironMg, let category = summary.ironCategory {
                paragraphs.append(language.text("reportIron", language.number(iron, digits: 2),
                    language.number(iron / 0.055845), language.text(category)))
            } else {
                paragraphs.append(language.text("reportNoIron"))
            }
            let r2 = fits.map(\.r2)
            let pdff = fits.map(\.fatFraction)
            if (r2.max() ?? 0) - (r2.min() ?? 0) > 0.25 * summary.r2 ||
                (pdff.max() ?? 0) - (pdff.min() ?? 0) > 0.05 {
                paragraphs.append(language.text("reportSpread"))
            }
        } else {
            let failed = Region.liver.filter { region in !liverRows.contains { $0.region == region && $0.fit != nil } }
            paragraphs.append(language.text("reportFailed", failed.map(\.rawValue).joined(separator: ", ")))
        }
        if fits.contains(where: { $0.usedEchoes < input.echoes.count }) {
            paragraphs.append(language.text("reportNoise"))
        }
        paragraphs.append(language.text("reportValidation"))
        return paragraphs.joined(separator: "\n\n")
    }
}
