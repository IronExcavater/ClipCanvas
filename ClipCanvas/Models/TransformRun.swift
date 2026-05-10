import Foundation
import SwiftData

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

@Model
final class TransformRun {
    var id: UUID
    var workspace: Workspace?
    var inputCardIDs: [UUID]
    var kind: TransformKind
    var operationLabel: String
    var inputText: String
    var outputText: String
    var status: TransformStatus
    var createdAt: Date
    var errorMessage: String?

    init(
        workspace: Workspace?,
        inputCardIDs: [UUID],
        kind: TransformKind,
        operationLabel: String,
        inputText: String,
        outputText: String = "",
        status: TransformStatus = .pending,
        errorMessage: String? = nil
    ) {
        self.id = UUID()
        self.workspace = workspace
        self.inputCardIDs = inputCardIDs
        self.kind = kind
        self.operationLabel = operationLabel
        self.inputText = inputText
        self.outputText = outputText
        self.status = status
        self.createdAt = Date()
        self.errorMessage = errorMessage
    }
}
