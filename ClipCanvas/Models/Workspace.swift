import Foundation
import SwiftData

// @Model marks this class for SwiftData persistence — stored in an on-device SQLite database.
@Model
final class Workspace {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var sortIndex: Int  // controls the order workspaces appear in the sidebar list
    var isActive: Bool  // only one workspace should be active at a time
    // @Relationship with .cascade means deleting a Workspace also deletes all its cards and threads.
    // `inverse` tells SwiftData which property on the child points back to this parent.
    var drawingData: Data?  // serialised PKDrawing — nil means no drawing on this workspace
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
        self.drawingData = nil
        self.cards = []
        self.chatThreads = []
    }
}

// @Model marks this class for SwiftData persistence.
@Model
final class WorkspaceCard {
    var id: UUID
    var workspace: Workspace?   // parent; nil if the workspace was deleted
    var snippet: Snippet?       // the clipboard content this card displays
    var transformRun: TransformRun? // set when this card holds an AI-generated result
    var x: Double               // position on the infinite canvas (unscaled coordinates)
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

extension Workspace {
    // @discardableResult lets callers ignore the returned card without a compiler warning.
    // Every card insertion goes through here so relationship wiring stays consistent.
    @discardableResult
    func addCard(
        snippet: Snippet,
        transformRun: TransformRun? = nil,
        x: Double,
        y: Double,
        width: Double? = nil,
        height: Double? = nil,
        color: CardColor? = nil
    ) -> WorkspaceCard {
        let card = WorkspaceCard(
            snippet: snippet,
            transformRun: transformRun,
            x: x,
            y: y,
            width: width ?? snippet.defaultCardSize.width,
            height: height ?? snippet.defaultCardSize.height,
            color: color ?? snippet.cardVariant
        )
        card.workspace = self
        cards.append(card)
        updatedAt = Date()
        return card
    }

    // Staggers new card positions so repeated pastes don't land exactly on top of each other.
    // Uses modulo arithmetic to cycle through a small grid of offsets.
    func nextCardPosition(offset: Double = 0) -> (x: Double, y: Double) {
        let index = Double(cards.count)
        return (
            x: 180 + offset + (index.truncatingRemainder(dividingBy: 5) * 28),
            y: 160 + offset + (index.truncatingRemainder(dividingBy: 7) * 22)
        )
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
