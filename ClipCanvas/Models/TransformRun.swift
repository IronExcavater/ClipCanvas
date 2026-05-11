import Foundation
import SwiftData

// Which AI transform was requested.
enum TransformKind: String, Codable, CaseIterable {
    case distill
    case actionItems
    case cleanUp
    case rewrite
    case title

    var label: String {
        switch self {
        case .distill: "Distill"
        case .actionItems: "Actions"
        case .cleanUp: "Clean Up"
        case .rewrite: "Rewrite"
        case .title: "Title"
        }
    }
}

enum TransformStatus: String, Codable, CaseIterable {
    case pending
    case done
    case failed
}

// @Model marks this class for SwiftData persistence — it is stored in SQLite on-device.
@Model
final class TransformRun {
    var id: UUID
    var workspace: Workspace?   // nil if the workspace was deleted after the run
    var inputCardIDs: [UUID]    // UUIDs of source cards; kept even if those cards are later deleted
    var kind: TransformKind
    var inputText: String
    var outputText: String
    var status: TransformStatus
    var createdAt: Date
    var errorMessage: String?   // populated only when status == .failed

    init(
        workspace: Workspace?,
        inputCardIDs: [UUID],
        kind: TransformKind,
        inputText: String,
        outputText: String = "",
        status: TransformStatus = .pending,
        errorMessage: String? = nil
    ) {
        self.id = UUID()
        self.workspace = workspace
        self.inputCardIDs = inputCardIDs
        self.kind = kind
        self.inputText = inputText
        self.outputText = outputText
        self.status = status
        self.createdAt = Date()
        self.errorMessage = errorMessage
    }
}
