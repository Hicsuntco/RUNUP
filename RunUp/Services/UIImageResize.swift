import UIKit

extension UIImage {
    /// Downscales so the longer side is at most `maxDimension`, preserving aspect ratio — never
    /// upscales a smaller source image. Used before storing a picked profile photo: the picker
    /// hands back full camera-resolution images, and only a thumbnail is ever actually displayed.
    func resized(maxDimension: CGFloat) -> UIImage {
        let longerSide = max(size.width, size.height)
        guard longerSide > maxDimension else { return self }
        let scale = maxDimension / longerSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
