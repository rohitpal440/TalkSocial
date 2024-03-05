

import Foundation

final class CacheItem {
    var data: Data
    var aliveTill: Date?
    
    init(data: Data, aliveTill: Date?) {
        self.data = data
        self.aliveTill = aliveTill
    }
}
