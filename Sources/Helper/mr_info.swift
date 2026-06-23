import Foundation

let h = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY)!

typealias GetInfo = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
typealias GetPlaying = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
typealias Register = @convention(c) (DispatchQueue) -> Void
typealias GetPID = @convention(c) (DispatchQueue, @escaping (Int32) -> Void) -> Void

let getInfo = unsafeBitCast(dlsym(h, "MRMediaRemoteGetNowPlayingInfo"), to: GetInfo.self)
let getPlaying = unsafeBitCast(dlsym(h, "MRMediaRemoteGetNowPlayingApplicationIsPlaying"), to: GetPlaying.self)
let register = unsafeBitCast(dlsym(h, "MRMediaRemoteRegisterForNowPlayingNotifications"), to: Register.self)
let getPID = unsafeBitCast(dlsym(h, "MRMediaRemoteGetNowPlayingApplicationPID"), to: GetPID.self)

register(.main)

getPID(.main) { pid in
    getPlaying(.main) { playing in
        getInfo(.main) { info in
            var output: [String: Any] = ["playing": playing, "pid": pid]
            output["title"] = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
            output["artist"] = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
            if let data = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                output["artwork"] = data.base64EncodedString()
            }
            if let json = try? JSONSerialization.data(withJSONObject: output),
               let str = String(data: json, encoding: .utf8) {
                print(str)
            }
            exit(0)
        }
    }
}

RunLoop.main.run(until: Date().addingTimeInterval(3))
