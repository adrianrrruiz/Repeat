import SwiftUI
import AVFoundation

@MainActor final class FocusSounds {
    static let shared = FocusSounds()
    private var player:AVAudioPlayer?
    private var activeHabit:String?
    static let choices = [("none","Silencio"),("white","Ruido blanco"),("soft","Ruido suave"),("waves","Olas")]
    func start(habitID:String) {
        stop(); activeHabit = habitID
        let choice = UserDefaults.standard.string(forKey:"repeat.focusSound."+habitID) ?? "none"
        guard choice != "none" else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient,options:[.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let url = FileManager.default.temporaryDirectory.appending(path:"repeat-ambient-\(choice).wav")
            if !FileManager.default.fileExists(atPath:url.path) { try soundData(choice).write(to:url,options:.atomic) }
            player = try AVAudioPlayer(contentsOf:url); player?.numberOfLoops = -1; player?.volume = 0.22; player?.play()
        } catch { player = nil }
    }
    func change(habitID:String,choice:String) { UserDefaults.standard.set(choice,forKey:"repeat.focusSound."+habitID); if activeHabit == habitID { start(habitID:habitID) } }
    func stop() { player?.stop(); player = nil; activeHabit = nil; try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation) }
    private func soundData(_ kind:String) -> Data {
        let rate = 22050,count = rate*12; var pcm = Data(capacity:count*2); var seed:UInt32 = 7321; var filtered:Double = 0
        for i in 0..<count {
            seed = 1664525 &* seed &+ 1013904223
            let noise = Double(seed)/Double(UInt32.max)*2-1
            filtered = 0.96*filtered+0.04*noise
            let wave = 0.35+0.65*(sin(Double(i)/Double(rate)*2*Double.pi/12-Double.pi/2)+1)/2
            let sample = kind == "white" ? noise*0.30 : filtered*(kind == "waves" ? wave : 1)*1.4
            var value = Int16(max(-1,min(1,sample))*Double(Int16.max)).littleEndian
            withUnsafeBytes(of:&value) { pcm.append(contentsOf:$0) }
        }
        var data = Data("RIFF".utf8)
        func append<T:FixedWidthInteger>(_ number:T) { var value = number.littleEndian; withUnsafeBytes(of:&value) { data.append(contentsOf:$0) } }
        append(UInt32(36+pcm.count)); data.append(Data("WAVEfmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1)); append(UInt32(rate)); append(UInt32(rate*2)); append(UInt16(2)); append(UInt16(16)); data.append(Data("data".utf8)); append(UInt32(pcm.count)); data.append(pcm); return data
    }
}
struct FocusSoundPicker:View {
    var habitID:String; var color:Color
    @Environment(\.dismiss) private var dismiss
    @State private var selected = "none"
    var body:some View { NavigationStack { List { ForEach(FocusSounds.choices,id:\.0) { key,title in Button { selected = key; FocusSounds.shared.change(habitID:habitID,choice:key) } label:{HStack { Label(title,systemImage:key == "none" ? "speaker.slash" : "waveform"); Spacer(); if selected == key { Image(systemName:"checkmark") } }} } } .navigationTitle("Sonido de enfoque").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement:.confirmationAction) { Button("Listo") { dismiss() } } }.tint(color).onAppear { selected = UserDefaults.standard.string(forKey:"repeat.focusSound."+habitID) ?? "none" } } }
}
