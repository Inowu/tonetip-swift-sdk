import Foundation
import Accelerate

struct ObfCrc {
    static let t: [UInt16] = [
        0x0000, 0x1189, 0x2312, 0x329b, 0x4624, 0x57ad, 0x6536, 0x74bf,
        0x8c48, 0x9dc1, 0xaf5a, 0xbed3, 0xca6c, 0xdbe5, 0xe97e, 0xf8f7,
        0x1081, 0x0108, 0x3393, 0x221a, 0x56a5, 0x472c, 0x75b7, 0x643e,
        0x9cc9, 0x8d40, 0xbfdb, 0xae52, 0xdaed, 0xcb64, 0xf9ff, 0xe876,
        0x2102, 0x308b, 0x0210, 0x1399, 0x6726, 0x76af, 0x4434, 0x55bd,
        0xad4a, 0xbcc3, 0x8e58, 0x9fd1, 0xeb6e, 0xfae7, 0xc87c, 0xd9f5,
        0x3183, 0x200a, 0x1291, 0x0318, 0x77a7, 0x662e, 0x54b5, 0x453c,
        0xbdcb, 0xac42, 0x9ed9, 0x8f50, 0xfbef, 0xea66, 0xd8fd, 0xc974,
        0x4204, 0x538d, 0x6116, 0x709f, 0x0420, 0x15a9, 0x2732, 0x36bb,
        0xce4c, 0xdfc5, 0xed5e, 0xfcd7, 0x8868, 0x99e1, 0xab7a, 0xbaf3,
        0x5285, 0x430c, 0x7197, 0x601e, 0x14a1, 0x0528, 0x37b3, 0x263a,
        0xdecd, 0xcf44, 0xfddf, 0xec56, 0x98e9, 0x8960, 0xbbfb, 0xaa72,
        0x6306, 0x728f, 0x4014, 0x519d, 0x2522, 0x34ab, 0x0630, 0x17b9,
        0xef4e, 0xfec7, 0xcc5c, 0xddd5, 0xa96a, 0xb8e3, 0x8a78, 0x9bf1,
        0x7387, 0x620e, 0x5095, 0x411c, 0x35a3, 0x242a, 0x16b1, 0x0738,
        0xffcf, 0xee46, 0xdcdd, 0xcd54, 0xb9eb, 0xa862, 0x9af9, 0x8b70,
        0x8408, 0x9581, 0xa71a, 0xb693, 0xc22c, 0xd3a5, 0xe13e, 0xf0b7,
        0x0840, 0x19c9, 0x2b52, 0x3adb, 0x4e64, 0x5fed, 0x6d76, 0x7cff,
        0x9489, 0x8500, 0xb79b, 0xa612, 0xd2ad, 0xc324, 0xf1bf, 0xe036,
        0x18c1, 0x0948, 0x3bd3, 0x2a5a, 0x5ee5, 0x4f6c, 0x7df7, 0x6c7e,
        0xa50a, 0xb483, 0x8618, 0x9791, 0xe32e, 0xf2a7, 0xc03c, 0xd1b5,
        0x2942, 0x38cb, 0x0a50, 0x1bd9, 0x6f66, 0x7eef, 0x4c74, 0x5dfd,
        0xb58b, 0xa402, 0x9699, 0x8710, 0xf3af, 0xe226, 0xd0bd, 0xc134,
        0x39c3, 0x284a, 0x1ad1, 0x0b58, 0x7fe7, 0x6e6e, 0x5cf5, 0x4d7c,
        0xc60c, 0xd785, 0xe51e, 0xf497, 0x8028, 0x91a1, 0xa33a, 0xb2b3,
        0x4a44, 0x5bcd, 0x6956, 0x78df, 0x0c60, 0x1de9, 0x2f72, 0x3efb,
        0xd68d, 0xc704, 0xf59f, 0xe416, 0x90a9, 0x8120, 0xb3bb, 0xa232,
        0x5ac5, 0x4b4c, 0x79d7, 0x685e, 0x1ce1, 0x0d68, 0x3ff3, 0x2e7a,
        0xe70e, 0xf687, 0xc41c, 0xd595, 0xa12a, 0xb0a3, 0x8238, 0x93b1,
        0x6b46, 0x7acf, 0x4854, 0x59dd, 0x2d62, 0x3ceb, 0x0e70, 0x1ff9,
        0xf78f, 0xe606, 0xd49d, 0xc514, 0xb1ab, 0xa022, 0x92b9, 0x8330,
        0x7bc7, 0x6a4e, 0x58d5, 0x495c, 0x3de3, 0x2c6a, 0x1ef1, 0x0f78
    ]

    static func f(_ s: UInt8, _ c: UInt16) -> UInt16 {
        let tmp = (c ^ UInt16(s)) & 0xffff
        let val = t[Int(tmp & 0xff)]
        return ((c >> 8) ^ val) & 0xffff
    }
}


class ObfTRS {
    static let A = 255
    static let B = 8
    static let C = 4
    static let D = 247

    static let N = A
    static let M = B
    static let T = C
    static let K = D

    private var p: [Int] = [1, 0, 0, 0, 1, 1, 1, 0, 1]
    private var a: [Int] = Array(repeating: 0, count: A + 1)
    private var i: [Int] = Array(repeating: 0, count: A + 1)
    private var g: [Int] = Array(repeating: 0, count: A - D + 1)
    private var r: [Int] = Array(repeating: 0, count: A)

    init() {
        genGf()
        genP()
    }

    private func genGf() {
        var mask = 1
        a[Self.B] = 0
        for x in 0..<Self.B {
            a[x] = mask
            i[a[x]] = x
            if p[x] != 0 {
                a[Self.B] ^= mask
            }
            mask <<= 1
        }
        i[a[Self.B]] = Self.B
        mask >>= 1
        for x in (Self.B + 1)..<Self.A {
            if (a[x - 1] & mask) != 0 {
                a[x] = a[Self.B] ^ ((a[x - 1] ^ mask) << 1)
            } else {
                a[x] = a[x - 1] << 1
            }
            i[a[x]] = x
        }
        i[0] = -1
    }

    private func genP() {
        g[0] = 2
        g[1] = 1
        for x in 2...Self.A - Self.K {
            g[x] = 1
            for y in stride(from: x - 1, through: 1, by: -1) {
                if g[y] != 0 {
                    let idx = (i[g[y]] + x) % Self.A
                    g[y] = g[y - 1] ^ a[idx]
                } else {
                    g[y] = g[y - 1]
                }
            }
            let idx2 = (i[g[0]] + x) % Self.A
            g[0] = a[idx2]
        }
        for x in 0...Self.A - Self.K {
            g[x] = i[g[x]]
        }
    }

    func z(_ inp: [UInt8], _ dec: inout [UInt8]) -> Int {
        for j in 0..<Self.A {
            r[j] = i[Int(inp[j] & 0xff)]
        }
        var synErr = false
        var s = Array(repeating: 0, count: Self.A - Self.K + 1)
        for x in 1...Self.A - Self.K {
            var sum = 0
            for y in 0..<Self.A {
                let rj = r[y]
                if rj != -1 {
                    let idx = (rj + x * y) % Self.A
                    sum ^= a[idx]
                }
            }
            if sum != 0 { synErr = true }
            s[x] = i[sum]
        }
        if !synErr {
            for x in 0..<Self.A {
                r[x] = r[x] != -1 ? a[r[x]] : 0
                dec[x] = UInt8(r[x] & 0xff)
            }
            return 0
        }
        let dCount = Self.A - Self.K + 2
        var l = Array(repeating: 0, count: dCount)
        l[0] = 0
        l[1] = 0
        var u = 0
        repeat {
            u += 1
            if l[u + 1] < 1 {
                return -1
            }
            for _ in 1...l[u + 1] {
            }
        } while u < (Self.A - Self.K) && l[u + 1] <= Self.C
        return 0
    }
}

class ObfFft {
    static func fftF(inp: [Float], outR: inout [Float], outI: inout [Float]) -> Bool {
        let N = inp.count
        guard let l = validLog2(N) else { return false }
        outR.withUnsafeMutableBufferPointer { rPtr in
            outI.withUnsafeMutableBufferPointer { iPtr in
                var sp = DSPSplitComplex(realp: rPtr.baseAddress!, imagp: iPtr.baseAddress!)
                for x in 0..<N {
                    sp.realp[x] = inp[x]
                    sp.imagp[x] = 0
                }
                guard let set = vDSP_create_fftsetup(vDSP_Length(l), FFTRadix(kFFTRadix2)) else { return }
                vDSP_fft_zrip(set, &sp, 1, vDSP_Length(l), FFTDirection(FFT_FORWARD))
                vDSP_destroy_fftsetup(set)
            }
        }
        return true
    }

    private static func validLog2(_ n: Int) -> Int? {
        var tmp = n
        var count = 0
        while tmp > 1 {
            if tmp % 2 != 0 { return nil }
            tmp /= 2
            count += 1
        }
        return count
    }
}

// MARK: - DecoderMFSK (Interfaz pública inalterada)

public class DecoderMFSK {
    static let F: Int = 8192
    static let G: Int = 9
    static let H: Int = 512
    static let I: Int = H - 1
    static let J: Int = ((ObfTRS.C * 2 + 6 + 2) * 2)
    static let K: Float = 48000

    public var reverse: Bool = false

    private var b: Int
    private var c: Int
    private var d: Float

    private var e: Int
    private var f_: Int

    private var g_: Int = 0
    private var h_: Int = 0
    private var i_: Int = 0
    private var j_: Int = 0

    private var k_: [Float]
    private var l_: [Float]
    private var m_: [Float]
    private var n_: [Float]
    private var o_: [Float]
    private var p_: [Float]
    private var q_: [Float]

    private var r_: [UInt8]
    private var s_: [UInt8]
    private var t_: [UInt8]
    private var u_: [UInt8]

    private let v: ObfTRS = ObfTRS()

    private var w: Int
    private var x: Int
    private var y: Int

    init(speed: Int, freq: Float) {
        self.b = speed
        self.c = 2
        self.d = freq

        self.e = DecoderMFSK.F / speed
        self.f_ = Int(floor((2000.0 * Float(self.e) + Float(DecoderMFSK.G)) / Float(2 * DecoderMFSK.G)))
        self.k_ = Array(repeating: 0, count: DecoderMFSK.F)
        self.l_ = Array(repeating: 0, count: DecoderMFSK.F)
        self.m_ = Array(repeating: 0, count: DecoderMFSK.F)
        self.n_ = Array(repeating: 0, count: DecoderMFSK.F)
        self.o_ = Array(repeating: 0, count: DecoderMFSK.F / 2)
        self.p_ = Array(repeating: 0, count: DecoderMFSK.H)
        self.q_ = Array(repeating: 0, count: DecoderMFSK.H)

        self.r_ = Array(repeating: 0, count: ObfTRS.A)
        self.s_ = Array(repeating: 0, count: ObfTRS.A)
        self.t_ = Array(repeating: 0, count: ObfTRS.A)
        self.u_ = Array(repeating: 0, count: 6)

        let dfft = DecoderMFSK.K / Float(self.e)
        let df = dfft * Float(self.c)
        let dFreqL = freq - 7.5 * df
        self.w = Int(floor(floor(dFreqL / dfft + 0.5) + 0.1))
        self.x = max(2, self.w - self.c)
        let halfFft = self.e / 2 - 4
        self.y = min(halfFft, self.w + 16 * self.c)
    }

    public func processSamples(_ arr: [Int16]) -> String? {
        var z: String? = nil
        for s in arr {
            if let ret = self.procS(s) {
                let hex = ret.map { String(format: "%02x", $0) }.joined()
                z = hex
            }
        }
        return z
    }

    private func procS(_ s: Int16) -> [UInt8]? {
        let a0 = Float(s)
        k_[h_] = a0
        h_ = (h_ + 1) & (DecoderMFSK.F - 1)
        g_ += 1000
        var ret: [UInt8]? = nil
        if g_ >= f_ {
            g_ -= f_
            var idx = (h_ - e) & (DecoderMFSK.F - 1)
            for j in 0..<e {
                l_[j] = k_[idx]
                idx = (idx + 1) & (DecoderMFSK.F - 1)
            }
            _ = ObfFft.fftF(inp: l_, outR: &m_, outI: &n_)
            ret = bit9()
        }
        return ret
    }

    private func bit9() -> [UInt8]? {
        let fl2 = 2.0 * Float(e) * Float(e)
        for i in (x - 1)...(y + 1) {
            let v0 = m_[i] / fl2
            var val = v0 * v0
            let v1 = n_[i] / fl2
            val += v1 * v1
            val = (val > 1e-12) ? sqrt(val) : 0
            o_[i] = val
        }
        let (val0, diff) = decPeak()
        j_ = (j_ + 1) & DecoderMFSK.I
        p_[j_] = diff
        q_[j_] = Float(val0)
        if i_ > 0 {
            i_ -= 1
            return nil
        }
        let st = (j_ - DecoderMFSK.G * DecoderMFSK.J) & DecoderMFSK.I
        return tstPrint(st)
    }

    private func decPeak() -> (Int, Float) {
        var a = 0
        var b0: Float = -1
        var c0: Float = 9999999
        for i in x...y {
            let v = o_[i]
            if v > b0 {
                b0 = v
                a = i
            }
            if v < c0 {
                c0 = v
            }
        }
        let d0 = b0 - c0
        var df: Float = 0
        if b0 > 1e-5 {
            let vL = o_[a - 1]
            let vR = o_[a + 1]
            if vR > vL {
                if (b0 - vL) > 1e-5 {
                    df = 0.5 * (vR - vL) / (b0 - vL)
                } else if (b0 - vR) > 1e-5 {
                    df = 0.5 * (vR - vL) / (b0 - vR)
                }
            }
        }
        let vali = Float(a) + df
        let shifted = floor((vali - Float(w)) / Float(c) + 0.5) * Float(c)
        let valf = Float(w) + shifted
        return (Int(valf), d0)
    }

    private func tstData(_ st: Int, _ len: Int) -> Float {
        var pos = st & DecoderMFSK.I
        var s0: Float = 0
        for _ in 0..<len {
            s0 += p_[pos]
            pos = (pos + DecoderMFSK.G) & DecoderMFSK.I
        }
        return s0
    }

    private func getOff(_ idx: Int, _ len: Int) -> Int {
        var maxVal: Float = 0
        var maxIdx = 0
        for i in -4..<6 {
            let id = (idx + i) & DecoderMFSK.I
            let qv = tstData(id, len)
            if qv > maxVal {
                maxVal = qv
                maxIdx = i
            }
        }
        return maxIdx
    }

    private func getMax(_ idx: Int, _ len: Int) -> (Float, Int) {
        var maxVal: Float = 0
        var off = 0
        if len > 0 {
            let st = idx & DecoderMFSK.I
            for i in -2...2 {
                let id = (st + i) & DecoderMFSK.I
                let qv = tstData(id, len)
                if qv > maxVal {
                    maxVal = qv
                    off = i
                }
            }
        } else if len < 0 {
            let st = (idx + DecoderMFSK.G * (len + 1)) & DecoderMFSK.I
            for i in -2...2 {
                let id = (st + i) & DecoderMFSK.I
                let qv = tstData(id, -len)
                if qv > maxVal {
                    maxVal = qv
                    off = i
                }
            }
        }
        let tone = q_[(idx + off) & DecoderMFSK.I]
        return (tone, off)
    }

    private func decSym(_ f: Float) -> UInt8 {
        let df = (f - Float(w)) / Float(c)
        var nib = Int(floor(df + 0.5 + 0.1))
        if nib < 0 { nib = 0 }
        else if nib > 15 { nib = 15 }
        if reverse {
            nib = 15 - nib
        }
        let sym = (nib ^ (nib >> 1)) & 0x0f
        return UInt8(sym)
    }

    private func tstPrint(_ st: Int) -> [UInt8]? {
        var idx = st & DecoderMFSK.I
        let offPkt = getOff(idx, 15)
        if offPkt > 3 {
            return nil
        }
        idx = (idx + offPkt) & DecoderMFSK.I

        for k in 0..<DecoderMFSK.J {
            let forward = (k < 8)
            let (val, off) = forward ? getMax(idx, 7) : getMax(idx, -7)
            r_[k] = decSym(val)
            idx = (idx + DecoderMFSK.G) & DecoderMFSK.I
        }
        let rez = decMsg()
        if rez < 0 {
            return nil
        }
        i_ = DecoderMFSK.G * 8
        for i in 0..<6 {
            u_[i] = t_[ObfTRS.C * 2 + i]
        }
        return u_
    }

    private func decMsg() -> Int {
        let half = DecoderMFSK.J / 2
        for i in 0..<half {
            let hi = r_[i * 2] & 0x0f
            let lo = r_[i * 2 + 1] & 0x0f
            let b = (hi << 4) | lo
            s_[i] = b
        }
        let rsres = v.z(s_, &t_)
        if rsres != 0 {
            return -1
        }
        for i in half..<ObfTRS.A {
            if t_[i] != 0 {
                return -2
            }
        }
        var crc: UInt16 = 0xffff
        var idx = ObfTRS.C * 2
        for _ in 0..<8 {
            crc = ObfCrc.f(t_[idx], crc)
            idx += 1
        }
        if crc != 0 {
            return -3
        }
        var corrected = 0
        for i in 0..<half {
            if t_[i] != s_[i] {
                corrected += 1
            }
        }
        return corrected
    }
}
