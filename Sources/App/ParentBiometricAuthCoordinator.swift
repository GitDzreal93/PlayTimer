import Foundation
import LocalAuthentication

@MainActor
final class ParentBiometricAuthCoordinator: ObservableObject {
    @Published private(set) var isAuthenticating = false

    private var context: LAContext?

    func authenticate(reason: String) async -> Bool {
        guard !isAuthenticating else { return false }

        isAuthenticating = true
        defer {
            isAuthenticating = false
            context = nil
        }

        let context = LAContext()
        context.localizedCancelTitle = "取消"
        context.localizedFallbackTitle = "输入 iPad 密码"
        self.context = context

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }

        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            if let laError = error as? LAError,
               laError.code == .userCancel ||
               laError.code == .systemCancel ||
               laError.code == .appCancel {
                return false
            }
            return false
        }
    }
}
