import Combine
import Foundation

enum AIReadMode: String, CaseIterable, Identifiable {
    case pdf, text
    var id: String { rawValue }
}
enum AIPDFQuality: String, CaseIterable, Identifiable {
    case high, light
    var id: String { rawValue }
}
enum AIOCRPreparation: String, CaseIterable, Identifiable {
    case basic, corrected
    var id: String { rawValue }
}

@MainActor final class AIReadSettings: ObservableObject {
    static let shared = AIReadSettings()
    @Published var mode: AIReadMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "ai.read.mode") }
    }
    @Published var pdfQuality: AIPDFQuality {
        didSet { UserDefaults.standard.set(pdfQuality.rawValue, forKey: "ai.pdf.quality") }
    }
    @Published var ocrPreparation: AIOCRPreparation {
        didSet { UserDefaults.standard.set(ocrPreparation.rawValue, forKey: "ai.ocr.preparation") }
    }
    private init() {
        mode = AIReadMode(rawValue: UserDefaults.standard.string(forKey: "ai.read.mode") ?? "") ?? .pdf
        pdfQuality =
            AIPDFQuality(rawValue: UserDefaults.standard.string(forKey: "ai.pdf.quality") ?? "") ?? .high
        ocrPreparation =
            AIOCRPreparation(rawValue: UserDefaults.standard.string(forKey: "ai.ocr.preparation") ?? "")
            ?? .basic
    }
}
