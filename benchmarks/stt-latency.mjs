#!/usr/bin/env node

/**
 * STT Latency Benchmark — Measures user-perceived response time
 *
 * Key metric: Time from sending last audio frame (status=2) to
 * receiving the final recognition result (data.status=2).
 *
 * This is the delay the user feels after they stop speaking.
 *
 * Usage:
 *   node benchmarks/stt-latency.mjs                    # full benchmark
 *   node benchmarks/stt-latency.mjs --quick             # 1 iteration per case
 *   node benchmarks/stt-latency.mjs --iterations 10     # custom iterations
 */

import { execSync } from 'child_process'
import { readFileSync, unlinkSync, existsSync } from 'fs'
import crypto from 'crypto'
import WebSocket from 'ws'
import { performance } from 'perf_hooks'

// ─── Config ──────────────────────────────────────────────────────────────────

const IFLYTEK = {
  appId: process.env.IFLYTEK_APP_ID || '93214a4e',
  apiKey: process.env.IFLYTEK_API_KEY || '58098814c38df62d8bf2979a3c39c735',
  apiSecret: process.env.IFLYTEK_API_SECRET || 'NjY4NzM5NjNkNjU3NzQyMzgyZDM4OTgy',
}

const FRAME_SIZE = 1280
const FRAME_INTERVAL_MS = 40

// ─── CLI Args ────────────────────────────────────────────────────────────────

const args = process.argv.slice(2)
const isQuick = args.includes('--quick')
const iterIdx = args.indexOf('--iterations')
const ITERATIONS = isQuick ? 1 : (iterIdx >= 0 ? parseInt(args[iterIdx + 1], 10) : 3)

// ─── Helpers ─────────────────────────────────────────────────────────────────

function buildAuthUrl() {
  const host = 'iat-api.xfyun.cn'
  const path = '/v2/iat'
  const date = new Date().toUTCString()
  const sig = crypto
    .createHmac('sha256', IFLYTEK.apiSecret)
    .update(`host: ${host}\ndate: ${date}\nGET ${path} HTTP/1.1`)
    .digest('base64')
  const auth = Buffer.from(
    `api_key="${IFLYTEK.apiKey}", algorithm="hmac-sha256", headers="host date request-line", signature="${sig}"`,
  ).toString('base64')
  return `wss://${host}${path}?authorization=${auth}&date=${encodeURIComponent(date)}&host=${host}`
}

function generateAudio(text, voice) {
  const tmp = `/tmp/verbo-bench-${Date.now()}.wav`
  execSync(`say -v ${voice} "${text.replace(/"/g, '\\"')}" -o /tmp/verbo-bench.aiff`)
  execSync(`afconvert -f WAVE -d LEI16@16000 -c 1 /tmp/verbo-bench.aiff ${tmp}`)
  try { unlinkSync('/tmp/verbo-bench.aiff') } catch {}
  return tmp
}

function readPCM(wavPath) {
  const buf = readFileSync(wavPath)
  return buf.slice(44) // skip WAV header
}

function splitFrames(pcm) {
  const frames = []
  for (let i = 0; i < pcm.length; i += FRAME_SIZE) {
    frames.push(pcm.slice(i, i + FRAME_SIZE))
  }
  return frames
}

// ─── Core Benchmark Function ─────────────────────────────────────────────────

/**
 * Run a single STT recognition and measure timing at each phase.
 *
 * Returns:
 *   - wsConnectMs:    WebSocket open latency
 *   - sendingMs:      Time to send all audio frames
 *   - lastFrameToResultMs:  ** THE KEY METRIC ** — last frame sent → final result received
 *   - totalMs:        Total wall clock time
 *   - text:           Recognized text
 *   - frameCount:     Number of audio frames sent
 *   - audioLengthMs:  Duration of audio in milliseconds
 */
function runSTT(pcm, lang) {
  return new Promise((resolve, reject) => {
    const frames = splitFrames(pcm)
    const language = lang === 'en' ? 'en_us' : 'cn_mandarin'
    const audioLengthMs = (pcm.length / 2 / 16000) * 1000 // 16-bit mono 16kHz

    const timing = {
      benchStart: performance.now(),
      wsConnected: 0,
      firstFrameSent: 0,
      lastFrameSent: 0,
      firstResultReceived: 0,
      finalResultReceived: 0,
    }

    const sentences = new Map()
    let maxSn = 0
    let finalText = ''
    let idx = 0
    let partialCount = 0

    const timer = setTimeout(() => {
      reject(new Error('Timeout 30s'))
    }, 30000)

    const url = buildAuthUrl()
    const ws = new WebSocket(url)

    ws.on('open', () => {
      timing.wsConnected = performance.now()

      // Send first frame
      ws.send(
        JSON.stringify({
          common: { app_id: IFLYTEK.appId },
          business: { language, domain: 'iat', accent: language, vad_eos: 3000, dwa: 'wpgs' },
          data: {
            status: frames.length === 1 ? 2 : 0,
            format: 'audio/L16;rate=16000',
            encoding: 'raw',
            audio: frames[0].toString('base64'),
          },
        }),
      )
      timing.firstFrameSent = performance.now()
      idx = 1

      if (frames.length === 1) {
        timing.lastFrameSent = timing.firstFrameSent
        return
      }

      const sendNext = () => {
        if (idx >= frames.length) return
        const isLast = idx === frames.length - 1
        ws.send(
          JSON.stringify({
            data: {
              status: isLast ? 2 : 1,
              format: 'audio/L16;rate=16000',
              encoding: 'raw',
              audio: frames[idx].toString('base64'),
            },
          }),
        )
        if (isLast) {
          timing.lastFrameSent = performance.now()
        }
        idx++
        if (!isLast) setTimeout(sendNext, FRAME_INTERVAL_MS)
      }
      sendNext()
    })

    ws.on('message', (data) => {
      const now = performance.now()
      const r = JSON.parse(data)

      if (r.code !== 0) {
        clearTimeout(timer)
        ws.close()
        reject(new Error(`iFlytek ${r.code}: ${r.message}`))
        return
      }

      if (timing.firstResultReceived === 0) {
        timing.firstResultReceived = now
      }

      const result = r.data?.result
      if (result) {
        partialCount++
        const text = (result.ws || [])
          .flatMap((w) => w.cw || [])
          .filter(Boolean)
          .map((c) => c.w || '')
          .join('')
        const sn = result.sn || 0
        const pgs = result.pgs
        const rg = result.rg || [0, 0]

        if (pgs === 'rpl') {
          for (let i = rg[0]; i <= rg[1]; i++) sentences.delete(i)
        }
        sentences.set(sn, text)
        maxSn = Math.max(maxSn, sn)

        const parts = []
        for (let i = 0; i <= maxSn; i++) {
          const s = sentences.get(i)
          if (s !== undefined) parts.push(s)
        }
        finalText = parts.join('')
      }

      if (r.data?.status === 2) {
        timing.finalResultReceived = now
        clearTimeout(timer)
        ws.close()

        const wsConnectMs = timing.wsConnected - timing.benchStart
        const sendingMs = timing.lastFrameSent - timing.firstFrameSent
        const lastFrameToResultMs = timing.finalResultReceived - timing.lastFrameSent
        const firstResultLatencyMs = timing.firstResultReceived - timing.firstFrameSent
        const totalMs = timing.finalResultReceived - timing.benchStart

        resolve({
          wsConnectMs: Math.round(wsConnectMs * 100) / 100,
          sendingMs: Math.round(sendingMs * 100) / 100,
          lastFrameToResultMs: Math.round(lastFrameToResultMs * 100) / 100,
          firstResultLatencyMs: Math.round(firstResultLatencyMs * 100) / 100,
          totalMs: Math.round(totalMs * 100) / 100,
          text: finalText,
          frameCount: frames.length,
          audioLengthMs: Math.round(audioLengthMs),
          partialCount,
        })
      }
    })

    ws.on('error', (e) => {
      clearTimeout(timer)
      reject(e)
    })
  })
}

// ─── Test Cases ──────────────────────────────────────────────────────────────

const TEST_CASES = [
  {
    name: 'ZH Short (2s)',
    text: '今天天气不错',
    voice: 'Tingting',
    lang: 'zh',
  },
  {
    name: 'ZH Medium (4s)',
    text: '明天下午两点我们需要讨论一下新功能的开发计划',
    voice: 'Tingting',
    lang: 'zh',
  },
  {
    name: 'ZH Long (7s)',
    text: '我觉得这个方案还是可以的，但是我们需要再讨论一下具体的实现细节，特别是关于性能优化的部分',
    voice: 'Tingting',
    lang: 'zh',
  },
  {
    name: 'EN Short (2s)',
    text: 'Hello how are you',
    voice: 'Samantha',
    lang: 'en',
  },
  {
    name: 'EN Medium (4s)',
    text: 'We need to discuss the deployment strategy before Friday',
    voice: 'Samantha',
    lang: 'en',
  },
  {
    name: 'EN Long (7s)',
    text: 'I think we should reconsider the architecture design because the current approach might not scale well for our expected user growth',
    voice: 'Samantha',
    lang: 'en',
  },
]

// ─── Stats ───────────────────────────────────────────────────────────────────

function calcStats(values) {
  const sorted = [...values].sort((a, b) => a - b)
  const n = sorted.length
  const sum = sorted.reduce((a, b) => a + b, 0)
  return {
    min: sorted[0],
    max: sorted[n - 1],
    avg: Math.round((sum / n) * 100) / 100,
    median: n % 2 === 0 ? (sorted[n / 2 - 1] + sorted[n / 2]) / 2 : sorted[Math.floor(n / 2)],
    p95: sorted[Math.floor(n * 0.95)] ?? sorted[n - 1],
  }
}

// ─── Main ────────────────────────────────────────────────────────────────────

async function main() {
  console.log('╔══════════════════════════════════════════════════════════════╗')
  console.log('║        Verbo STT Latency Benchmark                         ║')
  console.log('║        Key metric: last frame → final result               ║')
  console.log(`║        Iterations per case: ${ITERATIONS}                              ║`)
  console.log('╚══════════════════════════════════════════════════════════════╝')
  console.log()

  const allResults = []

  for (const tc of TEST_CASES) {
    console.log(`── ${tc.name} ──────────────────────────────────────`)
    console.log(`   Text: "${tc.text}"`)

    // Generate audio once per test case
    const wavPath = generateAudio(tc.text, tc.voice)
    const pcm = readPCM(wavPath)
    console.log(`   Audio: ${Math.round(pcm.length / 2 / 16000 * 1000)}ms, ${pcm.length} bytes, ${Math.ceil(pcm.length / FRAME_SIZE)} frames`)

    const latencies = []
    const totals = []
    const wsConnects = []
    const firstResults = []

    for (let i = 0; i < ITERATIONS; i++) {
      try {
        const result = await runSTT(pcm, tc.lang)

        latencies.push(result.lastFrameToResultMs)
        totals.push(result.totalMs)
        wsConnects.push(result.wsConnectMs)
        firstResults.push(result.firstResultLatencyMs)

        const icon = result.lastFrameToResultMs < 500 ? '🟢' : result.lastFrameToResultMs < 1000 ? '🟡' : '🔴'
        console.log(
          `   [${i + 1}/${ITERATIONS}] ${icon} last→result: ${result.lastFrameToResultMs}ms | ` +
          `ws: ${result.wsConnectMs}ms | total: ${result.totalMs}ms | ` +
          `partials: ${result.partialCount} | "${result.text.slice(0, 30)}${result.text.length > 30 ? '...' : ''}"`,
        )
      } catch (e) {
        console.log(`   [${i + 1}/${ITERATIONS}] ❌ Error: ${e.message}`)
      }

      // Brief pause between iterations to avoid rate limiting
      if (i < ITERATIONS - 1) {
        await new Promise((r) => setTimeout(r, 500))
      }
    }

    if (latencies.length > 0) {
      const stats = calcStats(latencies)
      const totalStats = calcStats(totals)

      allResults.push({
        name: tc.name,
        lang: tc.lang,
        audioMs: Math.round(pcm.length / 2 / 16000 * 1000),
        latency: stats,
        total: totalStats,
        samples: latencies.length,
      })

      if (ITERATIONS > 1) {
        console.log(`   ── Stats (${latencies.length} samples) ──`)
        console.log(`   Last→Result:  avg=${stats.avg}ms  median=${stats.median}ms  min=${stats.min}ms  max=${stats.max}ms`)
        console.log(`   Total:        avg=${totalStats.avg}ms`)
      }
    }

    try { unlinkSync(wavPath) } catch {}
    console.log()
  }

  // ─── Summary Table ───
  console.log('╔══════════════════════════════════════════════════════════════════════════╗')
  console.log('║                         Summary                                        ║')
  console.log('╠═══════════════════╦═══════╦════════════════════════════╦════════════════╣')
  console.log('║ Test Case         ║ Audio ║ Last Frame → Result (ms)  ║ Total (ms)     ║')
  console.log('║                   ║  (ms) ║  avg  │ median │  p95     ║  avg           ║')
  console.log('╠═══════════════════╬═══════╬═══════╪════════╪══════════╬════════════════╣')

  for (const r of allResults) {
    const name = r.name.padEnd(17)
    const audio = String(r.audioMs).padStart(5)
    const avg = String(r.latency.avg).padStart(5)
    const med = String(r.latency.median).padStart(6)
    const p95 = String(r.latency.p95).padStart(6)
    const total = String(r.total.avg).padStart(8)
    console.log(`║ ${name} ║ ${audio} ║ ${avg} │ ${med} │ ${p95}   ║ ${total}       ║`)
  }

  console.log('╚═══════════════════╩═══════╩═══════╧════════╧══════════╩════════════════╝')

  // ─── Verdict ───
  console.log()
  const allLatencies = allResults.flatMap((r) => [r.latency.avg])
  const maxAvg = Math.max(...allLatencies)
  if (maxAvg < 500) {
    console.log('✅ All latencies under 500ms — excellent user experience')
  } else if (maxAvg < 1000) {
    console.log('⚠️  Some latencies 500-1000ms — acceptable but noticeable')
  } else {
    console.log('❌ Some latencies over 1000ms — poor user experience, investigate')
  }
}

main().catch((e) => {
  console.error('Fatal:', e)
  process.exit(1)
})
