import UIKit
import RevenueCat
import RevenueCatUI
import FirebaseAuth
import FirebaseFirestore

class PremiumData {
    var productId: String
    var purchaseDate: String
    var expirationDate: String
    var store: String
    var isSandbox: Bool
    var transactionId: String
    var ownershipType: String
    
    init(productId: String,
         purchaseDate: Any?,
         expirationDate: Any?,
         store: String,
         isSandbox: Bool,
         transactionId: String,
         ownershipType: String) {
        
        // Force everything to String for Firestore keys
        if let date = purchaseDate as? Date {
            self.purchaseDate = date.iso8601String
        } else if let intVal = purchaseDate as? Int {
            self.purchaseDate = String(intVal)
        } else if let strVal = purchaseDate as? String {
            self.purchaseDate = strVal
        } else {
            self.purchaseDate = ""
        }
        
        if let date = expirationDate as? Date {
            self.expirationDate = date.iso8601String
        } else if let intVal = expirationDate as? Int {
            self.expirationDate = String(intVal)
        } else if let strVal = expirationDate as? String {
            self.expirationDate = strVal
        } else {
            self.expirationDate = ""
        }
        
        self.productId = productId
        self.store = store
        self.isSandbox = isSandbox
        self.transactionId = transactionId
        self.ownershipType = ownershipType
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "productId": productId,
            "purchaseDate": purchaseDate,
            "expirationDate": expirationDate,
            "store": store,
            "isSandbox": isSandbox,
            "transactionId": transactionId,
            "ownershipType": ownershipType
        ]
    }
}

extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}

extension CustomerInfo {
    var latestTransactionIdentifierSafe: String {
        if let latestNonSub = self.nonSubscriptionTransactions.sorted(by: { $0.purchaseDate > $1.purchaseDate }).first {
            return latestNonSub.transactionIdentifier
        }
        return ""
    }
}
