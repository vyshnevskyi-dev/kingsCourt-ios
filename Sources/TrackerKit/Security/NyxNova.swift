














import Foundation

enum NyxNova {

    
    
    
    
    
    
    
    
    static func reveal(_ blob: [UInt8], key: [UInt8]) -> String? {
        guard !blob.isEmpty, !key.isEmpty else { return nil }
        var out = [UInt8]()
        out.reserveCapacity(blob.count)
        for i in 0..<blob.count {
            out.append(blob[i] ^ key[i % key.count])
        }
        return String(decoding: out, as: UTF8.self)
    }
}
