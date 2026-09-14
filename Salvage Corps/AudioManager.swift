//
//  AudioManager.swift
//  Salvage Corps
//
//  Sistema centralizado de áudio. Usa AVAudioPlayer.
//  Suporta:
//  - Music tracks (loop, com fade in/out entre tracks)
//  - SFX (one-shot, com pool pra evitar interrupção)
//  - Volume separado pra music e SFX (persistido em UserDefaults)
//  - Mute global (persistido)
//  - Fallback silencioso se arquivo não existe (permite dev sem tracks)
//

import AVFoundation
import Foundation
import Observation

@Observable
final class AudioManager {

    static let shared = AudioManager()

    // MARK: - State

    private var currentMusic: AVAudioPlayer?
    private var currentMusicName: String?
    private var sfxPlayers: [AVAudioPlayer] = []  // pool pra one-shots concorrentes

    var isMuted: Bool {
        didSet {
            UserDefaults.standard.set(isMuted, forKey: "audio.muted")
            currentMusic?.volume = isMuted ? 0 : musicVolume
            print("AudioManager: mute = \(isMuted)")
        }
    }

    /// 0.0 a 1.0
    var musicVolume: Float {
        didSet {
            UserDefaults.standard.set(musicVolume, forKey: "audio.music.volume")
            if !isMuted { currentMusic?.volume = musicVolume }
        }
    }

    /// 0.0 a 1.0
    var sfxVolume: Float {
        didSet {
            UserDefaults.standard.set(sfxVolume, forKey: "audio.sfx.volume")
        }
    }

    private init() {
        self.isMuted = UserDefaults.standard.bool(forKey: "audio.muted")

        let savedMusic = UserDefaults.standard.object(forKey: "audio.music.volume") as? Float
        self.musicVolume = savedMusic ?? 0.6

        let savedSfx = UserDefaults.standard.object(forKey: "audio.sfx.volume") as? Float
        self.sfxVolume = savedSfx ?? 0.8

        configureSession()

        // Diagnóstico automático no boot pra facilitar debug
        diagnose()
    }

    // MARK: - Session

    private func configureSession() {
        do {
            // .playback = toca IGNORANDO o silent switch (importante pra game)
            // Se quiser respeitar silent switch (tipo pra apps que não são games), troque pra .ambient
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]  // não interrompe Spotify etc
            )
            try AVAudioSession.sharedInstance().setActive(true)
            print("AudioManager: sessão configurada com .playback + mixWithOthers")
        } catch {
            print("AudioManager: ERRO configurando session — \(error)")
        }
    }

    // MARK: - Diagnóstico

    /// Lista todos os arquivos de áudio disponíveis no bundle.
    /// Chame isso pra ver EXATAMENTE quais arquivos o app consegue encontrar.
    func diagnose() {
        print("═══════════════════════════════════════════════════")
        print("AudioManager: DIAGNÓSTICO")
        print("═══════════════════════════════════════════════════")

        // Lista arquivos de áudio esperados
        let expectedFiles = [
            AudioTrack.musicMenu,
            AudioTrack.musicCombat,
            AudioTrack.sfxCardPlay,
            AudioTrack.sfxCardDraw,
            AudioTrack.sfxDamageEnemy,
            AudioTrack.sfxDamagePlayer,
            AudioTrack.sfxEnemyDeath,
            AudioTrack.sfxMoralHit,
            AudioTrack.sfxTurnEnd,
            AudioTrack.sfxClick,
            AudioTrack.sfxVictory,
            AudioTrack.sfxDefeat,
        ]

        var foundCount = 0
        for name in expectedFiles {
            if let url = findAudio(name) {
                foundCount += 1
                let ext = url.pathExtension
                print("  ✓ \(name).\(ext)")
            } else {
                print("  ✗ \(name) — NÃO ENCONTRADO no bundle")
            }
        }

        print("---")
        print("Total: \(foundCount)/\(expectedFiles.count) arquivos disponíveis")

        // Categoria da sessão + silent-switch relevance
        let session = AVAudioSession.sharedInstance()
        print("Sessão: category=\(session.category.rawValue), mode=\(session.mode.rawValue)")
        print("Volume output atual: \(session.outputVolume) (0-1)")

        // Lista TODOS os arquivos de áudio no bundle (varredura direta)
        print("---")
        print("Arquivos de áudio no bundle (varredura):")
        listAllBundleAudio()
        print("═══════════════════════════════════════════════════")
    }

    private func listAllBundleAudio() {
        guard let resourcePath = Bundle.main.resourcePath else {
            print("  (Bundle.main.resourcePath = nil?)")
            return
        }
        let fm = FileManager.default
        let audioExtensions = ["mp3", "m4a", "wav", "caf", "aiff"]
        do {
            let allFiles = try fm.subpathsOfDirectory(atPath: resourcePath)
            let audioFiles = allFiles.filter { path in
                audioExtensions.contains((path as NSString).pathExtension.lowercased())
            }
            if audioFiles.isEmpty {
                print("  (nenhum arquivo de áudio encontrado no bundle)")
            } else {
                for file in audioFiles.sorted() {
                    print("  · \(file)")
                }
            }
        } catch {
            print("  Erro listando bundle: \(error)")
        }
    }

    // MARK: - Music

    /// Toca uma faixa de música. Se já está tocando a mesma, no-op.
    /// Se está tocando outra, faz cross-fade.
    func playMusic(_ name: String, loop: Bool = true, fadeIn: Bool = true) {
        print("AudioManager: playMusic('\(name)') chamado")

        // Se já é essa música E tá tocando, não reinicia
        if currentMusicName == name, currentMusic?.isPlaying == true {
            print("  → já está tocando essa música, no-op")
            return
        }

        // Se tá tocando outra, fade out antes de trocar
        if let current = currentMusic, current.isPlaying {
            print("  → fade out da música anterior antes de trocar")
            fadeOut(current) { [weak self] in
                self?.startMusic(name, loop: loop, fadeIn: fadeIn)
            }
        } else {
            startMusic(name, loop: loop, fadeIn: fadeIn)
        }
    }

    private func startMusic(_ name: String, loop: Bool, fadeIn: Bool) {
        guard let url = findAudio(name) else {
            print("  ⚠️ música '\(name)' NÃO ENCONTRADA no bundle (modo silencioso)")
            currentMusicName = nil
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = loop ? -1 : 0
            player.volume = fadeIn ? 0 : (isMuted ? 0 : musicVolume)
            player.prepareToPlay()
            let didStart = player.play()

            currentMusic = player
            currentMusicName = name

            print("  ✓ tocando '\(name).\(url.pathExtension)' (loop=\(loop), started=\(didStart), volume=\(player.volume))")

            if fadeIn && !isMuted {
                fade(player, from: 0, to: musicVolume, duration: 1.5)
            }
        } catch {
            print("  ✗ erro criando player pra '\(name)' — \(error)")
        }
    }

    func stopMusic(fadeOut: Bool = true) {
        guard let current = currentMusic else { return }
        if fadeOut {
            self.fadeOut(current) { [weak self] in
                self?.currentMusic = nil
                self?.currentMusicName = nil
            }
        } else {
            current.stop()
            currentMusic = nil
            currentMusicName = nil
        }
    }

    // MARK: - SFX

    /// Toca um SFX one-shot. Não interrompe outros SFX rodando.
    func playSFX(_ name: String) {
        guard !isMuted else { return }
        guard let url = findAudio(name) else {
            // Silencioso pra não spamar console em SFX ausente
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = sfxVolume
            player.prepareToPlay()
            player.play()

            // Adiciona ao pool. Cleanup de players que já terminaram.
            sfxPlayers.append(player)
            sfxPlayers.removeAll { !$0.isPlaying }
        } catch {
            print("AudioManager: erro no SFX '\(name)' — \(error)")
        }
    }

    // MARK: - Helpers

    private func findAudio(_ name: String) -> URL? {
        let extensions = ["mp3", "m4a", "wav", "caf", "aiff"]
        // Tenta root primeiro (compat), depois pastas comuns onde áudio pode viver.
        // Xcode: folder reference (pasta azul) mantém subdiretório no bundle,
        // enquanto group (pasta amarela) fica flat.
        let subdirectories: [String?] = [nil, "Audio", "audio", "Sounds"]

        for subdir in subdirectories {
            for ext in extensions {
                if let url = Bundle.main.url(
                    forResource: name,
                    withExtension: ext,
                    subdirectory: subdir
                ) {
                    return url
                }
            }
        }
        return nil
    }

    private func fade(
        _ player: AVAudioPlayer,
        from startVolume: Float,
        to endVolume: Float,
        duration: TimeInterval
    ) {
        let steps = 30
        let stepDuration = duration / Double(steps)
        let volumeStep = (endVolume - startVolume) / Float(steps)

        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) { [weak player] in
                guard let player else { return }
                player.volume = startVolume + volumeStep * Float(i)
            }
        }
    }

    private func fadeOut(
        _ player: AVAudioPlayer,
        duration: TimeInterval = 0.8,
        completion: @escaping () -> Void
    ) {
        let startVolume = player.volume
        let steps = 20
        let stepDuration = duration / Double(steps)
        let volumeStep = startVolume / Float(steps)

        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) { [weak player] in
                guard let player else { return }
                player.volume = max(0, startVolume - volumeStep * Float(i))
                if i == steps {
                    player.stop()
                    completion()
                }
            }
        }
    }
}
