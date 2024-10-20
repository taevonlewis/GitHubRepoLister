import Security

struct KeychainHelper {
    static func saveToken(account: String, token: String) {
        let tokenData = token.data(using: .utf8)!
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecValueData: tokenData
        ] as CFDictionary
        
        // Add or update the keychain item
        SecItemDelete(query)
        SecItemAdd(query, nil)
    }

    static func getToken(account: String) -> String? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary
        
        var item: AnyObject?
        SecItemCopyMatching(query, &item)
        
        guard let tokenData = item as? Data,
              let token = String(data: tokenData, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
}