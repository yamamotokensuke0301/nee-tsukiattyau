#!/usr/bin/env swift

import Foundation
import AVFoundation
import AudioToolbox

let sampleRate = 44_100.0
let maxRenderFrames: AVAudioFrameCount = 1_024
let soundBankURL = URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")

struct InstrumentSpec {
    let name: String
    let program: UInt8
    let volume: Float
    let pan: Float
}

struct NoteSpec {
    let voice: Int
    let startBeat: Double
    let durationBeats: Double
    let midi: UInt8
    let velocity: UInt8
}

struct Cue {
    let id: String
    let title: String
    let bpm: Double
    let bars: Int
    let instruments: [InstrumentSpec]
    let notes: [NoteSpec]
    let targetRMS: Float

    var beats: Double { Double(bars * 4) }
    var secondsPerBeat: Double { 60.0 / bpm }
    var duration: Double { beats * secondsPerBeat }
}

struct ScoreBuilder {
    var notes: [NoteSpec] = []

    mutating func note(_ voice: Int, _ start: Double, _ duration: Double, _ midi: Int, _ velocity: Int) {
        notes.append(
            NoteSpec(
                voice: voice,
                startBeat: start,
                durationBeats: max(0.08, duration),
                midi: UInt8(max(0, min(127, midi))),
                velocity: UInt8(max(1, min(127, velocity)))
            )
        )
    }

    mutating func chord(
        _ voice: Int,
        _ start: Double,
        _ duration: Double,
        _ pitches: [Int],
        _ velocity: Int,
        stagger: Double = 0
    ) {
        for (index, pitch) in pitches.enumerated() {
            note(voice, start + Double(index) * stagger, duration - Double(index) * stagger, pitch, velocity - index)
        }
    }

    mutating func arpeggio(
        _ voice: Int,
        _ start: Double,
        chord pitches: [Int],
        pattern: [Int],
        step: Double,
        length: Double,
        velocity: Int
    ) {
        for (index, pitchIndex) in pattern.enumerated() {
            let accent = index == 0 ? 4 : (index % 2 == 0 ? 1 : -2)
            note(voice, start + Double(index) * step, length, pitches[pitchIndex], velocity + accent)
        }
    }

    mutating func melody(
        _ voice: Int,
        _ start: Double,
        _ phrase: [(Double, Double, Int, Int)]
    ) {
        for (offset, duration, pitch, velocity) in phrase {
            note(voice, start + offset, duration, pitch, velocity)
        }
    }
}

let piano = InstrumentSpec(name: "felt piano", program: 0, volume: 0.64, pan: -0.08)
let electricPiano = InstrumentSpec(name: "soft electric piano", program: 4, volume: 0.52, pan: -0.06)
let nylonGuitar = InstrumentSpec(name: "nylon guitar", program: 24, volume: 0.58, pan: -0.18)
let musicBox = InstrumentSpec(name: "music box", program: 10, volume: 0.30, pan: 0.28)
let vibraphone = InstrumentSpec(name: "vibraphone", program: 11, volume: 0.34, pan: 0.22)
let acousticBass = InstrumentSpec(name: "acoustic bass", program: 32, volume: 0.42, pan: 0.02)
let strings = InstrumentSpec(name: "soft strings", program: 48, volume: 0.29, pan: 0.12)
let pizzicato = InstrumentSpec(name: "pizzicato strings", program: 45, volume: 0.36, pan: 0.12)
let flute = InstrumentSpec(name: "flute", program: 73, volume: 0.31, pan: 0.18)
let clarinet = InstrumentSpec(name: "clarinet", program: 71, volume: 0.30, pan: 0.16)

func cue01() -> Cue {
    var score = ScoreBuilder()
    let chords = [
        [48, 55, 59, 64], [45, 52, 55, 60], [41, 48, 52, 57], [43, 50, 55, 62],
        [48, 55, 59, 64], [45, 52, 55, 60], [41, 48, 52, 57], [43, 50, 57, 62],
        [45, 52, 55, 60], [41, 48, 52, 57], [50, 57, 60, 65], [43, 50, 55, 62],
    ]
    for (bar, chord) in chords.enumerated() {
        let start = Double(bar * 4)
        score.arpeggio(1, start, chord: [chord[0] + 12, chord[1] + 12, chord[2] + 12, chord[3] + 12], pattern: [0, 2, 1, 3], step: 1, length: 0.78, velocity: 48)
        score.note(0, start, 1.8, chord[0], 43)
        score.note(0, start + 2, 1.5, chord[1], 38)
        if bar % 2 == 0 {
            score.chord(2, start, 7.25, chord.map { $0 + 12 }, 35)
        }
    }
    score.melody(0, 8, [
        (0, 0.8, 67, 58), (1, 0.8, 64, 54), (2, 1.7, 69, 60),
        (4, 0.8, 67, 56), (5, 0.8, 64, 52), (6, 1.45, 62, 50),
    ])
    score.melody(0, 24, [
        (0, 0.8, 64, 52), (1, 0.8, 67, 56), (2, 1.7, 72, 61),
        (4, 0.8, 71, 55), (5, 0.8, 67, 52), (6, 1.45, 69, 54),
    ])
    score.melody(0, 40, [
        (0, 0.8, 67, 52), (1, 0.8, 64, 48), (2, 1.6, 69, 54),
        (4, 0.8, 67, 50), (5, 0.8, 64, 46), (6, 1.0, 62, 44),
    ])
    return Cue(id: "01", title: "はじめましての余白", bpm: 76, bars: 12, instruments: [piano, nylonGuitar, strings], notes: score.notes, targetRMS: 0.070)
}

func cue02() -> Cue {
    var score = ScoreBuilder()
    let chords = [
        [43, 50, 55, 59], [42, 50, 54, 57], [40, 47, 52, 55], [48, 55, 59, 64],
        [43, 50, 55, 59], [42, 50, 54, 57], [40, 47, 52, 55], [48, 55, 59, 64],
        [45, 52, 57, 60], [48, 55, 59, 64], [43, 50, 55, 59], [38, 45, 50, 57],
    ]
    for (bar, chord) in chords.enumerated() {
        let start = Double(bar * 4)
        score.arpeggio(0, start, chord: chord.map { $0 + 12 }, pattern: [0, 2, 1, 3, 1, 2, 0, 2], step: 0.5, length: 0.38, velocity: 45)
        score.note(1, start, 1.55, chord[0] - 12, 43)
        score.note(1, start + 2, 1.35, chord[1] - 12, 38)
    }
    score.melody(2, 8, [
        (0, 0.65, 71, 47), (1, 0.65, 74, 51), (2, 1.5, 76, 54),
        (4, 0.65, 74, 49), (5, 0.65, 71, 45), (6, 1.35, 69, 44),
    ])
    score.melody(2, 28, [
        (0, 0.65, 74, 48), (1, 0.65, 76, 51), (2, 1.5, 79, 55),
        (4, 0.65, 76, 48), (5, 0.65, 74, 46), (6, 1.4, 71, 44),
    ])
    return Cue(id: "02", title: "振り返る風", bpm: 84, bars: 12, instruments: [nylonGuitar, acousticBass, flute], notes: score.notes, targetRMS: 0.066)
}

func cue03() -> Cue {
    var score = ScoreBuilder()
    let chords = [
        [41, 48, 52, 57], [45, 52, 55, 60], [43, 50, 53, 58], [48, 55, 58, 64],
        [41, 48, 52, 57], [46, 53, 57, 62], [43, 50, 53, 58], [48, 55, 57, 62],
    ]
    for (bar, chord) in chords.enumerated() {
        let start = Double(bar * 4)
        score.chord(0, start, 2.25, chord.map { $0 + 12 }, 43, stagger: 0.025)
        score.chord(0, start + 2.5, 1.05, [chord[1] + 12, chord[2] + 12, chord[3] + 12], 35, stagger: 0.02)
        score.note(2, start, 2.7, chord[0] - 12, 39)
        if [1, 3, 5, 7].contains(bar) {
            score.note(1, start + 1.5, 1.15, chord[3] + 24, 37)
        }
    }
    score.melody(1, 8, [
        (0, 1.2, 81, 38), (2, 0.8, 79, 34), (4, 1.5, 76, 36),
        (7, 0.8, 74, 31),
    ])
    score.melody(1, 24, [
        (0, 1.2, 79, 36), (2, 0.8, 81, 38), (4, 1.5, 84, 40),
        (6.5, 0.8, 81, 34),
    ])
    return Cue(id: "03", title: "縁側、午後三時", bpm: 68, bars: 8, instruments: [electricPiano, vibraphone, acousticBass], notes: score.notes, targetRMS: 0.058)
}

func cue04() -> Cue {
    var score = ScoreBuilder()
    let chords = [
        [47, 54, 57, 62], [43, 50, 54, 59], [38, 45, 50, 57], [45, 52, 57, 62],
        [47, 54, 57, 62], [43, 50, 54, 59], [50, 57, 62, 66], [45, 52, 57, 62],
    ]
    for (bar, chord) in chords.enumerated() {
        let start = Double(bar * 4)
        score.note(0, start, 1.8, chord[0], 42)
        score.note(0, start + 1.45, 1.2, chord[2] + 12, 38)
        score.note(0, start + 2.8, 0.85, chord[1] + 12, 34)
        score.chord(1, start, 3.45, chord.map { $0 + 12 }, 28)
    }
    score.melody(2, 4, [
        (0, 1.35, 66, 43), (2, 1.35, 62, 39), (4, 2.8, 67, 45),
        (8, 1.35, 66, 41), (10, 1.35, 62, 37), (12, 2.2, 61, 36),
    ])
    score.melody(0, 24, [
        (0, 1.25, 57, 39), (2, 1.25, 62, 42), (4, 2.6, 66, 45),
    ])
    return Cue(id: "04", title: "バスはまだ来ない", bpm: 62, bars: 8, instruments: [piano, strings, clarinet], notes: score.notes, targetRMS: 0.054)
}

func cue05() -> Cue {
    var score = ScoreBuilder()
    let chords = [
        [46, 53, 57, 62], [45, 53, 57, 60], [43, 50, 53, 58], [39, 46, 51, 58],
        [46, 53, 57, 62], [41, 48, 53, 57], [43, 50, 53, 58], [41, 48, 51, 58],
        [46, 53, 57, 62], [45, 53, 57, 60], [39, 46, 51, 58], [41, 48, 53, 60],
    ]
    let pattern = [0, 2, 1, 3, 2, 1]
    for (bar, chord) in chords.enumerated() {
        let start = Double(bar * 4)
        score.arpeggio(1, start, chord: chord.map { $0 + 12 }, pattern: pattern, step: 2.0 / 3.0, length: 0.52, velocity: 42)
        score.note(2, start, 2.45, chord[0] - 12, 41)
        score.note(2, start + 2.65, 0.85, chord[1] - 12, 34)
        if bar % 2 == 0 {
            score.chord(0, start + 0.05, 3.2, [chord[1] + 12, chord[2] + 12, chord[3] + 12], 35, stagger: 0.04)
        }
    }
    score.melody(0, 8, [
        (0, 1.2, 65, 47), (1.5, 0.7, 62, 43), (2.5, 1.3, 67, 49),
        (4.5, 1.0, 65, 44), (6, 1.5, 60, 40),
    ])
    score.melody(0, 32, [
        (0, 1.2, 62, 43), (1.5, 0.7, 65, 46), (2.5, 1.3, 70, 50),
        (4.5, 1.0, 67, 44), (6, 1.4, 65, 42),
    ])
    return Cue(id: "05", title: "夕暮れの水音", bpm: 72, bars: 12, instruments: [piano, nylonGuitar, strings], notes: score.notes, targetRMS: 0.061)
}

func cue06() -> Cue {
    var score = ScoreBuilder()
    let chords = [
        [45, 52, 57, 60], [41, 48, 52, 57], [48, 55, 60, 64], [43, 50, 55, 59],
        [45, 52, 57, 60], [41, 48, 52, 57], [50, 57, 60, 65], [43, 50, 57, 62],
    ]
    for (bar, chord) in chords.enumerated() {
        let start = Double(bar * 4)
        score.arpeggio(0, start, chord: chord.map { $0 + 12 }, pattern: [0, 2, 1, 3, 2, 1], step: 2.0 / 3.0, length: 0.52, velocity: 41)
        score.note(0, start + 3.35, 0.4, chord[2] + 12, 34)
        if bar % 2 == 1 {
            score.note(1, start + 1.35, 1.0, chord[3] + 24, 34)
        }
    }
    score.melody(1, 8, [
        (0, 0.7, 76, 36), (1, 0.7, 79, 39), (2, 1.5, 84, 42),
        (5, 0.7, 83, 36), (6, 1.1, 79, 34),
    ])
    score.melody(1, 24, [
        (0, 0.7, 81, 36), (1, 0.7, 79, 34), (2, 1.4, 76, 35),
        (5, 1.2, 74, 32),
    ])
    return Cue(id: "06", title: "花を見ているふり", bpm: 66, bars: 8, instruments: [nylonGuitar, musicBox], notes: score.notes, targetRMS: 0.050)
}

func cue07() -> Cue {
    var score = ScoreBuilder()
    let chords = [
        [48, 55, 59, 64], [45, 52, 55, 60], [41, 48, 52, 57], [43, 50, 55, 59],
        [48, 55, 59, 64], [45, 52, 55, 60], [50, 57, 60, 65], [43, 50, 55, 62],
        [48, 55, 59, 64], [41, 48, 52, 57], [45, 52, 55, 60], [43, 50, 57, 62],
    ]
    for (bar, chord) in chords.enumerated() {
        let start = Double(bar * 4)
        score.chord(0, start, 0.82, chord.map { $0 + 12 }, 42, stagger: 0.018)
        score.chord(0, start + 1.5, 0.58, [chord[1] + 12, chord[2] + 12, chord[3] + 12], 34)
        score.chord(0, start + 3, 0.68, [chord[1] + 12, chord[2] + 12, chord[3] + 12], 38)
        score.note(1, start, 0.72, chord[0], 41)
        score.note(1, start + 2, 0.62, chord[1], 35)
    }
    score.melody(2, 8, [
        (0, 0.5, 72, 41), (0.75, 0.5, 74, 43), (1.5, 0.8, 76, 46),
        (3, 0.7, 74, 40), (4, 1.0, 79, 48), (6, 1.3, 76, 42),
    ])
    score.melody(2, 32, [
        (0, 0.5, 76, 42), (0.75, 0.5, 74, 39), (1.5, 0.8, 72, 38),
        (3, 0.7, 74, 41), (4, 1.0, 76, 44), (6, 1.3, 74, 39),
    ])
    return Cue(id: "07", title: "ノートの端の落書き", bpm: 82, bars: 12, instruments: [electricPiano, pizzicato, clarinet], notes: score.notes, targetRMS: 0.060)
}

func cue08() -> Cue {
    var score = ScoreBuilder()
    let chords = [
        [43, 50, 55, 59], [42, 50, 54, 57], [40, 47, 52, 55], [48, 55, 59, 64],
        [43, 50, 55, 59], [47, 54, 59, 62], [48, 55, 59, 64], [38, 45, 50, 57],
        [40, 47, 52, 55], [48, 55, 59, 64], [43, 50, 55, 59], [38, 45, 50, 55],
    ]
    for (bar, chord) in chords.enumerated() {
        let start = Double(bar * 4)
        score.arpeggio(0, start, chord: chord.map { $0 + 12 }, pattern: [0, 1, 2, 3, 2, 1, 2, 3], step: 0.5, length: 0.38, velocity: 43)
        score.note(2, start, 1.8, chord[0] - 12, 39)
        score.note(2, start + 2, 1.45, chord[1] - 12, 34)
        if bar % 2 == 0 {
            score.chord(1, start, 7.2, chord.map { $0 + 12 }, 31)
        }
    }
    score.melody(2, 8, [
        (0, 0.8, 71, 44), (1, 0.8, 74, 48), (2, 1.5, 76, 51),
        (4, 0.8, 74, 46), (5, 0.8, 71, 42), (6, 1.35, 69, 40),
    ])
    score.melody(2, 24, [
        (0, 0.8, 74, 46), (1, 0.8, 76, 49), (2, 1.5, 79, 54),
        (4, 0.8, 78, 49), (5, 0.8, 79, 52), (6, 1.4, 83, 56),
    ])
    score.melody(2, 40, [
        (0, 0.8, 79, 48), (1, 0.8, 76, 44), (2, 1.5, 74, 42),
        (4, 0.8, 71, 39), (5, 1.4, 69, 37),
    ])
    return Cue(id: "08", title: "夏空へ", bpm: 78, bars: 12, instruments: [piano, strings, flute], notes: score.notes, targetRMS: 0.066)
}

struct ScheduledEvent {
    let frame: Int64
    let voice: Int
    let midi: UInt8
    let velocity: UInt8
    let isNoteOn: Bool
}

func writePCM(left: [Float], right: [Float], to url: URL) throws {
    guard left.count == right.count,
          let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 2, interleaved: false)
    else {
        throw NSError(domain: "BGMRenderer", code: 10, userInfo: [NSLocalizedDescriptionKey: "PCMフォーマットを作成できません"])
    }
    try? FileManager.default.removeItem(at: url)
    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    var cursor = 0
    while cursor < left.count {
        let count = min(4_096, left.count - cursor)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)),
              let channels = buffer.floatChannelData
        else {
            throw NSError(domain: "BGMRenderer", code: 11, userInfo: [NSLocalizedDescriptionKey: "PCMバッファを作成できません"])
        }
        buffer.frameLength = AVAudioFrameCount(count)
        for index in 0..<count {
            channels[0][index] = left[cursor + index]
            channels[1][index] = right[cursor + index]
        }
        try file.write(from: buffer)
        cursor += count
    }
}

func convertToM4A(wavURL: URL, m4aURL: URL) throws {
    try? FileManager.default.removeItem(at: m4aURL)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
    process.arguments = ["-f", "m4af", "-d", "aac", "-b", "160000", wavURL.path, m4aURL.path]
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw NSError(domain: "BGMRenderer", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "afconvertに失敗しました"])
    }
}

func render(_ cue: Cue, outputDirectory: URL) throws {
    let engine = AVAudioEngine()
    let musicMixer = AVAudioMixerNode()
    let equalizer = AVAudioUnitEQ(numberOfBands: 3)
    let reverb = AVAudioUnitReverb()
    engine.attach(musicMixer)
    engine.attach(equalizer)
    engine.attach(reverb)

    equalizer.bands[0].filterType = .lowShelf
    equalizer.bands[0].frequency = 150
    equalizer.bands[0].gain = -2.0
    equalizer.bands[0].bypass = false
    equalizer.bands[1].filterType = .parametric
    equalizer.bands[1].frequency = 2_500
    equalizer.bands[1].bandwidth = 1.2
    equalizer.bands[1].gain = -1.2
    equalizer.bands[1].bypass = false
    equalizer.bands[2].filterType = .highShelf
    equalizer.bands[2].frequency = 7_000
    equalizer.bands[2].gain = -2.3
    equalizer.bands[2].bypass = false
    reverb.loadFactoryPreset(.mediumRoom)
    reverb.wetDryMix = 16

    var samplers: [AVAudioUnitSampler] = []
    for instrument in cue.instruments {
        let sampler = AVAudioUnitSampler()
        let voiceMixer = AVAudioMixerNode()
        engine.attach(sampler)
        engine.attach(voiceMixer)
        try sampler.loadSoundBankInstrument(
            at: soundBankURL,
            program: instrument.program,
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB: UInt8(kAUSampler_DefaultBankLSB)
        )
        voiceMixer.volume = instrument.volume
        voiceMixer.pan = instrument.pan
        engine.connect(sampler, to: voiceMixer, format: nil)
        engine.connect(voiceMixer, to: musicMixer, format: nil)
        samplers.append(sampler)
    }

    guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
        throw NSError(domain: "BGMRenderer", code: 12, userInfo: [NSLocalizedDescriptionKey: "レンダリングフォーマットを作成できません"])
    }
    engine.connect(musicMixer, to: equalizer, format: format)
    engine.connect(equalizer, to: reverb, format: format)
    engine.connect(reverb, to: engine.mainMixerNode, format: format)
    engine.mainMixerNode.outputVolume = 0.78

    try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: maxRenderFrames)
    engine.prepare()
    try engine.start()

    let cycleFrames = Int64((cue.duration * sampleRate).rounded())
    let outputStart = cycleFrames
    let outputEnd = cycleFrames * 2
    var events: [ScheduledEvent] = []
    for repetition in 0..<3 {
        let cycleStart = Int64(repetition) * cycleFrames
        let cycleEnd = cycleStart + cycleFrames
        for note in cue.notes {
            let start = cycleStart + Int64((note.startBeat * cue.secondsPerBeat * sampleRate).rounded())
            let rawEnd = start + Int64((note.durationBeats * cue.secondsPerBeat * sampleRate).rounded())
            let end = min(rawEnd, cycleEnd - 1)
            events.append(ScheduledEvent(frame: start, voice: note.voice, midi: note.midi, velocity: note.velocity, isNoteOn: true))
            events.append(ScheduledEvent(frame: end, voice: note.voice, midi: note.midi, velocity: 0, isNoteOn: false))
        }
    }
    events.sort {
        if $0.frame == $1.frame {
            return !$0.isNoteOn && $1.isNoteOn
        }
        return $0.frame < $1.frame
    }

    guard let renderBuffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: maxRenderFrames) else {
        throw NSError(domain: "BGMRenderer", code: 13, userInfo: [NSLocalizedDescriptionKey: "レンダリングバッファを作成できません"])
    }

    var left: [Float] = []
    var right: [Float] = []
    left.reserveCapacity(Int(cycleFrames))
    right.reserveCapacity(Int(cycleFrames))
    var eventIndex = 0
    var currentFrame: Int64 = 0

    while currentFrame < outputEnd {
        while eventIndex < events.count && events[eventIndex].frame <= currentFrame {
            let event = events[eventIndex]
            if event.isNoteOn {
                samplers[event.voice].startNote(event.midi, withVelocity: event.velocity, onChannel: 0)
            } else {
                samplers[event.voice].stopNote(event.midi, onChannel: 0)
            }
            eventIndex += 1
        }

        var frames = Int64(maxRenderFrames)
        if eventIndex < events.count {
            frames = min(frames, max(1, events[eventIndex].frame - currentFrame))
        }
        if currentFrame < outputStart {
            frames = min(frames, outputStart - currentFrame)
        }
        frames = min(frames, outputEnd - currentFrame)

        let status = try engine.renderOffline(AVAudioFrameCount(frames), to: renderBuffer)
        switch status {
        case .success:
            if currentFrame >= outputStart, let channels = renderBuffer.floatChannelData {
                let count = Int(renderBuffer.frameLength)
                for index in 0..<count {
                    left.append(channels[0][index])
                    right.append(channels[1][index])
                }
            }
            currentFrame += Int64(renderBuffer.frameLength)
        case .cannotDoInCurrentContext:
            continue
        case .insufficientDataFromInputNode:
            currentFrame += frames
            if currentFrame > outputStart {
                left.append(contentsOf: repeatElement(0, count: Int(frames)))
                right.append(contentsOf: repeatElement(0, count: Int(frames)))
            }
        case .error:
            throw NSError(domain: "BGMRenderer", code: 14, userInfo: [NSLocalizedDescriptionKey: "オフラインレンダリングに失敗しました"])
        @unknown default:
            throw NSError(domain: "BGMRenderer", code: 15, userInfo: [NSLocalizedDescriptionKey: "未知のレンダリング状態です"])
        }
    }
    engine.stop()
    engine.disableManualRenderingMode()

    let frameCount = min(left.count, right.count)
    guard frameCount > 0 else {
        throw NSError(domain: "BGMRenderer", code: 16, userInfo: [NSLocalizedDescriptionKey: "音声が生成されませんでした"])
    }
    var sumSquares: Double = 0
    var peak: Float = 0
    for index in 0..<frameCount {
        sumSquares += Double(left[index] * left[index] + right[index] * right[index])
        peak = max(peak, abs(left[index]), abs(right[index]))
    }
    let rms = Float(sqrt(sumSquares / Double(frameCount * 2)))
    let rmsScale = cue.targetRMS / max(rms, 0.000_001)
    let peakScale: Float = 0.90 / max(peak, 0.000_001)
    let scale = min(rmsScale, peakScale)
    let finalRMS = rms * scale
    let finalPeak = peak * scale
    for index in 0..<frameCount {
        left[index] *= scale
        right[index] *= scale
    }

    let wavURL = outputDirectory.appendingPathComponent("heroine-\(cue.id).wav")
    let m4aURL = outputDirectory.appendingPathComponent("heroine-\(cue.id).m4a")
    try writePCM(left: left, right: right, to: wavURL)
    try convertToM4A(wavURL: wavURL, m4aURL: m4aURL)
    try? FileManager.default.removeItem(at: wavURL)

    let attributes = try FileManager.default.attributesOfItem(atPath: m4aURL.path)
    let bytes = (attributes[.size] as? NSNumber)?.intValue ?? 0
    print(String(format: "rendered %@  %-18@  %5.1fs  rms %.3f  peak %.3f  %.0fKB", cue.id, cue.title as NSString, cue.duration, finalRMS, finalPeak, Double(bytes) / 1024.0))
}

func main() throws {
    let scriptURL = URL(fileURLWithPath: #filePath)
    let projectRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
    var outputDirectory = projectRoot.appendingPathComponent("assets/bgm", isDirectory: true)
    var requestedIDs: Set<String> = []
    var index = 1
    let arguments = CommandLine.arguments
    while index < arguments.count {
        switch arguments[index] {
        case "--output":
            index += 1
            guard index < arguments.count else { throw NSError(domain: "BGMRenderer", code: 20) }
            outputDirectory = URL(fileURLWithPath: arguments[index], relativeTo: projectRoot).standardizedFileURL
        case "--only":
            index += 1
            while index < arguments.count && !arguments[index].hasPrefix("--") {
                requestedIDs.insert(arguments[index])
                index += 1
            }
            continue
        default:
            break
        }
        index += 1
    }

    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    let cues = [cue01(), cue02(), cue03(), cue04(), cue05(), cue06(), cue07(), cue08()]
    let targets = requestedIDs.isEmpty ? cues : cues.filter { requestedIDs.contains($0.id) }
    guard !targets.isEmpty else {
        throw NSError(domain: "BGMRenderer", code: 21, userInfo: [NSLocalizedDescriptionKey: "対象曲がありません"])
    }
    print("output: \(outputDirectory.path)")
    for cue in targets {
        try render(cue, outputDirectory: outputDirectory)
    }
}

do {
    try main()
} catch {
    fputs("BGM render failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
