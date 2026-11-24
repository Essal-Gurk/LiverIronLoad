// SPDX-License-Identifier: MIT
import Foundation

struct QuantificationError: LocalizedError {
    let message: LocalizedMessage
    init(_ key: String, _ values: String...) { self.message = LocalizedMessage(key, values) }
    var errorDescription: String? { message.text(in: .current) }
}

enum FieldStrength: Equatable {
    case onePointFive, twoPointEightNine, three

    func display(in language: UILanguage) -> String {
        switch self {
        case .onePointFive: return language.number(1.5) + " T"
        case .twoPointEightNine: return language.number(2.89, digits: 2) + " T"
        case .three: return "3 T"
        }
    }

    init?(tesla: Double) {
        switch tesla {
        case 1.48...1.52: self = .onePointFive
        case 2.87...2.92: self = .twoPointEightNine
        case 2.97...3.03: self = .three
        default: return nil
        }
    }

    // Published Hernando et al. calibration coefficients, applied here for
    // comparison. This magnitude reconstruction differs from their complex fit.
    func estimatedIron(r2: Double) -> Double {
        switch self {
        case .onePointFive: 0.02603 * r2 - 0.16
        case .twoPointEightNine: 0.01400 * r2 - 0.03
        case .three: 0.01349 * r2 - 0.03
        }
    }
}

struct EchoSignal {
    let milliseconds: Double
    let magnitude: Double
    let background: Double
}

struct LiverFit {
    let r2: Double
    let fatFraction: Double
    let residual: Double
    let usedEchoes: Int
}

enum LiverQuantification {
    private struct Datum {
        let t: Double
        let signal: Double
        let fatReal: Double
        let fatImaginary: Double
    }

    private struct Candidate {
        let r2: Double
        let fat: Double
        let error: Double
    }

    static func fatSpectrum(t: Double, tesla: Double) -> (Double, Double) {
        let peaks = [(0.9, 8.8), (1.3, 70.0), (2.1, 12.0)]
        return peaks.reduce(into: (0.0, 0.0)) { total, peak in
            let angle = 2 * Double.pi * t * 42.57747892 * tesla * (peak.0 - 4.7)
            total.0 += peak.1 / 90.8 * cos(angle)
            total.1 += peak.1 / 90.8 * sin(angle)
        }
    }

    static let minimumEchoCount = 6

    static func validate(_ echoes: [EchoSignal], tesla: Double) throws {
        _ = try prepare(echoes, tesla: tesla)
    }

    private static func prepare(_ echoes: [EchoSignal], tesla: Double) throws -> (data: [Datum], first: EchoSignal) {
        let sorted = echoes.sorted { $0.milliseconds < $1.milliseconds }
        guard sorted.count >= minimumEchoCount,
              sorted.allSatisfy({ $0.milliseconds.isFinite && $0.milliseconds > 0 &&
                  $0.magnitude.isFinite && $0.magnitude >= 0 &&
                  $0.background.isFinite && $0.background > 0 }),
              zip(sorted.dropFirst(), sorted).allSatisfy({ $0.0.milliseconds - $0.1.milliseconds > 0.001 })
        else { throw QuantificationError("errEchoMin") }

        let retained = sorted.filter { $0.magnitude > 2 * $0.background }
        guard let first = retained.first, let last = retained.last,
              sorted.first?.milliseconds == first.milliseconds, retained.count >= minimumEchoCount,
              last.milliseconds - first.milliseconds >= 3,
              let scale = retained.map(\.magnitude).max(), scale > 0
        else { throw QuantificationError("errNoiseFloor") }

        let data = retained.map { echo in
            let t = echo.milliseconds / 1000
            let spectrum = fatSpectrum(t: t, tesla: tesla)
            return Datum(t: t, signal: echo.magnitude / scale, fatReal: spectrum.0, fatImaginary: spectrum.1)
        }
        // Echo scheduling must encode water/fat modulation even before fitting.
        let modulation = data.map { hypot(0.8 + 0.2 * $0.fatReal, 0.2 * $0.fatImaginary) }
        guard let low = modulation.min(), let high = modulation.max(), high - low >= 0.10
        else { throw QuantificationError("errPhase") }

        return (data, first)
    }

    static func fit(_ echoes: [EchoSignal], tesla: Double) throws -> LiverFit {
        let (data, first) = try prepare(echoes, tesla: tesla)

        func evaluate(_ r2: Double, _ fat: Double) -> Candidate {
            let basis = data.map { hypot(1 - fat + fat * $0.fatReal, fat * $0.fatImaginary) * exp(-r2 * $0.t) }
            let products = zip(data, basis)
            let norm = basis.reduce(0) { $0 + $1 * $1 }
            guard norm > 0 else { return Candidate(r2: r2, fat: fat, error: .infinity) }
            let amplitude = products.reduce(0) { $0 + $1.0.signal * $1.1 } / norm
            let squaredError = products.reduce(0.0) {
                let difference = $1.0.signal - amplitude * $1.1
                return $0 + difference * difference
            }
            return Candidate(r2: r2, fat: fat, error: squaredError)
        }

        let rows = (0...50).map { r in
            (0...50).map { f in evaluate(Double(r) * 40, Double(f) / 100) }
        }
        let starts = rows.enumerated().flatMap { r, row in
            row.enumerated().compactMap { f, candidate -> Candidate? in
                for i in max(0, r - 1)...min(50, r + 1) {
                    for j in max(0, f - 1)...min(50, f + 1) {
                        if rows[i][j].error < candidate.error { return nil }
                    }
                }
                return candidate
            }
        }.sorted { $0.error < $1.error }

        func refine(_ start: Candidate) -> Candidate {
            var best = start
            var rStep = 20.0
            var fStep = 0.005
            for _ in 0..<30 {
                let origin = best
                for r in [-rStep, 0, rStep] {
                    for f in [-fStep, 0, fStep] {
                        let trial = evaluate(min(2000, max(0, origin.r2 + r)), min(0.5, max(0, origin.fat + f)))
                        if trial.error < best.error { best = trial }
                    }
                }
                if best.error == origin.error {
                    rStep /= 2
                    fStep /= 2
                }
            }
            return best
        }

        let candidates = starts.prefix(12).map(refine).sorted { $0.error < $1.error }
        guard let best = candidates.first else { throw QuantificationError("errFit") }
        let rmse = sqrt(best.error / Double(data.count))
        guard best.r2 > 0, best.r2 < 1999, best.fat < 0.495, rmse <= 0.08
        else { throw QuantificationError("errFitLimit") }
        guard candidates.dropFirst().allSatisfy({
            abs($0.fat - best.fat) < 0.04 || sqrt($0.error / Double(data.count)) > rmse + 0.005
        }) else { throw QuantificationError("errAmbiguous") }

        guard 1000 / best.r2 >= 2 * first.milliseconds else {
            throw QuantificationError("errFastDecay")
        }

        return LiverFit(r2: best.r2, fatFraction: best.fat, residual: rmse, usedEchoes: data.count)
    }
}
