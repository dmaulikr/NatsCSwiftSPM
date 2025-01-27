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
    private var subscriptionPtr: UnsafeMutablePointer<natsSubscription>?
    private var subscriptionHandler: ((String) -> Void)?
    public private(set) var isConnected = false

    public init() { }

    deinit {
        close()
    }

    // Connect to NATS with public key + seed, specifying a URL. Calls completion with true/false.
    // If connection fails, we also fetch a detailed error string via nats_GetLastError.
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
            optsPtr = validOpts
        }

        guard let opts = optsPtr else {
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
            print("Connection failed: \(statusString(connStatus))")
            fetchLastErrorDetails()
            completion(false)
        }
    }

    // Publish a message (String) to a subject, with a success callback.
    // If not connected, we call completion(false) immediately.
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

    /// Convert a natsStatus code to a human-readable string
    private func statusString(_ status: natsStatus) -> String {
        guard let cStr = natsStatus_GetText(status) else {
            return "Unknown NATS error code \(status.rawValue)"
        }
        return String(cString: cStr)
    }

    /// Fetch and print the most recent detailed error info from the NATS library
    private func fetchLastErrorDetails() {
        var lastCode: natsStatus = NATS_OK
        let errPtr = nats_GetLastError(&lastCode)
        if let errPtr = errPtr {
            let errStr = String(cString: errPtr)
            print("nats_GetLastError -> code: \(lastCode), message: \"\(errStr)\"")
        } else {
            print("nats_GetLastError returned no error message. code=\(lastCode)")
        }
    }
    
    /// Fetch messages from event
    private static let cMsgCallback: natsMsgHandler = { (ncPtr, subPtr, msgPtr, userData) in
        guard let userData = userData else { return }
        let mySelf = Unmanaged<NatsSwiftWrapper>.fromOpaque(userData).takeUnretainedValue()
        guard let msgPtr = msgPtr else { return }

        let subjectCStr = natsMsg_GetSubject(msgPtr)
        let subject = subjectCStr.map { String(cString: $0) } ?? "(unknown)"

        let dataPtr = natsMsg_GetData(msgPtr) // UnsafePointer<CChar>
        let dataLen = natsMsg_GetDataLength(msgPtr) // Int32
        var messageString: String = ""

        if let dataPtr = dataPtr, dataLen > 0 {
            // Convert dataLen to Int
            let length = Int(dataLen)
            // Rebind Int8 pointer to UInt8
            dataPtr.withMemoryRebound(to: UInt8.self, capacity: length) { bytesPtr in
                let buffer = UnsafeBufferPointer(start: bytesPtr, count: length)
                messageString = String(decoding: buffer, as: UTF8.self)
            }
        } else {
            messageString = ""
        }

        if let handler = mySelf.subscriptionHandler {
            handler("Subject: \(subject)\nMessage: \(messageString)")
        }
    }
    
    public func subscribe(
        to subject: String,
        handler: @escaping (String) -> Void,
        completion: @escaping (Bool) -> Void
    ) {
        guard isConnected, let conn = connPtr else {
            print("Not connected, cannot subscribe.")
            completion(false)
            return
        }

        // If there's already a subscription, unsubscribe first (optional if you only allow one)
        if let existingSub = subscriptionPtr {
            natsSubscription_Unsubscribe(existingSub)
            subscriptionPtr = nil
        }

        // Store the Swift closure
        subscriptionHandler = handler

        // We'll pass 'self' via userData so we can retrieve in cMsgCallback
        let userData = Unmanaged.passUnretained(self).toOpaque()

        var subPtr: UnsafeMutablePointer<natsSubscription>?
        let subStatus = natsConnection_Subscribe(
            &subPtr,
            conn,
            subject,
            Self.cMsgCallback,
            userData
        )
        if subStatus == NATS_OK, let validSub = subPtr {
            subscriptionPtr = validSub
            print("Subscribed to \(subject) successfully.")
            completion(true)
        } else {
            print("Failed to subscribe to \(subject): \(statusString(subStatus))")
            fetchLastErrorDetails()
            completion(false)
        }
    }
    
}
