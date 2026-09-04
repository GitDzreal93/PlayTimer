import Foundation
import LocalAuthentication

struct ParentBiometricAuthenticator {
    func authenticate() async throws -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = ""

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error {
                throw error
            }
            return false
        }

        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "验证家长身份"
        )
    }
}
