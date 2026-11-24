import Foundation
import DaiJishowMorph
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

extension StudyStore {
    func saveExportFile(content: String, suggestedName: String, format: AnkiExportFormat) {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(suggestedName).\(format.fileExtension)"
        if #available(macOS 12.0, *) {
            panel.allowedContentTypes = [format == .csv ? .commaSeparatedText : .tabSeparatedText]
        }
        if panel.runModal() == .OK, let url = panel.url {
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
        #endif
    }
}
