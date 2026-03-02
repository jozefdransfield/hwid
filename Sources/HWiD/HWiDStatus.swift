public enum HWiDStatus : String, Identifiable, CaseIterable {
    case scanning
    case poweredOn
    case poweredOff
    case connected
    case disconnected
    case unauthorized
    case notSupported
    case error
    
    public var id: Self { self }
}
