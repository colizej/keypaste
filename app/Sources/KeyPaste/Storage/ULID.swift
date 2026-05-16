import Foundation
import Security

// 26-char Crockford base32 ULID:
//   10 chars  — 48-bit ms-since-epoch timestamp (sortable prefix)
//   16 chars  — 80-bit random tail (SecRandomCopyBytes)
// No external dependency. Sufficient for trigger IDs in a single-user app.

enum ULID {
    private static let alphabet: [Character] =
        Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    static func generate(now: Date = Date()) -> String {
        let ms = UInt64(now.timeIntervalSince1970 * 1000)
        var random = [UInt8](repeating: 0, count: 10)
        let status = SecRandomCopyBytes(kSecRandomDefault, random.count, &random)
        precondition(status == errSecSuccess, "ULID random source failed")

        var chars: [Character] = []
        chars.reserveCapacity(26)

        for i in 0..<10 {
            let shift = (9 - i) * 5
            let idx = Int((ms >> UInt64(shift)) & 0x1f)
            chars.append(alphabet[idx])
        }

        var bits: UInt64 = 0
        var bitsCount = 0
        var byteIdx = 0
        for _ in 0..<16 {
            while bitsCount < 5 {
                bits = (bits << 8) | UInt64(random[byteIdx])
                bitsCount += 8
                byteIdx += 1
            }
            bitsCount -= 5
            let idx = Int((bits >> UInt64(bitsCount)) & 0x1f)
            chars.append(alphabet[idx])
            bits &= (UInt64(1) << UInt64(bitsCount)) &- 1
        }

        return String(chars)
    }
}
