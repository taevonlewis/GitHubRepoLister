////
//  KeychainHelper.swift
//  GitHubRepoLister
//
//  Created by TaeVon Lewis on 10/19/24.
//

import Foundation
import Security

struct KeychainHelper {
    static func saveToken(account: String, token: String) {
        let tokenData = token.data(using: .utf8)!
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecValueData: tokenData
        ] as CFDictionary
        
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

    static func removeToken(account: String) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account
        ] as CFDictionary
        SecItemDelete(query)
    }

    static func setActiveAccount(_ account: String) {
        UserDefaults.standard.set(account, forKey: "activeAccount")
    }

    static func getActiveAccount() -> String? {
        return UserDefaults.standard.string(forKey: "activeAccount")
    }

    static func removeActiveAccount() {
        UserDefaults.standard.removeObject(forKey: "activeAccount")
    }
}
