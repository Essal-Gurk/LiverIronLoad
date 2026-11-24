// SPDX-License-Identifier: MIT
import AppKit
import SwiftUI

struct ResultsTable: View {
    let result: MeasurementModel.Result
    let echoes: [EchoPlane]
    @Binding var echoIndex: Int

    let language: UILanguage

    private let columns: [(key: String, width: CGFloat)] = [
        ("ROI", 42), ("Region", 94), ("X", 52), ("Y", 52), ("Signal", 72), ("SD", 50),
        ("R2", 63), ("T2", 63), ("LICmg", 68), ("LICumol", 75), ("SIR", 80), ("PDFF", 68)
    ]

    private var headings: [String] { columns.map { language.text("column" + $0.key) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let summary = result.summary {
                    HStack(spacing: 18) {
                        metric(language.text("licEstimate"), language.number(summary.ironMg, digits: 2), language.text("licUnit"), tip: "LICmg")
                        metric("PDFF", language.number(summary.fatPercent), "%", tip: "PDFF")
                        metric("R2*", language.number(summary.r2), "s⁻¹", tip: "R2")
                        metric("T2*", language.number(1000 / summary.r2, digits: 2), "ms", tip: "T2")
                    }
                }
                HStack {
                    Picker(language.text("signalAndSD"), selection: $echoIndex) {
                        ForEach(Array(echoes.enumerated()), id: \.element.te) { index, echo in
                            Text("TE \(language.number(echo.te, digits: 2)) ms").tag(index)
                        }
                    }.fixedSize().help(language.text("tipSignalEcho"))
                    Spacer()
                    Button(language.text("copyTable"), systemImage: "document.on.document") {
                        var header = headings
                        if echoes.indices.contains(echoIndex) {
                            let te = "TE \(language.number(echoes[echoIndex].te, digits: 2)) ms"
                            header[4] += " (\(te))"
                            header[5] += " (\(te))"
                        }
                        let lines = [header] + result.rows.map(cells(for:))
                        let tsv = lines.map { $0.joined(separator: "\t") }.joined(separator: "\n")
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(tsv, forType: .string)
                    }.help(language.text("tipCopyTable"))
                }
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 0) {
                        gridRow(headings).background(.quaternary)
                        ForEach(result.rows) { row in
                            gridRow(cells(for: row), region: row.region)
                            Divider()
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                Text(language.text("tableNote"))
                    .font(.caption).foregroundStyle(.secondary)
                let issues = result.rows.filter { $0.issue != nil }
                ForEach(issues) { row in
                    if let issue = row.issue {
                        Label("\(row.region.rawValue) · \(issue.text(in: language))", systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                liverMuscleRatios
                DisclosureGroup(language.text("fitQuality")) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(result.rows) { row in
                            if let fit = row.fit {
                                Text(language.text("fitQualityRow", row.region.rawValue, String(fit.usedEchoes),
                                                   language.number(fit.residual * 100)))
                            }
                            if !row.signals.isEmpty {
                                Text("\(row.region.rawValue) · " + row.signals.map { language.number($0.mean) }.joined(separator: " / "))
                            }
                        }
                        Text(language.text("signalOrder")).foregroundStyle(.secondary)
                    }.font(.caption).monospacedDigit().textSelection(.enabled).padding(.top, 5)
                }.help(language.text("tipFitQuality"))
            }.padding(18)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var liverMuscleRatios: some View {
        let signals = result.rows.reduce(into: [Region: Double]()) { values, row in
            if row.signals.indices.contains(echoIndex) { values[row.region] = row.signals[echoIndex].mean }
        }
        let denominator = [signals[.muscleRight], signals[.muscleLeft]].compactMap { $0 }
        let mean = denominator.reduce(0, +) / 2
        let ratios = mean > 0 && denominator.count == 2 ? Region.liver.compactMap { region in
            signals[region].map { "\(region.rawValue) \(language.number($0 / mean, digits: 2))" }
        } : []
        return Group {
            if !ratios.isEmpty {
                Text(language.text("ratios", ratios.joined(separator: "   ")))
                    .help(language.text("tipRatios"))
                    .font(.caption).textSelection(.enabled)
            }
        }
    }

    private func cells(for row: ROIResult) -> [String] {
        let signal = row.signals.indices.contains(echoIndex) ? row.signals[echoIndex] : nil
        let pdff = Region.liver.contains(row.region) ? row.fit.map { 100 * $0.fatFraction } : nil
        return [row.region.rawValue, row.region.label(in: language), language.number(row.center.x), language.number(row.center.y),
                language.number(signal?.mean), language.number(signal?.sd), language.number(row.fit?.r2),
                language.number(row.fit.map { 1000 / $0.r2 }, digits: 2), language.number(row.ironMg, digits: 2),
                language.number(row.ironMg.map { $0 / 0.055845 }), "—", language.number(pdff)]
    }

    private func gridRow(_ values: [String], region: Region? = nil) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(columns.enumerated()), id: \.element.key) { index, column in
                let help = index < 2 && region != nil
                    ? region?.tooltip(in: language) ?? ""
                    : language.text("tipColumn" + column.key)
                Text(values[index])
                    .font(region == nil ? .caption.bold() : .caption)
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(width: column.width, alignment: index < 2 ? .leading : .trailing)
                    .contentShape(Rectangle())
                    .help(help)
            }
        }
        .padding(.vertical, 7).padding(.horizontal, 8)
        .textSelection(.enabled)
    }

    private func metric(_ label: String, _ value: String, _ unit: String, tip: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text("\(value) \(unit)").font(.headline.monospacedDigit())
        }.help(language.text("tipColumn" + tip))
    }
}
