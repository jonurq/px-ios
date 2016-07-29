//
//  PaymentInfo.swift
//  MercadoPagoSDK
//
//  Created by Maria cristina rodriguez on 29/7/16.
//  Copyright © 2016 MercadoPago. All rights reserved.
//

import UIKit

public class PaymentInfo: NSObject {
    
    var amount : Double?
    var currency : Currency?

    override init(){
        super.init()
    }
    
    public class func fromJSON(json : NSDictionary) -> PaymentInfo {
        let paymentInfo : PaymentInfo = PaymentInfo()
        
        if json["amount"] != nil && !(json["amount"]! is NSNull) {
            paymentInfo.amount = JSON(json["amount"]!).asDouble!
        }
        
        let currency = Currency()
        if json["thousands_separator"] != nil && !(json["thousands_separator"]! is NSNull) {
            currency.thousandsSeparator = json["thousands_separator"] as! Character
        }
        
        if json["decimal_separator"] != nil && !(json["decimal_separator"]! is NSNull) {
            currency.decimalSeparator = json["decimal_separator"] as! Character
        }
        
        if json["symbol"] != nil && !(json["symbol"]! is NSNull) {
            currency.symbol = json["symbol"] as! String
        }
        
        if json["decimal_places"] != nil && !(json["decimal_places"]! is NSNull) {
            currency.decimalPlaces = json["decimal_places"] as! Int
        }
        
        paymentInfo.currency = currency
        return paymentInfo
    }
}
