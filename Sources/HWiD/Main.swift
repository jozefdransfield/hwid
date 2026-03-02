import Foundation
import Logging

@main
struct Main {
    static func main() async {
        
        let logger = Logger(label:"HWiD")

        let hWiD = HWiD(logger: logger)
        
        let task0 = Task {
            for await data in hWiD.status {
                print("Status: \(data)")
            }
        }
        
        let task1 = Task {
            for await data in hWiD.speed {
                print("Found Dataz here! \(data)")
            }
        }
        
        let task2 = Task {
            for await data in hWiD.carId {
                print("Found a car! \(data)")
            }
        }
        
        await task1.value
        await task2.value
    
    }
}

