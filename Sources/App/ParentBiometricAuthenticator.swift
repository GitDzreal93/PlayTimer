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

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "验证家长身份"
            )
        } catch {
            // 用户主动取消或点 fallback 不是错误，静默返回未验证
            if let laError = error as? LAError,
               laError.code == .userCancel || laError.code == .systemCancel || laError.code == .appCancel {
                return false
            }
            throw error
        }
    }
}
