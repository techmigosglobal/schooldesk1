import Foundation

@_cdecl("net_nfet_printing_set_document")
public func net_nfet_printing_set_document(
    _ job: UInt32,
    _ doc: UnsafePointer<UInt8>?,
    _ size: UInt64
) {
    guard let doc else {
        return
    }
    PrintingPlugin.setDocument(job: job, doc: doc, size: size)
}

@_cdecl("net_nfet_printing_set_error")
public func net_nfet_printing_set_error(
    _ job: UInt32,
    _ message: UnsafePointer<CChar>?
) {
    guard let message else {
        return
    }
    PrintingPlugin.setError(job: job, message: message)
}
