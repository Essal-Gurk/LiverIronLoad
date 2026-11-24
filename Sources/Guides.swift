// SPDX-License-Identifier: MIT
import SwiftUI

struct AcquisitionGuideView: View {
    @AppStorage(UILanguage.preferenceKey) private var language = UILanguage.systemDefault

    var body: some View { ScrollView { content } }

    var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(language.text("guideTitle")).font(.title2.bold())
            section(language.text("researchStatus"), language.text("tipResearchStatus"))
            section(language.text("guideBefore"),
                    language.text("guideBeforeDetail"))
            section(language.text("guideTiming"),
                    language.text("guideTimingDetail"))
            section(language.text("guideExport"),
                    language.text("guideExportDetail"))
            section(language.text("guideReview"),
                    language.text("guideReviewDetail"))
            section(language.text("guideLoss"),
                    language.text("guideLossDetail"))
            Link(language.text("linkMRQ"),
                 destination: URL(string: "https://radsapp.net/mrquantif/protocols")!)
                .help(language.text("tipLink"))
            Link(language.text("linkESGAR"),
                 destination: URL(string: "https://doi.org/10.1148/radiol.221856")!)
                .help(language.text("tipLink"))
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section(_ title: String, _ content: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.headline)
            Text(content).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ROIGuideView: View {
    @AppStorage(UILanguage.preferenceKey) private var language = UILanguage.systemDefault

    private let markers: [(Region, CGPoint)] = [
        (.liver1, CGPoint(x: 0.28, y: 0.38)),
        (.liver2, CGPoint(x: 0.23, y: 0.56)),
        (.liver3, CGPoint(x: 0.45, y: 0.39)),
        (.noise, CGPoint(x: 0.10, y: 0.12)),
        (.spleen, CGPoint(x: 0.81, y: 0.49)),
        (.pancreas, CGPoint(x: 0.60, y: 0.52)),
        (.fat, CGPoint(x: 0.10, y: 0.54)),
        (.muscleRight, CGPoint(x: 0.40, y: 0.74)),
        (.muscleLeft, CGPoint(x: 0.60, y: 0.74))
    ]

    var body: some View { ScrollView { content } }

    var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(language.text("schemaTitle")).font(.headline)
            Canvas { context, size in
                let scale = CGAffineTransform(scaleX: size.width, y: size.height)
                func fill(_ contour: Path, _ color: Color) {
                    context.fill(contour.applying(scale), with: .color(color))
                }
                fill(Path(ellipseIn: CGRect(x: 0.06, y: 0.16, width: 0.88, height: 0.70)), Color(white: 0.27))
                fill(Path(ellipseIn: CGRect(x: 0.11, y: 0.20, width: 0.78, height: 0.62)), Color(white: 0.15))
                fill(Path { p in
                    p.move(to: CGPoint(x: 0.13, y: 0.43))
                    p.addQuadCurve(to: CGPoint(x: 0.31, y: 0.28), control: CGPoint(x: 0.19, y: 0.26))
                    p.addQuadCurve(to: CGPoint(x: 0.65, y: 0.35), control: CGPoint(x: 0.47, y: 0.28))
                    p.addQuadCurve(to: CGPoint(x: 0.50, y: 0.49), control: CGPoint(x: 0.67, y: 0.45))
                    p.addQuadCurve(to: CGPoint(x: 0.36, y: 0.53), control: CGPoint(x: 0.37, y: 0.45))
                    p.addQuadCurve(to: CGPoint(x: 0.19, y: 0.65), control: CGPoint(x: 0.31, y: 0.66))
                    p.addQuadCurve(to: CGPoint(x: 0.13, y: 0.43), control: CGPoint(x: 0.11, y: 0.58))
                    p.closeSubpath()
                }, Color(red: 0.50, green: 0.30, blue: 0.24))
                fill(Path(ellipseIn: CGRect(x: 0.75, y: 0.35, width: 0.13, height: 0.27)),
                     Color(red: 0.25, green: 0.51, blue: 0.47))
                fill(Path(ellipseIn: CGRect(x: 0.435, y: 0.58, width: 0.13, height: 0.13)), Color(white: 0.56))
                fill(Path(ellipseIn: CGRect(x: 0.49, y: 0.47, width: 0.22, height: 0.10)),
                     Color(red: 0.52, green: 0.34, blue: 0.41))
                for x in [0.34, 0.54] {
                    fill(Path(ellipseIn: CGRect(x: x, y: 0.66, width: 0.12, height: 0.15)), Color(white: 0.35))
                }
                for (region, point) in markers {
                    let center = CGPoint(x: point.x * size.width, y: point.y * size.height)
                    let circle = CGRect(x: center.x - 12, y: center.y - 12, width: 24, height: 24)
                    context.fill(Path(ellipseIn: circle), with: .color(.black.opacity(0.7)))
                    context.stroke(Path(ellipseIn: circle), with: .color(region.color), lineWidth: 1.5)
                    context.draw(Text(region.rawValue).font(.system(size: 9, weight: .bold)).foregroundStyle(region.color), at: center)
                }
                for (label, x) in [("R", 0.065), ("L", 0.935)] {
                    context.draw(Text(label).font(.caption.bold()).foregroundStyle(.white),
                                 at: CGPoint(x: size.width * x, y: size.height * 0.45))
                }
            }
            .frame(height: 205)
            .background(.black, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                GeometryReader { geometry in
                    ForEach(markers, id: \.0) { region, point in
                        Color.clear
                            .frame(width: 24, height: 24)
                            .contentShape(Circle())
                            .help(region.tooltip(in: language))
                            .position(x: point.x * geometry.size.width, y: point.y * geometry.size.height)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 7) {
                Text(language.text("schemaLiver")).bold()
                Text(language.text("schemaLiverDetail"))
                Text(language.text("schemaNoise")).bold()
                Text(language.text("schemaNoiseDetail"))
                Text(language.text("schemaOptional")).bold()
                Text(language.text("schemaOptionalDetail"))
            }.font(.callout)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
    }
}
