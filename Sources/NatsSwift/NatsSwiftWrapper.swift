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

    // We store whether we’re successfully connected
    public private(set) var isConnected = false

    // MARK: - Lifecycle

    public init() {
        // We'll do "lazy" options creation in connectWithNKey
        // or if you prefer, you can create it here.
    }

    deinit {
        close()
    }

    // MARK: - Connect with NKey (Callback Style)

    /// Connect to NATS with public key + seed, specifying a URL. Calls completion with true/false.
    public func connectWithNKey(
        publicKey: String,
        seedContent: String,
        url: String,
        completion: @escaping (Bool) -> Void
    ) {
        // 1) Create natsOptions if not yet created
        if optsPtr == nil {
            var tempOpts: UnsafeMutablePointer<natsOptions>?
            let createStatus = natsOptions_Create(&tempOpts)
            guard createStatus == NATS_OK, let validOpts = tempOpts else {
                completion(false)
                return
            }
            self.optsPtr = validOpts
        }

        guard let opts = self.optsPtr else {
            completion(false)
            return
        }

        // 2) Set NKey from seed
        let nkeyStatus = seedContent.withCString { seedCString in
            natsOptions_SetNKeyFromSeed(opts, publicKey, seedCString)
        }
        if nkeyStatus != NATS_OK {
            completion(false)
            return
        }

        // 3) Set URL
        let urlStatus = natsOptions_SetURL(opts, url)
        if urlStatus != NATS_OK {
            completion(false)
            return
        }

        // 4) Connect
        var tempConn: UnsafeMutablePointer<natsConnection>?
        let connStatus = natsConnection_Connect(&tempConn, opts)
        if connStatus == NATS_OK, let validConn = tempConn {
            self.connPtr = validConn
            self.isConnected = true
            completion(true)
        } else {
            self.isConnected = false
            completion(false)
        }
    }

    // MARK: - Publish with Callback

    /// Publish a message (String) to a subject, with a success callback.
    /// If not connected, we immediately invoke completion(false).
    public func publish(subject: String, message: String, completion: @escaping (Bool) -> Void) {
        // 1) Check if connected
        guard isConnected, let conn = connPtr else {
            print("NATS not connected, skipping publish.")
            completion(false)
            return
        }
        // 2) Actually publish
        let status = natsConnection_PublishString(conn, subject, message)
        completion(status == NATS_OK)
    }

    // MARK: - Close

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

    // MARK: - Helpers (Error Handling)

    /// Simple wrapper to create an Error from natsStatus
    private func makeNatsError(_ status: natsStatus, _ context: String) -> Error {
        let errCStr = natsStatus_GetText(status)
        let errMsg = errCStr != nil ? String(cString: errCStr!) : "Unknown"
        return NatsError("\(context) [\(status.rawValue)]: \(errMsg)")
    }
}

// A simple Swift Error type for convenience
public struct NatsError: Error {
    public let message: String
    public init(_ message: String) { self.message = message }
}
