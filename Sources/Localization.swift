// SPDX-License-Identifier: MIT
import Foundation

enum UILanguage: String, CaseIterable, Identifiable {
    case de, en, fr, es, it, pt, ja, zh, tr, ar

    static let preferenceKey = "de.isixplugins.leberquant.language"
    var id: Self { self }
    var locale: Locale { Locale(identifier: self == .zh ? "zh-Hans" : rawValue) }

    var name: String {
        switch self {
        case .de: "Deutsch"
        case .en: "English"
        case .fr: "Français"
        case .es: "Español"
        case .it: "Italiano"
        case .pt: "Português"
        case .ja: "日本語"
        case .zh: "简体中文"
        case .tr: "Türkçe"
        case .ar: "العربية"
        }
    }

    static func preferred(from identifiers: [String]) -> Self {
        identifiers.lazy.compactMap { identifier -> Self? in
            guard let code = Locale(identifier: identifier).language.languageCode?.identifier else { return nil }
            return Self(rawValue: code)
        }.first ?? .en
    }

    static var systemDefault: Self { preferred(from: Locale.preferredLanguages) }
    static var current: Self {
        UserDefaults.standard.string(forKey: preferenceKey).flatMap(Self.init(rawValue:)) ?? systemDefault
    }

    func text(_ key: String, _ values: String...) -> String { render(key, values) }

    fileprivate func render(_ key: String, _ values: [String]) -> String {
        TranslationCatalog.plugin.text(key, in: self, values: values)
    }

    func number(_ value: Double?, digits: Int = 1) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.locale(locale).precision(.fractionLength(digits)))
    }
}

struct LocalizedMessage {
    let key: String
    let values: [String]
    private let hostText: String?
    private var prefix: String?

    init(_ key: String, _ values: [String] = []) {
        self.key = key
        self.values = values
        hostText = nil
    }

    init(_ error: Error) {
        if let own = error as? QuantificationError {
            self = own.message
        } else {
            key = "errorHost"
            values = []
            hostText = error.localizedDescription
        }
    }

    func prefixed(by label: String) -> Self {
        var copy = self
        copy.prefix = label
        return copy
    }

    func text(in language: UILanguage) -> String {
        let text = hostText.map { language.text(key, $0) } ?? language.render(key, values)
        return prefix.map { $0 + " · " + text } ?? text
    }
}

@objc(LiverIronLoadLocalizationResource)
private final class LocalizationResource: NSObject {}

struct TranslationCatalog {
    let rows: [String: [UILanguage: String]]

    init(_ content: String) {
        var result: [String: [UILanguage: String]] = [:]
        for line in content.split(whereSeparator: \.isNewline) where !line.hasPrefix("#") {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count == UILanguage.allCases.count + 1 else { continue }
            result[fields[0]] = Dictionary(uniqueKeysWithValues: zip(UILanguage.allCases, fields.dropFirst()))
        }
        rows = result
    }

    func text(_ key: String, in language: UILanguage, values: [String] = []) -> String {
        let entry = rows[key]
        let template = entry?[language] ?? entry?[.en] ?? key
        guard !values.isEmpty else { return template }
        // One pass keeps text inserted from DICOM metadata or the host literal.
        let pieces = template.split(separator: "{", omittingEmptySubsequences: false)
        return pieces.dropFirst().reduce(String(pieces[0])) { result, piece in
            let parts = piece.split(separator: "}", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2, let index = Int(parts[0]), values.indices.contains(index) else {
                return result + "{" + piece
            }
            return result + values[index] + parts[1]
        }
    }

    static let plugin: Self = {
        let bundle = Bundle(for: LocalizationResource.self)
        let file = bundle.url(forResource: "Translations", withExtension: "tsv")
        return Self(file.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "")
    }()
}
