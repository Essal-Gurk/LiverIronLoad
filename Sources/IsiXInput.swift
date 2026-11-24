// SPDX-License-Identifier: MIT
import CoreGraphics
import Foundation
import IsiXPluginKit

struct EchoPlane {
    let te: Double
    let pixels: IsiXPixelBuffer<Float>

    func statistics(at indices: [Int]) throws -> SignalStatistics {
        try SignalStatistics.measure(pixels: pixels.samples, indices: indices)
    }
}

struct EchoLocation {
    let slice: Int
    let phase: Int
    let sop: String
}

struct MeasurementInput {
    let id = UUID()
    let echoes: [EchoPlane]
    let geometry: IsiXImageGeometry
    let tesla: Double
    let strength: FieldStrength
    let series: String?
    let repetition: Double
    let flip: Double
    let reference: EchoLocation
    let otherROIFrames: [EchoLocation]
    let phaseCount: Int
    let echoIssue: LocalizedMessage?

    var slice: Int { reference.slice + 1 }

    var width: Int { geometry.columns }
    var height: Int { geometry.rows }
    var aspect: Double { Double(width) * geometry.columnSpacing / (Double(height) * geometry.rowSpacing) }

    func indices(in roi: ROIShape) throws -> [Int] {
        try roi.indices(width: width, height: height)
    }

    func image(for index: Int, fixedWindow: Bool) -> CGImage? {
        let samples = echoes[index].pixels.samples
        let histogramSource = (fixedWindow ? echoes[0].pixels.samples : samples)
        let strideSize = max(1, histogramSource.count / 16384)
        let sample = Swift.stride(from: 0, to: histogramSource.count, by: strideSize)
            .map { histogramSource[$0] }.filter { $0.isFinite && $0 > 0 }.sorted()
        guard !sample.isEmpty else { return nil }
        let upper = max(1e-6, sample[Int(Double(sample.count - 1) * 0.985)])
        let bytes = samples.map { value -> UInt8 in
            guard value.isFinite else { return 0 }
            return UInt8((255 * min(1, max(0, value / upper))).rounded())
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
                       space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}

@MainActor
enum IsiXInput {
    static func capture(
        context: IsiXPluginContext, reference: IsiXViewer, additional: [IsiXViewer]
    ) throws -> MeasurementInput {
        let position = try reference.currentPosition()
        let summary = try reference.series()
        let geometry = try reference.geometry(slice: position.slice, phase: position.phase)
        let attributes = try reference.attributes(slice: position.slice, phase: position.phase)
        guard let study = summary.studyInstanceUID, attributes.studyInstanceUID == study,
              let sourceUID = attributes.sopInstanceUID, geometry.columns > 0, geometry.rows > 0,
              geometry.rowSpacing.isFinite, geometry.columnSpacing.isFinite,
              geometry.rowSpacing > 0, geometry.columnSpacing > 0,
              abs(geometry.normal.z) > 0.85
        else { throw QuantificationError("errChooseSlice") }

        let database = try context.database()
        var headers: [String: DICOMHeader] = [:]
        func header(_ sop: String) throws -> DICOMHeader {
            if let cached = headers[sop] { return cached }
            let files = try database.images(withSOPInstanceUID: sop)
            guard let file = files.first(where: { $0.studyInstanceUID == study && $0.numberOfFrames <= 1 && $0.file?.isFileURL == true })?.file else {
                throw QuantificationError("errSourceFile")
            }
            let header = try DICOMHeader(url: file)
            try header.verifySource()
            guard header.sop == sop else { throw QuantificationError("errSOP") }
            headers[sop] = header
            return header
        }

        let source = try header(sourceUID)
        guard let tesla = source.tesla, let repetition = source.repetition, let flip = source.flip,
              let referenceTE = source.echo, let strength = FieldStrength(tesla: tesla) else {
            throw QuantificationError("errStrength")
        }

        func plane(in viewer: IsiXViewer, at frame: EchoLocation, te: Double) throws -> EchoPlane {
            let image = try viewer.image(slice: frame.slice, phase: frame.phase)
            guard image.attributes.sopInstanceUID == frame.sop,
                  let pixels = image.scalarPixels, pixels.width == geometry.columns,
                  pixels.height == geometry.rows, pixels.channels == 1 else {
                throw QuantificationError("errPixels")
            }
            return EchoPlane(te: te, pixels: pixels)
        }

        let origin = EchoLocation(slice: position.slice, phase: position.phase, sop: sourceUID)
        let preview = try plane(in: reference, at: origin, te: referenceTE)
        var matchesInReference: [(te: Double, location: EchoLocation)] = []
        var echoes: [EchoPlane] = []
        let echoIssue: LocalizedMessage?
        do {
            var seen: Set<String> = []
            for viewer in [reference] + additional {
                guard viewer.isOpen else { throw QuantificationError("errEchoClosed") }
                let series = try viewer.series()
                let (total, overflow) = series.sliceCount.multipliedReportingOverflow(by: series.phaseCount)
                guard series.studyInstanceUID == study, !overflow, (1...4096).contains(total) else {
                    throw QuantificationError("errStudy")
                }
                for phase in 0..<series.phaseCount {
                    for slice in 0..<series.sliceCount {
                        let otherGeometry: IsiXImageGeometry
                        do {
                            otherGeometry = try viewer.geometry(slice: slice, phase: phase)
                        } catch IsiXPluginError.sliceOutOfRange(_) {
                            // The active phase may have more slices than this phase.
                            break
                        }
                        guard matches(geometry, otherGeometry) else { continue }
                        let metadata = try viewer.attributes(slice: slice, phase: phase)
                        guard metadata.modality == "MR", metadata.studyInstanceUID == study,
                              let sop = metadata.sopInstanceUID else {
                            throw QuantificationError("errMR")
                        }
                        guard seen.insert(sop).inserted else { continue }
                        let other = try header(sop)
                        guard let te = other.echo, let field = other.tesla, abs(field - tesla) <= 0.01,
                              source.frameOfReference == other.frameOfReference,
                              source.sequence == other.sequence, source.acquisition == other.acquisition,
                              abs(repetition - (other.repetition ?? 0)) <= 0.01,
                              abs(flip - (other.flip ?? 0)) <= 0.1,
                              metadata.rescaleSlope.isFinite, metadata.rescaleSlope > 0,
                              abs(metadata.rescaleIntercept) <= 0.001 else {
                            throw QuantificationError("errEchoGroup")
                        }
                        guard echoes.count < 64 else { throw QuantificationError("errTooMany") }
                        let frame = EchoLocation(slice: slice, phase: phase, sop: sop)
                        echoes.append(sop == sourceUID ? preview : try plane(in: viewer, at: frame, te: te))
                        if viewer.id == reference.id && sop != sourceUID {
                            matchesInReference.append((te, frame))
                        }
                    }
                }
            }

            echoes.sort { $0.te < $1.te }
            guard echoes.count >= LiverQuantification.minimumEchoCount else {
                throw QuantificationError("errCount", String(echoes.count))
            }
            guard zip(echoes.dropFirst(), echoes).allSatisfy({ $0.0.te - $0.1.te > 0.001 }) else {
                throw QuantificationError("errDuplicateTE")
            }
            echoIssue = nil
        } catch {
            // A split or invalid stack must not hide the reference image and its ROIs.
            echoes = [preview]
            echoIssue = LocalizedMessage(error)
        }

        return MeasurementInput(echoes: echoes, geometry: geometry, tesla: tesla, strength: strength,
                                series: summary.seriesDescription, repetition: repetition, flip: flip,
                                reference: origin, otherROIFrames: echoIssue == nil ? matchesInReference.sorted { $0.te < $1.te }.map(\.location) : [],
                                phaseCount: summary.phaseCount, echoIssue: echoIssue)
    }

    private static func matches(_ lhs: IsiXImageGeometry, _ rhs: IsiXImageGeometry) -> Bool {
        func close(_ a: IsiXVector3, _ b: IsiXVector3, tolerance: Double) -> Bool {
            hypot(hypot(a.x - b.x, a.y - b.y), a.z - b.z) <= tolerance
        }
        return lhs.columns == rhs.columns && lhs.rows == rhs.rows &&
            abs(lhs.columnSpacing - rhs.columnSpacing) <= 0.001 &&
            abs(lhs.rowSpacing - rhs.rowSpacing) <= 0.001 &&
            abs(lhs.sliceThickness - rhs.sliceThickness) <= 0.05 &&
            close(lhs.imagePosition, rhs.imagePosition, tolerance: 0.05) &&
            close(lhs.rowDirection, rhs.rowDirection, tolerance: 0.0001) &&
            close(lhs.columnDirection, rhs.columnDirection, tolerance: 0.0001)
    }
}
