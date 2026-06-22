import Foundation

nonisolated enum ICloudProfileStatus: Equatable {
    case checking
    case available
    case noAccount
    case unavailable
}

enum ICloudAccountService {
    static func currentStatus() -> ICloudProfileStatus {
        FileManager.default.ubiquityIdentityToken == nil ? .noAccount : .available
    }
}
