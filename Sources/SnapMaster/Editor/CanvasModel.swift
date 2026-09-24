import Foundation
import AppKit

enum AnnotationTool: String, CaseIterable, Identifiable {
    case select = "cursorarrow"
    case arrow = "arrow.up.right"
    case rectangle = "rectangle"
    case oval = "circle"
    case stepNumber = "1.circle.fill"
    case text = "textformat"
    case pen = "pencil.tip"
    case pixelate = "checkerboard.rectangle"
    case spotlight = "sun.max"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .select: return "Chọn / Di chuyển"
        case .arrow: return "Mũi tên"
        case .rectangle: return "Hình chữ nhật"
        case .oval: return "Hình tròn / Elip"
        case .stepNumber: return "Số thứ tự (1, 2, 3)"
        case .text: return "Văn bản"
        case .pen: return "Bút vẽ tự do"
        case .pixelate: return "Che mờ / Pixelate"
        case .spotlight: return "Spotlight làm tối"
        }
    }
}

struct AnnotationItem: Identifiable {
    let id = UUID()
    var type: AnnotationTool
    var startPoint: CGPoint
    var endPoint: CGPoint
    var points: [CGPoint] = [] // Dành cho bút vẽ tự do
    var color: NSColor
    var lineWidth: CGFloat
    var text: String = ""
    var stepIndex: Int = 1
    var isFilled: Bool = false
    
    var rect: CGRect {
        let minX = min(startPoint.x, endPoint.x)
        let maxX = max(startPoint.x, endPoint.x)
        let minY = min(startPoint.y, endPoint.y)
        let maxY = max(startPoint.y, endPoint.y)
        return CGRect(x: minX, y: minY, width: max(1, maxX - minX), height: max(1, maxY - minY))
    }
}
