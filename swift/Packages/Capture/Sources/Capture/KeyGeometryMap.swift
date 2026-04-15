import Core
import Foundation

struct KeyGeometry {
    let row: Double
    let column: Double
    let hand: KeyHand
}

enum KeyGeometryMap {
    static func geometry(for keyCode: Int64) -> KeyGeometry? {
        geometries[keyCode]
    }

    static func keyCode(for character: Character) -> Int64? {
        keyCodesByCharacter[character]
    }

    static func distanceBucket(from firstKeyCode: Int64, to secondKeyCode: Int64) -> DistanceBucket {
        guard let first = geometry(for: firstKeyCode), let second = geometry(for: secondKeyCode) else {
            return .unknown
        }

        let distance = abs(first.row - second.row) + abs(first.column - second.column)

        switch distance {
        case ..<0.5:
            return .sameKey
        case ..<2.0:
            return .near
        case ..<4.5:
            return .medium
        default:
            return .far
        }
    }

    static func handPattern(from firstKeyCode: Int64, to secondKeyCode: Int64) -> HandTransitionPattern {
        guard let firstHand = geometry(for: firstKeyCode)?.hand,
              let secondHand = geometry(for: secondKeyCode)?.hand else {
            return .unknown
        }

        if firstHand == .neutral || secondHand == .neutral {
            return .involvesNeutral
        }

        if firstHand == .unknown || secondHand == .unknown {
            return .unknown
        }

        return firstHand == secondHand ? .sameHand : .crossHand
    }

    private static let geometries: [Int64: KeyGeometry] = [
        50: .init(row: 0.0, column: 0.0, hand: .left),  // `
        18: .init(row: 0.0, column: 1.0, hand: .left),  // 1
        19: .init(row: 0.0, column: 2.0, hand: .left),  // 2
        20: .init(row: 0.0, column: 3.0, hand: .left),  // 3
        21: .init(row: 0.0, column: 4.0, hand: .left),  // 4
        23: .init(row: 0.0, column: 5.0, hand: .left),  // 5
        22: .init(row: 0.0, column: 6.0, hand: .right), // 6
        26: .init(row: 0.0, column: 7.0, hand: .right), // 7
        28: .init(row: 0.0, column: 8.0, hand: .right), // 8
        25: .init(row: 0.0, column: 9.0, hand: .right), // 9
        29: .init(row: 0.0, column: 10.0, hand: .right), // 0
        27: .init(row: 0.0, column: 11.0, hand: .right), // -
        24: .init(row: 0.0, column: 12.0, hand: .right), // =
        48: .init(row: 1.0, column: 0.5, hand: .left),  // tab
        12: .init(row: 1.0, column: 1.5, hand: .left),  // q
        13: .init(row: 1.0, column: 2.5, hand: .left),  // w
        14: .init(row: 1.0, column: 3.5, hand: .left),  // e
        15: .init(row: 1.0, column: 4.5, hand: .left),  // r
        17: .init(row: 1.0, column: 5.5, hand: .left),  // t
        16: .init(row: 1.0, column: 6.5, hand: .right), // y
        32: .init(row: 1.0, column: 7.5, hand: .right), // u
        34: .init(row: 1.0, column: 8.5, hand: .right), // i
        31: .init(row: 1.0, column: 9.5, hand: .right), // o
        35: .init(row: 1.0, column: 10.5, hand: .right), // p
        33: .init(row: 1.0, column: 11.5, hand: .right), // [
        30: .init(row: 1.0, column: 12.5, hand: .right), // ]
        42: .init(row: 1.0, column: 13.5, hand: .right), // \
        0: .init(row: 2.0, column: 1.0, hand: .left),   // a
        1: .init(row: 2.0, column: 2.0, hand: .left),   // s
        2: .init(row: 2.0, column: 3.0, hand: .left),   // d
        3: .init(row: 2.0, column: 4.0, hand: .left),   // f
        5: .init(row: 2.0, column: 5.0, hand: .left),   // g
        4: .init(row: 2.0, column: 6.0, hand: .right),  // h
        38: .init(row: 2.0, column: 7.0, hand: .right), // j
        40: .init(row: 2.0, column: 8.0, hand: .right), // k
        37: .init(row: 2.0, column: 9.0, hand: .right), // l
        41: .init(row: 2.0, column: 10.0, hand: .right), // ;
        39: .init(row: 2.0, column: 11.0, hand: .right), // '
        6: .init(row: 3.0, column: 1.5, hand: .left),   // z
        7: .init(row: 3.0, column: 2.5, hand: .left),   // x
        8: .init(row: 3.0, column: 3.5, hand: .left),   // c
        9: .init(row: 3.0, column: 4.5, hand: .left),   // v
        11: .init(row: 3.0, column: 5.5, hand: .left),  // b
        45: .init(row: 3.0, column: 6.5, hand: .right), // n
        46: .init(row: 3.0, column: 7.5, hand: .right), // m
        43: .init(row: 3.0, column: 8.5, hand: .right), // ,
        47: .init(row: 3.0, column: 9.5, hand: .right), // .
        44: .init(row: 3.0, column: 10.5, hand: .right), // /
        49: .init(row: 4.0, column: 6.0, hand: .neutral), // space
        36: .init(row: 2.0, column: 12.5, hand: .neutral), // return
        51: .init(row: 0.0, column: 13.5, hand: .neutral)  // delete/backspace
    ]

    private static let keyCodesByCharacter: [Character: Int64] = [
        "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4, "i": 34,
        "j": 38, "k": 40, "l": 37, "m": 46, "n": 45, "o": 31, "p": 35, "q": 12,
        "r": 15, "s": 1, "t": 17, "u": 32, "v": 9, "w": 13, "x": 7, "y": 16,
        "z": 6, " ": 49
    ]
}
