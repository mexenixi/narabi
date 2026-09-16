import Foundation
import UIKit

nonisolated enum DocumentTextPageRenderer {
    private static let pageSize = CGSize(width: 1240, height: 1754)
    private static let margin: CGFloat = 86

    static func render(title: String, blocks: [String]) -> [UIImage] {
        guard !blocks.isEmpty else { return [] }
        var remaining = blocks
        var images: [UIImage] = []
        var page = 1
        while !remaining.isEmpty {
            var consumed = 0
            let image = UIGraphicsImageRenderer(size: pageSize).image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: pageSize))
                NSString(string: title).draw(
                    in: CGRect(x: margin, y: margin, width: pageSize.width - margin * 2, height: 55),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 34, weight: .semibold),
                        .foregroundColor: UIColor.black,
                    ]
                )
                let style = NSMutableParagraphStyle()
                style.lineSpacing = 7
                style.paragraphSpacing = 8
                style.lineBreakMode = .byWordWrapping
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 25),
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: style,
                ]
                var y: CGFloat = 165
                for block in remaining {
                    let value = NSAttributedString(string: block, attributes: attributes)
                    let bounds = value.boundingRect(
                        with: CGSize(width: 1068, height: CGFloat.greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil
                    )
                    let height = min(ceil(bounds.height) + 22, 1450)
                    if y + height > 1640, consumed > 0 { break }
                    value.draw(in: CGRect(x: margin, y: y, width: 1068, height: height))
                    y += height
                    consumed += 1
                }
                NSString(string: String(page)).draw(
                    at: CGPoint(x: pageSize.width - margin - 30, y: pageSize.height - 67),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 17), .foregroundColor: UIColor.darkGray,
                    ]
                )
            }
            guard consumed > 0 else { break }
            images.append(image)
            remaining.removeFirst(consumed)
            page += 1
        }
        return images
    }
}
