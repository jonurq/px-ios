//
//  InstructionsService.swift
//  MercadoPagoSDK
//
//  Created by Maria cristina rodriguez on 16/2/16.
//  Copyright © 2016 MercadoPago. All rights reserved.
//

import UIKit
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


open class InstructionsService: MercadoPagoService {

    open let MP_INSTRUCTIONS_URI = MercadoPago.MP_ENVIROMENT + "/payments/${payment_id}/results"
    
    public init(){
        super.init(baseURL: MercadoPago.MP_API_BASE_URL)
    }
    
    @available(*, deprecated: 2.2.4, message: "Use getInstructions(_ paymentId : String, ...) instead. PaymentId can be greater than Int and might fail")
    open func getInstructions(_ paymentId : Int, paymentTypeId: String? = "", success : @escaping (_ instructionsInfo : InstructionsInfo) -> Void, failure: ((_ error: NSError) -> Void)?){
        let paymentId = String(paymentId)
        self.getInstructions(for: paymentId, paymentTypeId: paymentTypeId, success: success, failure: failure)
    }
    
    open func getInstructions(for paymentId : String, paymentTypeId: String? = "", success : @escaping (_ instructionsInfo : InstructionsInfo) -> Void, failure: ((_ error: NSError) -> Void)?){
        var params =  "public_key=" + MercadoPagoContext.publicKey()
        if paymentTypeId != nil && paymentTypeId?.characters.count > 0 {
            params = params + "&payment_type=" + paymentTypeId!
        }
        params = params + "&api_version=" + MercadoPago.API_VERSION
        self.request(uri: MP_INSTRUCTIONS_URI.replacingOccurrences(of: "${payment_id}", with: paymentId), params: params, body: nil, method: "GET", cache: false, success: { (jsonResult) -> Void in
            let error = jsonResult?["error"] as? String
            if error != nil && error!.characters.count > 0 {
                let e : NSError = NSError(domain: "com.mercadopago.sdk.getInstructions", code: MercadoPago.ERROR_INSTRUCTIONS, userInfo: [NSLocalizedDescriptionKey : "No se ha podido obtener las intrucciones correspondientes al pago".localized, NSLocalizedFailureReasonErrorKey : jsonResult!["error"] as! String])
                failure!(e)
            } else {
                success(InstructionsInfo.fromJSON(jsonResult as! NSDictionary))
            }
        }, failure: failure)
    }
}
