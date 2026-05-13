import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

struct FoundationTransformProvider {
    var isAvailable: Bool = true

    func transform(skillID: String, input: TransformSkillInput) async throws -> String? {
        guard isAvailable else { return nil }
        #if canImport(FoundationModels)
        return nil
        #else
        return nil
        #endif
    }
}
