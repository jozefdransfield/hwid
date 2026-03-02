import Foundation

public protocol HWiD {
    var status: AsyncStream<HWiDStatus> { get }
    
    var carId: AsyncStream<Data> { get }
    
    var speed: AsyncStream<Float> { get }
    
    func scan()
}
