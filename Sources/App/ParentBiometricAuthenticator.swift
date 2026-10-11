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

    func authenticateDeviceOwnerForPINRecovery() async throws -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "使用设备密码"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw error ?? ParentAuthenticationError.unavailable
        }

        return try await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "验证 iPad 设备所有者身份后重设家长 PIN 和找回问题"
        )
    }
}

private enum ParentAuthenticationError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "这台 iPad 暂时无法验证设备所有者身份。请确认已设置设备密码后重试。"
    }
}
