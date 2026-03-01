import Foundation
import Logging

@main
struct Main {
    static func main() async {
        
        let logger = Logger(label:"HWiD")

        let meh = HWiD(logger: logger)
        
        
        for await data in meh.speed {
            print("Found Dataz here! \(data)")
        }
    
    }
}


extension Data {
    var toFloat: Float? {
        guard count >= 4 else { return nil }
        return withUnsafeBytes { $0.load(as: Float.self) }
    }
}
