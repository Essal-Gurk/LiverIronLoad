// SPDX-License-Identifier: MIT
import AppKit
import IsiXPluginKit
import SwiftUI

@MainActor
public final class IsiXLeberQuantPlugin: IsiXPlugin {
    private var measurement: NSWindow?
    private var diagram: NSPanel?
    private var info: NSPanel?
    private var observation: IsiXObservation?
    private var model: MeasurementModel?
    private var fourDCache: [[String]: IsiXViewer] = [:]

    public init() {}

    public func activate(with context: IsiXPluginContext) throws {
        try context.register(IsiXCommand(id: "leberquant-measure", title: "Liver IronLoad · " + UILanguage.current.text("menuMeasurement"),
                                         placement: .imageFilters, requirement: .viewer)) { [weak self] invocation in
            guard let viewer = invocation.viewer else { return }
            self?.prepareMeasurement(context: context, viewer: viewer)
        }
        try context.register(IsiXCommand(id: "leberquant-info", title: "Liver IronLoad · " + UILanguage.current.text("guide") + " …",
                                         placement: .imageFilters, requirement: .none)) { [weak self] _ in
            self?.showInfo()
        }
        observation = try context.observe([.viewerWillClose]) { [weak self] event in
            guard case .viewerWillClose(let id) = event, let self else { return }
            // Do not call the closing viewer from its own close notification.
            self.model?.viewerWillClose(id)
        }
    }

    public func deactivate() {
        observation?.invalidate()
        observation = nil
        model = nil
        fourDCache = [:]
        measurement?.close()
        diagram?.close()
        info?.close()
        measurement = nil
        diagram = nil
        info = nil
    }

    private func prepareMeasurement(context: IsiXPluginContext, viewer: IsiXViewer) {
        do {
            let preparation = try Automatic4D.prepare(context: context, reference: viewer, cache: &fourDCache)
            showMeasurement(context: context, viewer: preparation.reference, preparation: preparation)
        } catch {
            let preparation = Automatic4D.Preparation(reference: viewer, notice: LocalizedMessage(error))
            showMeasurement(context: context, viewer: viewer, preparation: preparation)
        }
    }

    private func showMeasurement(context: IsiXPluginContext, viewer: IsiXViewer,
                                 preparation: Automatic4D.Preparation) {
        // Reinvoking on the same viewer preserves the in-progress ROI placements.
        if let window = measurement,
           let host = window.contentViewController as? NSHostingController<MeasurementView>,
           host.rootView.model.viewerID == viewer.id,
           window.isVisible {
            window.makeKeyAndOrderFront(nil)
            showDiagram()
            return
        }
        measurement?.close()
        let model = MeasurementModel(context: context, reference: viewer, preparation: preparation)
        self.model = model
        let view = MeasurementView(model: model, showDiagram: { [weak self] in self?.showDiagram() },
                                   showInfo: { [weak self] in self?.showInfo() },
                                   updateWindowTitles: { [weak self] in self?.updateTitles(in: $0) })
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Liver IronLoad"
        window.setContentSize(NSSize(width: 980, height: 730))
        window.minSize = NSSize(width: 760, height: 550)
        window.isReleasedWhenClosed = false
        window.center()
        if let bounds = window.screen?.visibleFrame, bounds.width >= 1160 {
            let size = window.frame.size
            let width = min(size.width, bounds.width - 390)
            window.setFrame(NSRect(x: bounds.minX + 8, y: window.frame.minY, width: width, height: size.height),
                            display: false)
        }
        measurement = window
        window.makeKeyAndOrderFront(nil)
        showDiagram()
    }

    private func showDiagram() {
        let panel = diagram ?? makePanel("Liver IronLoad · " + UILanguage.current.text("diagram"), size: NSSize(width: 370, height: 523),
                                        view: ROIGuideView())
        if let screen = measurement?.screen, let base = measurement?.frame {
            let bounds = screen.visibleFrame
            panel.setFrameTopLeftPoint(NSPoint(x: min(base.maxX + 10, bounds.maxX - panel.frame.width - 10),
                                               y: min(base.maxY, bounds.maxY - 10)))
        }
        diagram = panel
        panel.orderFront(nil)
    }

    private func showInfo() {
        if let info {
            info.makeKeyAndOrderFront(nil)
            return
        }
        let panel = makePanel("Liver IronLoad · " + UILanguage.current.text("guide"), size: NSSize(width: 530, height: 600),
                              view: AcquisitionGuideView())
        info = panel
        panel.makeKeyAndOrderFront(nil)
    }

    private func updateTitles(in language: UILanguage) {
        diagram?.title = "Liver IronLoad · " + language.text("diagram")
        info?.title = "Liver IronLoad · " + language.text("guide")
    }

    private func makePanel<Content: View>(_ title: String, size: NSSize, view: Content) -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.titled, .closable, .resizable, .utilityWindow],
                            backing: .buffered, defer: false)
        panel.contentViewController = NSHostingController(rootView: view)
        panel.title = title
        panel.setContentSize(size)
        panel.minSize = NSSize(width: min(340, size.width), height: 350)
        panel.isFloatingPanel = true
        panel.isReleasedWhenClosed = false
        panel.center()
        return panel
    }
}
