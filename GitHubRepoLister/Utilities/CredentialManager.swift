////
//  CredentialManager.swift
//  GitHubRepoLister
//
//  Created by TaeVon Lewis on 10/20/24.
//


#if os(Windows)
import WinSDK

struct CredentialManager {
    static func saveToken(account: String, token: String) {
        let tokenData = token.data(using: .utf8)!
        let credential = CREDENTIALW(
            Flags: 0,
            Type: CRED_TYPE_GENERIC,
            TargetName: account.wide(),
            Comment: nil,
            LastWritten: FILETIME(),
            CredentialBlobSize: DWORD(tokenData.count),
            CredentialBlob: tokenData.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: BYTE.self) },
            Persist: CRED_PERSIST_LOCAL_MACHINE,
            AttributeCount: 0,
            Attributes: nil,
            TargetAlias: nil,
            UserName: nil
        )

        guard CredWriteW(&credential, 0) else {
            print("Failed to save token for account \(account)")
            return
        }
        print("Token saved successfully.")
    }

    static func getToken(account: String) -> String? {
        var credentialPtr: UnsafeMutablePointer<CREDENTIALW>?
        guard CredReadW(account.wide(), CRED_TYPE_GENERIC, 0, &credentialPtr) else {
            print("No token found for account \(account)")
            return nil
        }

        guard let credential = credentialPtr?.pointee,
              let blob = credential.CredentialBlob else {
            return nil
        }

        let token = String(bytesNoCopy: blob, length: Int(credential.CredentialBlobSize), encoding: .utf8, freeWhenDone: false)
        CredFree(credentialPtr)
        return token
    }
}

// Helper extension for converting Swift strings to wide strings for WinSDK API.
extension String {
    func wide() -> UnsafePointer<WCHAR> {
        return self.withCString(encodedAs: UTF16.self) { $0 }
    }
}
#endif