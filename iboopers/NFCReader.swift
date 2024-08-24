import Foundation
import CoreNFC

class NFCReaderWriter: NSObject, NFCNDEFReaderSessionDelegate {
    var session: NFCNDEFReaderSession?
    var writeMessage: NFCNDEFMessage?
    var readCompletion: ((String) -> Void)?

    func beginScanning(completion: @escaping (String) -> Void) {
        self.readCompletion = completion
        guard NFCNDEFReaderSession.readingAvailable else {
            print("NFC is not available on this device")
            return
        }
        
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold to boop."
        session?.begin()
    }
    
    func writeToTag(message: String) {
        guard NFCNDEFReaderSession.readingAvailable else {
            print("NFC is not available on this device")
            return
        }
        
        let payload = NFCNDEFPayload.wellKnownTypeTextPayload(
            string: message,
            locale: Locale(identifier: "en")
        )
        
        self.writeMessage = NFCNDEFMessage(records: [payload].compactMap { $0 })
        
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near an NFC tag to write."
        session?.begin()
    }
    
    func writeURLToTag(urlString: String) {
            guard let url = URL(string: urlString), NFCNDEFReaderSession.readingAvailable else {
                print("Invalid URL or NFC is not available on this device")
                return
            }
            
            let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: url)!
            self.writeMessage = NFCNDEFMessage(records: [payload])
            
            session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
            session?.alertMessage = "Hold your iPhone near an NFC tag to write the URL."
            session?.begin()
        }
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        print("The session was invalidated: \(error.localizedDescription)")
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        for message in messages {
            print(message)
            for record in message.records {
                if let string = String(data: record.payload, encoding: .utf8) {
                    print("NFC tag contains: \(string)")
                    DispatchQueue.main.async {
                        self.readCompletion?(string)
                    }
                    session.invalidate()
                    return
                }
            }
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag found.")
            return
        }
        
        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "Connection failed: \(error.localizedDescription)")
                return
            }
            
            tag.queryNDEFStatus { status, capacity, error in
                guard error == nil else {
                    session.invalidate(errorMessage: "Failed to query tag.")
                    return
                }
                
                switch status {
                case .notSupported:
                    session.invalidate(errorMessage: "Tag is not NDEF compliant.")
                case .readOnly:
                    session.invalidate(errorMessage: "Tag is read-only.")
                case .readWrite:
                    if let message = self.writeMessage {
                        tag.writeNDEF(message) { error in
                            if let error = error {
                                session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
                            } else {
                                session.alertMessage = "Write successful!"
                                session.invalidate()
                            }
                        }
                    } else {
                        self.readTag(tag, session: session)
                    }
                @unknown default:
                    session.invalidate(errorMessage: "Unknown tag status.")
                }
            }
        }
    }
    
    private func readTag(_ tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        tag.readNDEF { message, error in
            if let error = error {
                session.invalidate(errorMessage: "Read error: \(error.localizedDescription)")
            } else if let message = message, let record = message.records.first,
                      let string = String(data: record.payload, encoding: .utf8) {
                print("Read from tag: \(string)")
                let cleanString = string.replacingOccurrences(of: "\n", with: "").trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\0", with: "")
                DispatchQueue.main.async {
                    self.readCompletion?(cleanString)
                }
                session.alertMessage = "Read successful!"
                session.invalidate()
            } else {
                session.invalidate(errorMessage: "No data read from tag.")
            }
        }
    }
}
