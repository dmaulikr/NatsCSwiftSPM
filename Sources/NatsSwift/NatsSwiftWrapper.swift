//
//  NatsSwiftWrapper.swift
//  NatsCSwift
//
//  Created by Desai on 17/01/25.
//

import Foundation
import NatsC

public class NatsSwiftWrapper {
    private var optsPtr: UnsafeMutablePointer<natsOptions>?
    private var connPtr: UnsafeMutablePointer<natsConnection>?

    public private(set) var isConnected = false

    public init() {
        // lazy creation of natsOptions in connectWithNKey
    }

    deinit {
        close()
    }

    /// Connect to NATS with public key + seed, specifying a URL. Calls completion with true/false.
    public func connectWithNKey(
        publicKey: String,
        seedContent: String,
        url: String,
        completion: @escaping (Bool) -> Void
    ) {
        if optsPtr == nil {
            var tempOpts: UnsafeMutablePointer<natsOptions>?
            let createStatus = natsOptions_Create(&tempOpts)
            guard createStatus == NATS_OK, let validOpts = tempOpts else {
                print("Failed to create natsOptions: \(statusString(createStatus))")
                completion(false)
                return
            }
            self.optsPtr = validOpts
        }

        guard let opts = self.optsPtr else {
            print("optsPtr is nil, cannot proceed.")
            completion(false)
            return
        }

        let nkeyStatus = seedContent.withCString { seedCString in
            natsOptions_SetNKeyFromSeed(opts, publicKey, seedCString)
        }
        if nkeyStatus != NATS_OK {
            print("Failed to set NKey from seed: \(statusString(nkeyStatus))")
            completion(false)
            return
        }

        let urlStatus = natsOptions_SetURL(opts, url)
        if urlStatus != NATS_OK {
            print("Failed to set URL: \(statusString(urlStatus))")
            completion(false)
            return
        }

        var tempConn: UnsafeMutablePointer<natsConnection>?
        let connStatus = natsConnection_Connect(&tempConn, opts)
        if connStatus == NATS_OK, let validConn = tempConn {
            connPtr = validConn
            isConnected = true
            completion(true)
        } else {
            isConnected = false
            var lastErrCode: Int32 = 0
    var errPtr: UnsafeMutablePointer<CChar>?
    nats_GetLastError(&lastErrCode, &errPtr)
    if let errPtr = errPtr {
        let errStr = String(cString: errPtr)
        print("Failed to connect: \(errStr) [error code: \(lastErrCode)]")
    } else {
        print("Failed to connect: Unknown error")
    }
            completion(false)
        }
    }

    /// Publish a message (String) to a subject, with a success callback.
    public func publish(
        subject: String,
        message: String,
        completion: @escaping (Bool) -> Void
    ) {
        guard isConnected, let conn = connPtr else {
            print("NATS not connected, skipping publish.")
            completion(false)
            return
        }

        let status = natsConnection_PublishString(conn, subject, message)
        if status == NATS_OK {
            completion(true)
        } else {
            print("Failed to publish: \(statusString(status))")
            completion(false)
        }
    }

    /// Close and destroy the connection + options
    public func close() {
        if let conn = connPtr {
            natsConnection_Close(conn)
            natsConnection_Destroy(conn)
            connPtr = nil
        }
        if let opts = optsPtr {
            natsOptions_Destroy(opts)
            optsPtr = nil
        }
        isConnected = false
    }

    /// Converts a natsStatus code to a human-readable string.
    private func statusString(_ status: natsStatus) -> String {
        guard let cStr = natsStatus_GetText(status) else {
            return "Unknown NATS error code \(status.rawValue)"
        }
        return String(cString: cStr)
    }
}

public struct NatsError: Error {
    public let message: String
    public init(_ message: String) { self.message = message }
}
