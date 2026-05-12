extension Array where Element == Clip {
    func sortedForPinnedRecency() -> [Clip] {
        sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.updatedAt > $1.updatedAt
        }
    }
}
