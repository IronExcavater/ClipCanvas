import Foundation
import SwiftData

@Model
final class Workspace {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var sortIndex: Int
    var isActive: Bool
    @Relationship(deleteRule: .cascade, inverse: \WorkspaceCard.workspace) var cards: [WorkspaceCard]
    @Relationship(deleteRule: .cascade, inverse: \WorkspaceChatThread.workspace) var chatThreads: [WorkspaceChatThread]

    init(
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isArchived: Bool = false,
        sortIndex: Int = 0,
        isActive: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.sortIndex = sortIndex
        self.isActive = isActive
        self.cards = []
        self.chatThreads = []
    }
}

@Model
final class WorkspaceCard {
    var id: UUID
    var workspace: Workspace?
    var snippet: Snippet?
    var transformRun: TransformRun?
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var color: CardColor
    var createdAt: Date
    var updatedAt: Date

    init(
        snippet: Snippet? = nil,
        transformRun: TransformRun? = nil,
        x: Double = 120,
        y: Double = 160,
        width: Double = 220,
        height: Double = 150,
        color: CardColor = .default
    ) {
        self.id = UUID()
        self.workspace = nil
        self.snippet = snippet
        self.transformRun = transformRun
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.color = color
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum CardColor: String, Codable, CaseIterable {
    case `default`
    case yellow
    case blue
    case green
    case pink
    case purple

    var label: String {
        switch self {
        case .default: "Default"
        case .yellow: "Yellow"
        case .blue: "Blue"
        case .green: "Green"
        case .pink: "Pink"
        case .purple: "Purple"
        }
    }
}
