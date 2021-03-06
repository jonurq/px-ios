//
//  Refund.swift
//  MercadoPagoSDK
//
//  Created by Matias Gualino on 6/3/15.
//  Copyright (c) 2015 com.mercadopago. All rights reserved.
//

import Foundation

public class Refund : NSObject {
    public var amount : Double = 0
    public var dateCreated : NSDate!
    public var _id : Int = 0
    public var metadata : NSObject!
    public var paymentId : Int = 0
    public var source : String!
    public var uniqueSequenceNumber : String!
    
    public class func fromJSON(json : NSDictionary) -> Refund {
        let refund : Refund = Refund()
		if json["id"] != nil && !(json["id"]! is NSNull) {
			refund._id = (json["id"] as? Int)!
		}
		if json["amount"] != nil && !(json["amount"]! is NSNull) {
			refund.amount = (json["amount"] as? Double)!
		}
        refund.source = JSON(json["source"]!).asString
        refund.uniqueSequenceNumber = JSON(json["unique_sequence_number"]!).asString
		if json["payment_id"] != nil && !(json["payment_id"]! is NSNull) {
			refund.paymentId = (json["payment_id"] as? Int)!
		}
        refund.dateCreated = Utils.getDateFromString(json["date_created"] as? String)
        return refund
    }
    
}
