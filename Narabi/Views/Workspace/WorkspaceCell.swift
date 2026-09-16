import SwiftUI
import UIKit

final class WorkspaceCell: UICollectionViewCell {
    static func thumbnailKey(for item: ProjectPage, maximumPixel: Int) -> String {
        let crop = item.cropInsets
        return [
            item.id.uuidString, String(item.originalData.count), String(item.renderedData.count),
            String(item.editBaseData?.count ?? 0), String(crop.left), String(crop.right), String(crop.top),
            String(crop.bottom), item.colorMode.rawValue, item.outputStyle.rawValue,
            String(item.a4WidthRatio), String(item.placementOffsetX), String(item.placementOffsetY),
            String(item.placementRotationDegrees), item.paperPreset.rawValue, item.paperOrientation.rawValue,
            String(item.customPaperWidthMM), String(item.customPaperHeightMM), item.paperUnit.rawValue,
            String(maximumPixel),
        ].joined(separator: "|")
    }

    static let reuseID = "WorkspaceCell"

    private var representedPageID: UUID?
    private var representedThumbnailKey: String?
    private let imageView = UIImageView()
    private let pageBadge = UILabel()
    private let selectionBadge = UILabel()
    private let hiddenBadge = UIImageView(image: UIImage(systemName: "eye.slash.fill"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 8
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.separator.cgColor
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 0.14
        contentView.layer.shadowRadius = 2
        contentView.layer.shadowOffset = CGSize(width: 0, height: 1)
        contentView.clipsToBounds = true

        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)

        [pageBadge, selectionBadge].forEach {
            $0.textAlignment = .center
            $0.textColor = .white
            $0.font = .preferredFont(forTextStyle: .caption1)
            $0.layer.cornerRadius = 13.5
            $0.clipsToBounds = true
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        hiddenBadge.tintColor = .white
        hiddenBadge.contentMode = .center
        hiddenBadge.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        hiddenBadge.layer.cornerRadius = 9
        hiddenBadge.clipsToBounds = true
        hiddenBadge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hiddenBadge)

        pageBadge.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        selectionBadge.backgroundColor = (UIColor(named: "AccentColor") ?? .systemGray).withAlphaComponent(
            0.95)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            pageBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            pageBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            pageBadge.widthAnchor.constraint(equalToConstant: 27),
            pageBadge.heightAnchor.constraint(equalToConstant: 27),
            selectionBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            selectionBadge.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            selectionBadge.widthAnchor.constraint(equalToConstant: 27),
            selectionBadge.heightAnchor.constraint(equalToConstant: 27),
            hiddenBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 5),
            hiddenBadge.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            hiddenBadge.widthAnchor.constraint(equalToConstant: 22),
            hiddenBadge.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        representedPageID = nil
        representedThumbnailKey = nil
        imageView.image = nil
        transform = .identity
        contentView.alpha = 1
    }

    func setLongPressActive(_ active: Bool) {
        UIView.animate(withDuration: 0.10) {
            self.transform =
                active
                ? CGAffineTransform(scaleX: 0.97, y: 0.97)
                : .identity
            self.contentView.layer.borderWidth = active ? 2 : 0
            self.contentView.layer.borderColor =
                active
                ? (UIColor(named: "AccentColor") ?? .systemGray).cgColor
                : UIColor.clear.cgColor
            self.contentView.alpha = active ? 0.88 : 1
        }
    }

    func configure(
        item: ProjectPage,
        pageNumber: Int?,
        selectionNumber: Int?
    ) {
        representedPageID = item.id
        let maximumPixel = 420
        let key = Self.thumbnailKey(for: item, maximumPixel: maximumPixel)
        representedThumbnailKey = key
        imageView.image = WorkspaceThumbnailLoader.shared.cachedImage(for: key)
        updateMetadata(item: item, pageNumber: pageNumber, selectionNumber: selectionNumber)
        guard imageView.image == nil else { return }
        WorkspaceThumbnailLoader.shared.request(page: item, key: key, maximumPixel: CGFloat(maximumPixel)) {
            [weak self] image in
            guard let self, representedPageID == item.id, representedThumbnailKey == key else { return }
            imageView.image = image
        }
    }

    func updateMetadata(item: ProjectPage, pageNumber: Int?, selectionNumber: Int?) {
        // Reorder commits change labels and selection state, not image content.
        imageView.alpha = item.isHiddenFromPreviewAndOutput ? 0.58 : 1.0
        hiddenBadge.isHidden = !item.isHiddenFromPreviewAndOutput
        accessibilityValue = item.isHiddenFromPreviewAndOutput ? L10n.text("page.hide", "見えなくする") : nil
        pageBadge.isHidden = pageNumber == nil
        pageBadge.text = pageNumber.map(String.init)
        selectionBadge.isHidden = selectionNumber == nil
        selectionBadge.text = selectionNumber.map(String.init)
        contentView.layer.borderWidth = selectionNumber == nil ? 0 : 3
        contentView.layer.borderColor =
            selectionNumber == nil
            ? UIColor.clear.cgColor : (UIColor(named: "AccentColor") ?? .systemBlue).cgColor
    }
}
