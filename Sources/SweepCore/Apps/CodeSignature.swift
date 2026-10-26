import Foundation
#if canImport(Security)
import Security
#endif

public enum CodeSignature {
    /// The developer team that signed the bundle, e.g. "UBF8T346G9" for Microsoft. Nil for unsigned and
    /// ad-hoc signed bundles.
    public static func teamID(of url: URL) -> String? {
        #if canImport(Security)
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let info = info as? [String: Any] else { return nil }
        return info[kSecCodeInfoTeamIdentifier as String] as? String
        #else
        return nil
        #endif
    }
}
