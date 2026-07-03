import Foundation

/// Minimal GRIB2 reader for FMI HARMONIE precipitation (Android `FmiHarmonieGribParser.kt`).
enum FmiHarmonieGribParser {
    private static let missing = 9999.0
    private static let harmonieBinaryScale = -20

    struct PrecipField: Equatable {
        let validity: Date
        /// Timestep length in minutes (30 or 60 for HARMONIE).
        let stepMinutes: Int
        /// [row][col] mm in timestep; row 0 = north.
        let amountMm: [[Double]]
        let bounds: RadarGeoBounds
    }

    static func parseAll(_ gribBytes: Data) -> [PrecipField] {
        var out: [PrecipField] = []
        var offset = 0
        let bytes = [UInt8](gribBytes)
        while offset + 16 <= bytes.count {
            guard bytes[offset] == UInt8(ascii: "G"),
                  bytes[offset + 1] == UInt8(ascii: "R"),
                  bytes[offset + 2] == UInt8(ascii: "I"),
                  bytes[offset + 3] == UInt8(ascii: "B") else {
                break
            }
            let totalLen = Int(readUInt64(bytes, offset + 8))
            guard totalLen > 0, offset + totalLen <= bytes.count else { break }
            if let field = parseMessage(bytes, base: offset, totalLen: totalLen) {
                out.append(field)
            }
            offset += totalLen
        }
        return out.sorted { $0.validity < $1.validity }
    }

    static func buildDownloadURL(
        west: Double,
        south: Double,
        east: Double,
        north: Double,
        start: Date,
        end: Date,
        originTime: Date
    ) -> URL {
        let origin = FmiInstantFormat.toParam(originTime)
        let startParam = FmiInstantFormat.toParam(start)
        let endParam = FmiInstantFormat.toParam(end)
        let urlString =
            "https://opendata.fmi.fi/download?producer=harmonie_scandinavia_surface" +
            "&param=PrecipitationAmount" +
            "&bbox=\(formatCoord(west)),\(formatCoord(south)),\(formatCoord(east)),\(formatCoord(north))" +
            "&origintime=\(origin)" +
            "&starttime=\(startParam)" +
            "&endtime=\(endParam)" +
            "&format=grib2&projection=EPSG:4326&levels=0&timestep=30"
        return URL(string: urlString)!
    }

    // MARK: - Private

    private static func parseMessage(
        _ bytes: [UInt8],
        base: Int,
        totalLen: Int
    ) -> PrecipField? {
        var secOff = base + 16
        let end = base + totalLen
        var section1: [UInt8]?
        var section3: [UInt8]?
        var section4: [UInt8]?
        var section5: [UInt8]?
        var section6: [UInt8]?
        var section7: [UInt8]?

        while secOff + 5 <= end {
            if bytes[secOff] == UInt8(ascii: "7"),
               bytes[secOff + 1] == UInt8(ascii: "7"),
               bytes[secOff + 2] == UInt8(ascii: "7"),
               bytes[secOff + 3] == UInt8(ascii: "7") {
                break
            }
            let secLen = readUInt32(bytes, secOff)
            guard secLen >= 5 else { break }
            let secNum = Int(bytes[secOff + 4])
            let bodyStart = secOff + 5
            let bodyEnd = secOff + secLen
            guard bodyEnd <= end else { break }
            let body = Array(bytes[bodyStart ..< bodyEnd])
            switch secNum {
            case 1: section1 = body
            case 3: section3 = body
            case 4: section4 = body
            case 5: section5 = body
            case 6: section6 = body
            case 7: section7 = body
            default: break
            }
            secOff += secLen
        }

        guard let s1 = section1, let s3 = section3, let s4 = section4,
              let s5 = section5, let s6 = section6, let s7 = section7,
              s3.count >= 36, s5.count >= 16 else {
            return nil
        }

        guard let validity = parseValidity(section1: s1, section4: s4) else { return nil }
        let stepMinutes = readUInt16(s4, 15)
        guard stepMinutes == 30 || stepMinutes == 60 else { return nil }

        let ni = readUInt16(s3, 27)
        let nj = readUInt16(s3, 31)
        guard ni > 0, nj > 0, ni <= 2000, nj <= 2000 else { return nil }

        let nPacked = readUInt16(s5, 2)
        let reference = readFloat32(s5, 6)
        let bitsPerValue = Int(s5[14])
        guard bitsPerValue > 0, bitsPerValue <= 32 else { return nil }

        let scale = pow(2.0, Double(harmonieBinaryScale))
        let packed = unpackBits(s7, count: nPacked, bitsPerValue: bitsPerValue)
        let values = packed.map { i -> Double in
            let raw = reference + Double(i) * scale
            if raw >= missing - 1 || raw.isNaN || raw < 0 { return 0 }
            return raw
        }

        var grid = [Double](repeating: .nan, count: ni * nj)
        let bitmap = Array(s6.dropFirst(2))
        var valueIndex = 0
        var bitIndex = 0
        for point in 0 ..< ni * nj {
            if readBitmapBit(bitmap, index: bitIndex) {
                if valueIndex < values.count {
                    grid[point] = values[valueIndex]
                    valueIndex += 1
                }
            }
            bitIndex += 1
        }

        let rows = (0 ..< nj).map { row in
            (0 ..< ni).map { col in
                let v = grid[row * ni + col]
                return v.isNaN ? 0.0 : v
            }
        }

        let maxMm = rows.flatMap { $0 }.max() ?? 0
        guard maxMm > 0.001 else { return nil }

        return PrecipField(
            validity: validity,
            stepMinutes: stepMinutes,
            amountMm: rows,
            bounds: RadarGeoBounds(northLat: 0, westLon: 0, southLat: 0, eastLon: 0)
        )
    }

    private static func parseValidity(section1: [UInt8], section4: [UInt8]) -> Date? {
        guard section1.count >= 13, section4.count >= 17 else { return nil }
        let year = readUInt16(section1, 7)
        let month = Int(section1[9])
        let day = Int(section1[10])
        let hour = Int(section1[11])
        let minute = Int(section1[12])
        let stepMinutes = readUInt16(section4, 15)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let base = calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        ) else { return nil }
        return calendar.date(byAdding: .minute, value: stepMinutes, to: base)
    }

    private static func unpackBits(_ data: [UInt8], count: Int, bitsPerValue: Int) -> [Int] {
        var out = [Int]()
        out.reserveCapacity(count)
        var bitPos = 0
        for _ in 0 ..< count {
            var v = 0
            for _ in 0 ..< bitsPerValue {
                let byteIndex = bitPos / 8
                let bitInByte = 7 - (bitPos % 8)
                let bit: Int
                if byteIndex < data.count {
                    bit = (Int(data[byteIndex]) >> bitInByte) & 1
                } else {
                    bit = 0
                }
                v = (v << 1) | bit
                bitPos += 1
            }
            out.append(v)
        }
        return out
    }

    private static func readBitmapBit(_ bitmap: [UInt8], index: Int) -> Bool {
        let byteIndex = index / 8
        let bitInByte = 7 - (index % 8)
        guard byteIndex < bitmap.count else { return false }
        return ((Int(bitmap[byteIndex]) >> bitInByte) & 1) == 1
    }

    private static func readUInt16(_ bytes: [UInt8], _ offset: Int) -> Int {
        guard offset + 2 <= bytes.count else { return 0 }
        return (Int(bytes[offset]) << 8) | Int(bytes[offset + 1])
    }

    private static func readUInt32(_ bytes: [UInt8], _ offset: Int) -> Int {
        guard offset + 4 <= bytes.count else { return 0 }
        var value = 0
        for i in 0 ..< 4 {
            value = (value << 8) | Int(bytes[offset + i])
        }
        return value
    }

    private static func readUInt64(_ bytes: [UInt8], _ offset: Int) -> UInt64 {
        guard offset + 8 <= bytes.count else { return 0 }
        var value: UInt64 = 0
        for i in 0 ..< 8 {
            value = (value << 8) | UInt64(bytes[offset + i])
        }
        return value
    }

    private static func readFloat32(_ bytes: [UInt8], _ offset: Int) -> Double {
        guard offset + 4 <= bytes.count else { return 0 }
        let bits =
            (UInt32(bytes[offset]) << 24) |
            (UInt32(bytes[offset + 1]) << 16) |
            (UInt32(bytes[offset + 2]) << 8) |
            UInt32(bytes[offset + 3])
        return Double(Float(bitPattern: bits))
    }

    private static func formatCoord(_ value: Double) -> String {
        String(format: "%.4f", value)
    }
}
