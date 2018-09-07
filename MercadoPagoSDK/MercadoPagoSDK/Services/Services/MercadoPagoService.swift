//
//  MercadoPagoService.swift
//  MercadoPagoSDK
//
//  Created by Matias Gualino on 5/2/15.
//  Copyright (c) 2015 com.mercadopago. All rights reserved.
//

import Foundation

internal class MercadoPagoService: NSObject {

    let MP_DEFAULT_TIME_OUT = 15.0

    var baseURL: String!
    init (baseURL: String) {
        super.init()
        self.baseURL = baseURL
    }

    internal func request(uri: String, params: String?, body: Data?, method: HTTPMethod, headers: [String: String]? = nil, cache: Bool = true, success: @escaping (_ data: Data) -> Void,
                          failure: ((_ error: NSError) -> Void)?) {

        let url = baseURL + uri
        var requesturl = url

        if let params = params, !String.isNullOrEmpty(params), let escapedParams = params.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
            requesturl += "?" + escapedParams
        }

        var cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
        if cache {
            cachePolicy = .returnCacheDataElseLoad
        }

        let Rurl = URL(string: requesturl)
        var request = URLRequest(url: Rurl!)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.cachePolicy = cachePolicy
        request.timeoutInterval = MP_DEFAULT_TIME_OUT

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let sdkVersion = PXServicesURLConfigs.PX_SDK_VERSION {
            let value = "PX/iOS/" + sdkVersion
            request.setValue(value, forHTTPHeaderField: "User-Agent")
        }

        if let headers = headers {
            for header in headers {
                request.setValue(header.value, forHTTPHeaderField: header.key)
            }
        }

        MercadoPagoSDKV4.request(request).responseData { response in
            MercadoPagoService.debugPrint(response: response)

            if let data = response.result.value, response.error == nil {
                success(data)
            } else if let error = response.error as NSError? {
                failure?(error)
            } else {
                let error: NSError = NSError(domain: "com.mercadopago.sdk", code: NSURLErrorCannotDecodeContentData, userInfo: nil)
                failure?(error)
            }
        }
    }
}

extension MercadoPagoService {
    static func debugPrint(response: DataResponse<Data>?) {
        guard let response = response else {
            return
        }
        #if DEBUG
        print("--Request: \(String(describing: response.request))")
        if let body = response.request?.httpBody {
            print("--Request Body: \(String(describing: String(data: body, encoding: .utf8)))")
        }
        if let data = response.result.value, let utf8Text = String(data: data, encoding: .utf8) {
            print("--Data: \(utf8Text)")
        }
        print("--Error: \(String(describing: response.error))")
        #endif
    }
}
