import Foundation
import Accelerate

// ============================ CRC ============================

struct ObfCrc {
    static let t: [UInt16] = [
        0x0000,0x1189,0x2312,0x329b,0x4624,0x57ad,0x6536,0x74bf,
        0x8c48,0x9dc1,0xaf5a,0xbed3,0xca6c,0xdbe5,0xe97e,0xf8f7,
        0x1081,0x0108,0x3393,0x221a,0x56a5,0x472c,0x75b7,0x643e,
        0x9cc9,0x8d40,0xbfdb,0xae52,0xdaed,0xcb64,0xf9ff,0xe876,
        0x2102,0x308b,0x0210,0x1399,0x6726,0x76af,0x4434,0x55bd,
        0xad4a,0xbcc3,0x8e58,0x9fd1,0xeb6e,0xfae7,0xc87c,0xd9f5,
        0x3183,0x200a,0x1291,0x0318,0x77a7,0x662e,0x54b5,0x453c,
        0xbdcb,0xac42,0x9ed9,0x8f50,0xfbef,0xea66,0xd8fd,0xc974,
        0x4204,0x538d,0x6116,0x709f,0x0420,0x15a9,0x2732,0x36bb,
        0xce4c,0xdfc5,0xed5e,0xfcd7,0x8868,0x99e1,0xab7a,0xbaf3,
        0x5285,0x430c,0x7197,0x601e,0x14a1,0x0528,0x37b3,0x263a,
        0xdecd,0xcf44,0xfddf,0xec56,0x98e9,0x8960,0xbbfb,0xaa72,
        0x6306,0x728f,0x4014,0x519d,0x2522,0x34ab,0x0630,0x17b9,
        0xef4e,0xfec7,0xcc5c,0xddd5,0xa96a,0xb8e3,0x8a78,0x9bf1,
        0x7387,0x620e,0x5095,0x411c,0x35a3,0x242a,0x16b1,0x0738,
        0xffcf,0xee46,0xdcdd,0xcd54,0xb9eb,0xa862,0x9af9,0x8b70,
        0x8408,0x9581,0xa71a,0xb693,0xc22c,0xd3a5,0xe13e,0xf0b7,
        0x0840,0x19c9,0x2b52,0x3adb,0x4e64,0x5fed,0x6d76,0x7cff,
        0x9489,0x8500,0xb79b,0xa612,0xd2ad,0xc324,0xf1bf,0xe036,
        0x18c1,0x0948,0x3bd3,0x2a5a,0x5ee5,0x4f6c,0x7df7,0x6c7e,
        0xa50a,0xb483,0x8618,0x9791,0xe32e,0xf2a7,0xc03c,0xd1b5,
        0x2942,0x38cb,0x0a50,0x1bd9,0x6f66,0x7eef,0x4c74,0x5dfd,
        0xb58b,0xa402,0x9699,0x8710,0xf3af,0xe226,0xd0bd,0xc134,
        0x39c3,0x284a,0x1ad1,0x0b58,0x7fe7,0x6e6e,0x5cf5,0x4d7c,
        0xc60c,0xd785,0xe51e,0xf497,0x8028,0x91a1,0xa33a,0xb2b3,
        0x4a44,0x5bcd,0x6956,0x78df,0x0c60,0x1de9,0x2f72,0x3efb,
        0xd68d,0xc704,0xf59f,0xe416,0x90a9,0x8120,0xb3bb,0xa232,
        0x5ac5,0x4b4c,0x79d7,0x685e,0x1ce1,0x0d68,0x3ff3,0x2e7a,
        0xe70e,0xf687,0xc41c,0xd595,0xa12a,0xb0a3,0x8238,0x93b1,
        0x6b46,0x7acf,0x4854,0x59dd,0x2d62,0x3ceb,0x0e70,0x1ff9,
        0xf78f,0xe606,0xd49d,0xc514,0xb1ab,0xa022,0x92b9,0x8330,
        0x7bc7,0x6a4e,0x58d5,0x495c,0x3de3,0x2c6a,0x1ef1,0x0f78
    ]

    static func f(_ s: UInt8, _ c: UInt16) -> UInt16 {
        let tmp = (c ^ UInt16(s)) & 0xffff
        let val = t[Int(tmp & 0xff)]
        return ((c >> 8) ^ val) & 0xffff
    }
}

// ============================ RS (GF(2^8), (255,247), t=4) ============================

final class ObfTRS {
    static let A = 255   // N
    static let B = 8     // M
    static let C = 4     // T
    static let D = 247   // K

    // aliases
    static let N = A, M = B, T = C, K = D

    private var pp: [Int] = [1,0,0,0,1,1,1,0,1]
    private var alphaTo: [Int] = Array(repeating: 0, count: A + 1)
    private var indexOf: [Int] = Array(repeating: 0, count: A + 1)
    private var gg: [Int]      = Array(repeating: 0, count: A - D + 1)
    private var recd: [Int]    = Array(repeating: 0, count: A)

    init() {
        generateGf()
        genPoly()
    }

    private func generateGf() {
        var mask = 1
        alphaTo[Self.M] = 0
        for i in 0..<Self.M {
            alphaTo[i] = mask
            indexOf[alphaTo[i]] = i
            if pp[i] != 0 { alphaTo[Self.M] ^= mask }
            mask <<= 1
        }
        indexOf[alphaTo[Self.M]] = Self.M
        mask >>= 1
        for i in (Self.M + 1)..<Self.A {
            if (alphaTo[i - 1] & mask) != 0 {
                alphaTo[i] = alphaTo[Self.M] ^ ((alphaTo[i - 1] ^ mask) << 1)
            } else {
                alphaTo[i] = alphaTo[i - 1] << 1
            }
            indexOf[alphaTo[i]] = i
        }
        indexOf[0] = -1
    }

    private func genPoly() {
        gg[0] = 2
        gg[1] = 1
        for i in 2...(Self.A - Self.D) {
            gg[i] = 1
            for j in stride(from: i - 1, through: 1, by: -1) {
                if gg[j] != 0 {
                    let idx = (indexOf[gg[j]] + i) % Self.A
                    gg[j] = gg[j - 1] ^ alphaTo[idx]
                } else {
                    gg[j] = gg[j - 1]
                }
            }
            let idx2 = (indexOf[gg[0]] + i) % Self.A
            gg[0] = alphaTo[idx2]
        }
        for i in 0...(Self.A - Self.D) {
            gg[i] = indexOf[gg[i]]
        }
    }

    func z(_ input: [UInt8], _ decoded: inout [UInt8]) -> Int {
        for i in 0..<Self.A {
            recd[i] = indexOf[Int(input[i] & 0xff)]
        }

        var synError = false
        var s = Array(repeating: 0, count: Self.A - Self.D + 1)

        for i in 1...(Self.A - Self.D) {
            var sum = 0
            for j in 0..<Self.A {
                let rj = recd[j]
                if rj != -1 {
                    let idx = (rj + i * j) % Self.A
                    sum ^= alphaTo[idx]
                }
            }
            if sum != 0 { synError = true }
            s[i] = indexOf[sum]
        }

        if !synError {
            // Sin errores
            for i in 0..<Self.A {
                recd[i] = (recd[i] != -1) ? alphaTo[recd[i]] : 0
                decoded[i] = UInt8(recd[i] & 0xff)
            }
            return 0
        }

        let dCount = Self.A - Self.D + 2
        var d   = Array(repeating: 0,  count: dCount)
        var elp = Array(repeating: Array(repeating: 0, count: Self.A - Self.D), count: dCount)
        var l   = Array(repeating: 0,  count: dCount)
        var uLu = Array(repeating: 0,  count: dCount)

        d[0] = 0
        d[1] = s[1]
        elp[0][0] = 0
        elp[1][0] = 1
        for i in 1..<(Self.A - Self.D) {
            elp[0][i] = -1
            elp[1][i] = 0
        }
        l[0] = 0
        l[1] = 0
        uLu[0] = -1
        uLu[1] = 0
        var u = 0

        repeat {
            u += 1
            if d[u] == -1 {
                l[u + 1] = l[u]
                for i in 0...l[u] {
                    elp[u + 1][i] = elp[u][i]
                    elp[u][i] = indexOf[elp[u][i]]
                }
            } else {
                var q = u - 1
                while q > 0 && d[q] == -1 { q -= 1 }
                if q > 0 {
                    var j = q
                    while j > 0 {
                        j -= 1
                        if d[j] != -1 && uLu[q] < uLu[j] { q = j }
                    }
                }
                l[u + 1] = (l[u] > l[q] + (u - q)) ? l[u] : (l[q] + (u - q))

                for i in 0..<(Self.A - Self.D) { elp[u + 1][i] = 0 }

                if d[u] != -1 && d[q] != -1 {
                    for i in 0...l[q] {
                        if elp[q][i] != -1 {
                            let idx = (d[u] + Self.A - d[q] + elp[q][i]) % Self.A
                            elp[u + 1][i + (u - q)] ^= alphaTo[idx]
                        }
                    }
                }
                for i in 0...l[u] {
                    elp[u + 1][i] ^= elp[u][i]
                    elp[u][i] = indexOf[elp[u][i]]
                }
            }
            uLu[u + 1] = u - l[u + 1]

            if u < (Self.A - Self.D) {
                var sum = (s[u + 1] != -1) ? alphaTo[s[u + 1]] : 0
                if l[u + 1] > 0 {
                    for i in 1...l[u + 1] {
                        if s[u + 1 - i] != -1, elp[u + 1][i] != 0 {
                            let idx = (s[u + 1 - i] + indexOf[elp[u + 1][i]]) % Self.A
                            sum ^= alphaTo[idx]
                        }
                    }
                }
                d[u + 1] = indexOf[sum]
            }
        } while (u < (Self.A - Self.D) && l[u + 1] <= Self.C)
        u += 1

        if l[u] > Self.C {
            for i in 0..<Self.A {
                recd[i] = (recd[i] != -1) ? alphaTo[recd[i]] : 0
                decoded[i] = UInt8(recd[i] & 0xff)
            }
            return -1
        }

        for i in 0...l[u] { elp[u][i] = indexOf[elp[u][i]] }

        var reg = Array(repeating: 0, count: Self.C + 1)
        for i in 1...l[u] { reg[i] = elp[u][i] }

        var root = Array(repeating: 0, count: Self.C)
        var loc  = Array(repeating: 0, count: Self.C)
        var cnt = 0

        for r in 1...Self.A {
            var q = 1
            for j in 1...l[u] {
                if reg[j] != -1 {
                    reg[j] = (reg[j] + j) % Self.A
                    q ^= alphaTo[reg[j]]
                }
            }
            if q == 0 {
                root[cnt] = r
                loc[cnt]  = Self.A - r
                cnt += 1
            }
        }

        if cnt != l[u] {
            for i in 0..<Self.A {
                recd[i] = (recd[i] != -1) ? alphaTo[recd[i]] : 0
                decoded[i] = UInt8(recd[i] & 0xff)
            }
            return -1
        }

        var z = Array(repeating: 0, count: Self.C + 1)
        if l[u] > 0 {
            for rr in 1...l[u] {
                if s[rr] != -1 && elp[u][rr] != -1 {
                    z[rr] = alphaTo[s[rr]] ^ alphaTo[elp[u][rr]]
                } else if s[rr] != -1 && elp[u][rr] == -1 {
                    z[rr] = alphaTo[s[rr]]
                } else if s[rr] == -1 && elp[u][rr] != -1 {
                    z[rr] = alphaTo[elp[u][rr]]
                } else {
                    z[rr] = 0
                }
                if rr >= 2 {
                    for jj in 1..<rr {
                        if s[rr - jj] != -1 && elp[u][jj] != -1 {
                            let idx = (elp[u][jj] + s[rr - jj]) % Self.A
                            z[rr] ^= alphaTo[idx]
                        }
                    }
                }
                z[rr] = indexOf[z[rr]]
            }
        }

        var err = Array(repeating: 0, count: Self.A)
        for j in 0..<Self.A {
            recd[j] = (recd[j] != -1) ? alphaTo[recd[j]] : 0
        }

        if l[u] > 0 {
            for rr in 0..<l[u] {
                err[loc[rr]] = 1
                if l[u] > 0 {
                    for jj in 1...l[u] {
                        if z[jj] != -1 {
                            let idx = (z[jj] + jj * root[rr]) % Self.A
                            err[loc[rr]] ^= alphaTo[idx]
                        }
                    }
                }
                if err[loc[rr]] != 0 {
                    err[loc[rr]] = indexOf[err[loc[rr]]]
                    var qq = 0
                    if l[u] > 1 {
                        for m in 0..<l[u] where m != rr {
                            let tmp = (loc[m] + root[rr]) % Self.A
                            qq += indexOf[1 ^ alphaTo[tmp]]
                        }
                    }
                    qq %= Self.A
                    let newVal = (err[loc[rr]] - qq + Self.A) % Self.A
                    err[loc[rr]] = alphaTo[newVal]
                    recd[loc[rr]] ^= err[loc[rr]]
                }
            }
        }

        for j in 0..<Self.A {
            decoded[j] = UInt8(recd[j] & 0xff)
        }
        return 0
    }
}

// ============================ FFT wrapper ============================

final class ObfFft {
    private static var cache: [Int: FFTSetup] = [:]
    private static let lock = NSLock()

    @discardableResult
    static func fftF(inp: [Float], outR: inout [Float], outI: inout [Float]) -> Bool {
        let N = inp.count
        var log2n = 0
        var v = N
        while v > 1 { v >>= 1; log2n += 1 }
        guard (2...14).contains(log2n) else { return false }

        var setup: FFTSetup!
        lock.lock()
        if let s = cache[log2n] {
            setup = s
        } else {
            setup = vDSP_create_fftsetup(vDSP_Length(log2n), FFTRadix(kFFTRadix2))
            cache[log2n] = setup
        }
        lock.unlock()

        if outR.count < N { outR = .init(repeating: 0, count: N) }
        if outI.count < N { outI = .init(repeating: 0, count: N) }

        outR.withUnsafeMutableBufferPointer { rPtr in
            outI.withUnsafeMutableBufferPointer { iPtr in
                guard let realp = rPtr.baseAddress, let imagp = iPtr.baseAddress else { return }
                inp.withUnsafeBufferPointer { inPtr in
                    cblas_scopy(Int32(N), inPtr.baseAddress!, 1, realp, 1)
                    vDSP_vclr(imagp, 1, vDSP_Length(N))
                    var split = DSPSplitComplex(realp: realp, imagp: imagp)
                    vDSP_fft_zrip(setup, &split, 1, vDSP_Length(log2n), FFTDirection(FFT_FORWARD))
                }
            }
        }
        return true
    }
}

// ============================ Decoder MFSK ============================

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

        self.e  = DecoderMFSK.F / speed
        self.f_ = Int(floor((2000.0 * Float(self.e) + Float(DecoderMFSK.G)) / Float(2 * DecoderMFSK.G)))

        self.k_ = .init(repeating: 0, count: DecoderMFSK.F)
        self.l_ = .init(repeating: 0, count: DecoderMFSK.F)
        self.m_ = .init(repeating: 0, count: DecoderMFSK.F)
        self.n_ = .init(repeating: 0, count: DecoderMFSK.F)
        self.o_ = .init(repeating: 0, count: DecoderMFSK.F / 2)
        self.p_ = .init(repeating: 0, count: DecoderMFSK.H)
        self.q_ = .init(repeating: 0, count: DecoderMFSK.H)

        self.r_ = .init(repeating: 0, count: ObfTRS.A)
        self.s_ = .init(repeating: 0, count: ObfTRS.A)
        self.t_ = .init(repeating: 0, count: ObfTRS.A)
        self.u_ = .init(repeating: 0, count: 6)

        let dfft  = DecoderMFSK.K / Float(self.e)
        let df    = dfft * Float(self.c)
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
        let fl2 = Float(e) * Float(e)
        for i in (x - 1)...(y + 1) {
            let v0 = m_[i] / fl2
            var val = v0 * v0
            let v1 = n_[i] / fl2
            val += v1 * v1
            val = (val > 3e-11) ? sqrt(val) : 0
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
        var maxv: Float = -1
        var minv: Float =  9_999_999

        for i in x...y {
            let v = o_[i]
            if v > maxv { maxv = v; a = i }
            if v < minv { minv = v }
        }
        let diff = maxv - minv

        var df: Float = 0
        if maxv > 5e-6 {
            let vL = o_[a - 1]
            let vR = o_[a + 1]
            if vR > vL {
                if (maxv - vL) > 1e-5 {
                    df = 0.5 * (vR - vL) / (maxv - vL)
                } else if (maxv - vR) > 1e-5 {
                    df = 0.5 * (vR - vL) / (maxv - vR)
                }
            }
        }
        let vali = Float(a) + df
        let shifted = floor((vali - Float(w)) / Float(c) + 0.5) * Float(c)
        let valf = Float(w) + shifted
        return (Int(valf), diff)
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
                if qv > maxVal { maxVal = qv; off = i }
            }
        } else if len < 0 {
            let st = (idx + DecoderMFSK.G * (len + 1)) & DecoderMFSK.I
            for i in -2...2 {
                let id = (st + i) & DecoderMFSK.I
                let qv = tstData(id, -len)
                if qv > maxVal { maxVal = qv; off = i }
            }
        }
        let tone = q_[(idx + off) & DecoderMFSK.I]
        return (tone, off)
    }

    private func decSym(_ f: Float) -> UInt8 {
        var df = (f - Float(w)) / Float(c)
        var nib = Int(floor(df + 0.5 + 0.1))
        if nib < 0 { nib = 0 } else if nib > 15 { nib = 15 }
        if reverse { nib = 15 - nib }
        let sym = (nib ^ (nib >> 1)) & 0x0f
        return UInt8(sym)
    }

    private func tstPrint(_ st: Int) -> [UInt8]? {
        var idx = st & DecoderMFSK.I
        let offPkt = getOff(idx, 15)
        if offPkt > 3 { return nil }
        idx = (idx + offPkt) & DecoderMFSK.I

        for k in 0..<DecoderMFSK.J {
            let forward = (k < 8)
            let (val, _) = forward ? getMax(idx, 7) : getMax(idx, -7)
            r_[k] = decSym(val)
            idx = (idx + DecoderMFSK.G) & DecoderMFSK.I
        }

        let rez = decMsg()
        if rez < 0 { return nil }

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
            s_[i] = (hi << 4) | lo
        }

        let rsres = v.z(s_, &t_)
        if rsres != 0 { return -1 }

        for i in half..<ObfTRS.A { if t_[i] != 0 { return -2 } }

        var crc: UInt16 = 0xffff
        var idx = ObfTRS.C * 2
        for _ in 0..<8 {
            crc = ObfCrc.f(t_[idx], crc); idx += 1
        }
        if crc != 0 { return -3 }

        var corrected = 0
        for i in 0..<half { if t_[i] != s_[i] { corrected += 1 } }
        return corrected
    }
}
