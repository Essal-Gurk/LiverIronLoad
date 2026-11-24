// SPDX-License-Identifier: MIT
import AppKit
import SwiftUI

extension Region {
    var color: Color {
        switch self {
        case .liver1, .liver2, .liver3: .yellow
        case .noise: .cyan
        case .spleen: .mint
        case .pancreas: .pink
        case .heart: .red
        case .fat: .purple
        case .muscleRight, .muscleLeft: .orange
        }
    }
}

struct MeasurementView: View {
    @ObservedObject var model: MeasurementModel
    let showDiagram: () -> Void
    let showInfo: () -> Void
    let updateWindowTitles: (UILanguage) -> Void
    @AppStorage(UILanguage.preferenceKey) private var language = UILanguage.systemDefault

    private enum Page: String, CaseIterable, Identifiable {
        case measurement = "pageMeasurement", data = "pageData", report = "pageReport"
        var id: Self { self }
    }

    @State private var page: Page = .measurement

    private var ready: Bool { model.calculationIssue == nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Liver IronLoad").font(.title2.bold())
                    Text("v0.8 · Multi-Echo-GRE").foregroundStyle(.secondary)
                    Text(language.text("researchStatus"))
                        .font(.caption).foregroundStyle(.secondary)
                        .help(language.text("tipResearchStatus"))
                }
                Spacer()
                Button(language.text("diagram"), systemImage: "map", action: showDiagram)
                    .help(language.text("tipDiagram"))
                Button(language.text("guide"), systemImage: "info.circle", action: showInfo)
                    .help(language.text("tipGuide"))
                Picker(language.text("language"), selection: $language) {
                    ForEach(UILanguage.allCases) { choice in
                        Text(choice.name).tag(choice)
                    }
                }
                .labelsHidden().fixedSize()
                .help(language.text("tipLanguage"))
                .accessibilityLabel(language.text("language"))
            }
            .padding(16)
            Divider()
            Picker(language.text("view"), selection: $page) {
                ForEach(Page.allCases) { tab in
                    Text(language.text(tab.rawValue)).tag(tab)
                }
            }
            .labelsHidden().pickerStyle(.segmented).frame(maxWidth: 540).padding(9)
            .help(language.text("tipView"))
            Divider()
            switch page {
            case .measurement: measurement
            case .data:
                if let result = model.result, let input = model.input {
                    ResultsTable(result: result, echoes: input.echoes, echoIndex: $model.echoIndex, language: language)
                } else { noResults }
            case .report:
                if let result = model.result, let input = model.input {
                    let assessment = model.assessment(result, input: input, language: language)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text(language.text("reportDraft")).font(.title2.bold())
                                Spacer()
                                Button(language.text("copyReport"), systemImage: "document.on.document") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(assessment, forType: .string)
                                }
                                .help(language.text("tipCopyReport"))
                            }
                            Text(assessment).textSelection(.enabled)
                        }
                        .frame(maxWidth: 740, alignment: .leading).padding(24)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else { noResults }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .onChange(of: language, initial: true) { updateWindowTitles(language) }
    }

    private var noResults: some View {
        ContentUnavailableView(language.text("noResults"), systemImage: "tablecells",
                               description: Text(language.text("noResultsDetail")))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var measurement: some View {
        HSplitView {
                Group {
                    if let input = model.input {
                        VStack(spacing: 12) {
                            HStack {
                                Picker(language.text("image"), selection: $model.echoIndex) {
                                    ForEach(Array(input.echoes.enumerated()), id: \.element.te) { index, echo in
                                        Text("TE \(format(echo.te, 2)) ms").tag(index)
                                    }
                                }
                                .help(language.text("tipImage"))
                                Toggle(language.text("fixedWindow"), isOn: $model.fixedWindow)
                                    .help(language.text("tipWindow"))
                            }
                            MRImageView(input: input, echoIndex: model.echoIndex, fixedWindow: model.fixedWindow,
                                        regions: model.rois, active: model.activeRegion, language: language, onDraw: model.setROI)
                                .id(input.id)
                            Text(language.text("imageDetails", input.series ?? language.text("mrSeries"), String(input.slice),
                                input.strength.display(in: language), String(input.echoes.count),
                                format(input.repetition), format(input.flip, 0)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(16)
                    } else {
                        ContentUnavailableView(language.text("noEcho"), systemImage: "photo.stack",
                            description: Text(language.text("noEchoDetail")))
                    }
                }.frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)

                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        acquisition
                        Divider()
                        roiControls
                        if let problem = model.error {
                            Label(problem.text(in: language), systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                        if let issue = model.calculationIssue {
                            Label(issue.text(in: language), systemImage: "info.circle")
                                .font(.callout).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Button(language.text("calculate")) {
                            model.measure()
                            if model.result != nil { page = .data }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!ready)
                        .help(language.text("tipCalculate"))
                    }
                    .padding(16)
                }
                .frame(minWidth: 355, idealWidth: 390, maxWidth: 510)
        }
    }

    private var acquisition: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(language.text("sources")).font(.headline)
            if !model.groups.isEmpty {
                Picker(language.text("auto4DGroup"), selection: Binding(
                    get: { model.activeGroup }, set: { model.selectGroup($0) }
                )) {
                    ForEach(Array(model.groups.enumerated()), id: \.element.id) { index, group in
                        Text(language.text("auto4DGroupLabel", String(index + 1), language.number(group.z), String(group.echoes)))
                            .tag(group.id)
                    }
                }
                .help(language.text("tipAuto4DGroup"))
            }
            if let notice = model.automaticNotice {
                Text(notice.text(in: language)).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(language.text("capture"), systemImage: "arrow.down.to.line", action: model.capture)
                .help(language.text("tipCapture"))
            if let input = model.input, input.phaseCount > 1 {
                Text(language.text("fourDInfo", String(input.phaseCount)))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            DisclosureGroup(language.text("echoSeries", String(model.selected.count))) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(language.text("echoSeriesDetail"))
                        .font(.caption).foregroundStyle(.secondary)
                    Button(language.text("refresh"), action: model.refreshOptions)
                        .help(language.text("tipRefresh"))
                    ForEach(model.options) { option in
                        Toggle("\(option.description ?? language.text("mrSeries")) (…\(option.suffix))", isOn: Binding(
                            get: { model.selected.contains(option.id) },
                            set: { model.selectSeries(option.id, included: $0) }
                        )).help(language.text("tipSelectEcho"))
                    }
                    if model.options.isEmpty {
                        Text(language.text("noOtherViewers")).font(.caption)
                    }
                }.padding(.top, 6)
            }
            .help(language.text("tipEchoSeries"))
        }
    }

    private var roiControls: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(language.text("regions")).font(.headline)
            Text(language.text("regionsDetail"))
                .font(.caption).foregroundStyle(.secondary)
            Button(language.text("importROIs"), systemImage: "viewfinder", action: model.importViewerROIs)
                .help(language.text("tipImportROIs"))
            ForEach(Region.allCases) { region in
                VStack(alignment: .leading, spacing: 2) {
                    roiRow(region)
                    if let issue = model.roiImportIssues[region] {
                        Label(issue.text(in: language), systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }.disabled(model.input == nil)
    }

    private func roiRow(_ region: Region) -> some View {
        HStack {
            Button {
                model.activeRegion = region
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(region.rawValue) · \(region.label(in: language))")
                        if let roi = model.rois[region]?.bounds, let geometry = model.input?.geometry {
                            let source = model.viewerRegions.contains(region) ? " · IsiX" : ""
                            Text("\(format(roi.width * geometry.columnSpacing, 0)) × \(format(roi.height * geometry.rowSpacing, 0)) mm\(source)")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: model.rois[region] == nil ? "circle" : "checkmark.circle.fill")
                        .foregroundStyle(region.color == .yellow ? Color.orange : region.color)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .help(region.tooltip(in: language))
            .padding(5)
            .background(model.activeRegion == region ? Color.accentColor.opacity(0.16) : .clear,
                        in: RoundedRectangle(cornerRadius: 5))
            if model.rois[region] != nil {
                Button { model.removeROI(region) } label: { Image(systemName: "xmark.circle") }
                   .buttonStyle(.plain)
                    .help(language.text("tipRemoveROI", region.rawValue))
                    .accessibilityLabel(language.text("tipRemoveROI", region.rawValue))
            }
        }
    }

    private func format(_ value: Double, _ digits: Int = 1) -> String {
        language.number(value, digits: digits)
    }
}

private struct MRImageView: View {
    let input: MeasurementInput
    let echoIndex: Int
    let fixedWindow: Bool
    let regions: [Region: ROIShape]
    let active: Region
    let language: UILanguage
    let onDraw: (CGRect) -> Void

    @State private var drag: CGRect?
    @State private var preview: CGImage?

    private var leftMarker: String {
        let direction = input.geometry.rowDirection
        if abs(direction.x) >= abs(direction.y) { return direction.x > 0 ? "R" : "L" }
        return direction.y > 0 ? "A" : "P"
    }

    private var rightMarker: String {
        switch leftMarker {
        case "R": "L"
        case "L": "R"
        case "A": "P"
        default: "A"
        }
    }

    var body: some View {
        GeometryReader { container in
            let width = min(container.size.width, container.size.height * input.aspect)
            let height = width / input.aspect
            let size = CGSize(width: width, height: height)
            ZStack {
                Color.black
                if let preview {
                    Image(decorative: preview, scale: 1).resizable().interpolation(.medium)
                }
                ForEach(Region.allCases) { region in
                    if let roi = regions[region] {
                        outline(region, roi: roi, size: size)
                    }
                }
                if let drag {
                    shape(active, box: drag)
                }
                HStack {
                    Text(leftMarker)
                    Spacer()
                    Text(rightMarker)
                }.font(.caption.monospaced().bold()).foregroundStyle(.white).padding(6)
                    .allowsHitTesting(false)
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 3, coordinateSpace: .local)
                .onChanged { drag = displayRect($0, size: size) }
                .onEnded {
                    let rect = displayRect($0, size: size)
                    drag = nil
                    guard width > 0, height > 0 else { return }
                    let sx = Double(input.width) / width
                    let sy = Double(input.height) / height
                    onDraw(CGRect(x: rect.minX * sx, y: rect.minY * sy, width: rect.width * sx, height: rect.height * sy))
                })
            .position(x: container.size.width / 2, y: container.size.height / 2)
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel(language.text("axialImage"))
        .help(language.text("tipDraw"))
        .onChange(of: echoIndex, initial: true) { updatePreview() }
        .onChange(of: fixedWindow) { updatePreview() }
    }

    private func updatePreview() {
        guard input.echoes.indices.contains(echoIndex) else { return }
        preview = input.image(for: echoIndex, fixedWindow: fixedWindow)
    }

    private func displayRect(_ value: DragGesture.Value, size: CGSize) -> CGRect {
        let end = CGPoint(x: min(size.width, max(0, value.location.x)),
                          y: min(size.height, max(0, value.location.y)))
        return CGRect(x: min(value.startLocation.x, end.x), y: min(value.startLocation.y, end.y),
                      width: abs(value.startLocation.x - end.x), height: abs(value.startLocation.y - end.y))
    }

    private func toDisplay(_ rect: CGRect, size: CGSize) -> CGRect {
        let sx = size.width / Double(input.width)
        let sy = size.height / Double(input.height)
        return CGRect(x: rect.minX * sx, y: rect.minY * sy, width: rect.width * sx, height: rect.height * sy)
    }

    private func outline(_ region: Region, roi: ROIShape, size: CGSize) -> some View {
        let bounds = toDisplay(roi.bounds, size: size)
        let path: Path
        switch roi {
        case .oval: path = Path(ellipseIn: bounds)
        case .rectangle: path = Path(bounds)
        case .polygon(let points):
            let sx = size.width / Double(input.width)
            let sy = size.height / Double(input.height)
            path = Path { line in
                line.addLines(points.map { CGPoint(x: $0.x * sx, y: $0.y * sy) })
                line.closeSubpath()
            }
        }
        return ZStack(alignment: .topLeading) {
            path.stroke(region.color, lineWidth: 2)
            marker(region).position(x: bounds.midX, y: max(7, bounds.minY - 6))
        }.allowsHitTesting(false)
    }

    private func shape(_ region: Region, box: CGRect) -> some View {
        Ellipse()
            .stroke(region.color, lineWidth: 2)
            .overlay(alignment: .top) { marker(region).offset(y: -12) }
            .frame(width: box.width, height: box.height)
            .position(x: box.midX, y: box.midY)
            .allowsHitTesting(false)
    }

    private func marker(_ region: Region) -> some View {
        Text(region.rawValue).font(.caption2.bold()).foregroundStyle(region.color)
            .padding(.horizontal, 3).background(.black.opacity(0.75))
    }
}
