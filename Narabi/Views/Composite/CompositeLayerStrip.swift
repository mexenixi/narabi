import AVFoundation
import StoreKit
import SwiftUI

struct CompositeLayerStrip: UIViewRepresentable {
    @Binding var pages: [ProjectPage]
    @Binding var selectedID: UUID?
    @Binding var actionPage: ProjectPage?
    @Binding var zoomPage: ProjectPage?
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 84, height: 112)
        layout.minimumLineSpacing = 8
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.register(CompositeStripCell.self, forCellWithReuseIdentifier: "c")
        view.dataSource = context.coordinator
        view.delegate = context.coordinator
        context.coordinator.collection = view
        let press = UILongPressGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.press(_:)))
        press.minimumPressDuration = 0.18
        press.delegate = context.coordinator
        view.addGestureRecognizer(press)
        return view
    }
    func updateUIView(_ uiView: UICollectionView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.refreshIfNeeded()
    }
    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate,
        UIGestureRecognizerDelegate
    {
        var parent: CompositeLayerStrip
        weak var collection: UICollectionView?
        var ids: [UUID] = []
        var visualSignatures: [UUID: String] = [:]
        var lastSelectedID: UUID?
        var placementRefreshWork: DispatchWorkItem?
        var start: Int?
        var proposed: Int?
        var startPoint: CGPoint?
        var dragged = false
        var leftSafe = false
        var edgeUnlocked = false
        var snapshot: UIView?
        var snapshotTouchOffset = CGPoint.zero
        var display: CADisplayLink?
        var velocity: CGFloat = 0
        init(_ p: CompositeLayerStrip) { parent = p }
        func refreshIfNeeded() {
            guard let collection else { return }
            let newIDs = parent.pages.map(\.id)
            if newIDs != ids {
                ids = newIDs
                visualSignatures = Dictionary(
                    uniqueKeysWithValues: parent.pages.map { ($0.id, visualSignature($0)) })
                lastSelectedID = parent.selectedID
                collection.reloadData()
                return
            }

            var indexesToRefresh = Set<Int>()
            for (index, page) in parent.pages.enumerated() {
                let signature = visualSignature(page)
                if visualSignatures[page.id] != signature {
                    visualSignatures[page.id] = signature
                    indexesToRefresh.insert(index)
                }
            }
            if lastSelectedID != parent.selectedID {
                if let old = lastSelectedID, let index = parent.pages.firstIndex(where: { $0.id == old }) {
                    indexesToRefresh.insert(index)
                }
                if let current = parent.selectedID,
                    let index = parent.pages.firstIndex(where: { $0.id == current })
                {
                    indexesToRefresh.insert(index)
                }
                lastSelectedID = parent.selectedID
            }
            for index in indexesToRefresh where parent.pages.indices.contains(index) {
                let indexPath = IndexPath(item: index, section: 0)
                if let cell = collection.cellForItem(at: indexPath) as? CompositeStripCell {
                    configure(cell, index)
                }
            }

            placementRefreshWork?.cancel()
            guard let selected = parent.selectedID,
                let selectedIndex = parent.pages.firstIndex(where: { $0.id == selected })
            else { return }
            let work = DispatchWorkItem { [weak self, weak collection] in
                guard let self, let collection, self.parent.pages.indices.contains(selectedIndex) else {
                    return
                }
                let indexPath = IndexPath(item: selectedIndex, section: 0)
                if let cell = collection.cellForItem(at: indexPath) as? CompositeStripCell {
                    self.configure(cell, selectedIndex)
                }
            }
            placementRefreshWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
        }
        private func visualSignature(_ page: ProjectPage) -> String {
            [
                page.id.uuidString,
                String(page.isHiddenFromPreviewAndOutput),
                String(page.cropInsets.left),
                String(page.cropInsets.right),
                String(page.cropInsets.top),
                String(page.cropInsets.bottom),
                page.colorMode.rawValue,
                page.outputStyle.rawValue,
                page.paperPreset.rawValue,
                page.paperOrientation.rawValue,
                String(page.customPaperWidthMM),
                String(page.customPaperHeightMM),
                page.paperUnit.rawValue,
                String(page.renderedData.count),
                String(page.editBaseData?.count ?? 0),
            ].joined(separator: "|")
        }
        func collectionView(_ c: UICollectionView, numberOfItemsInSection s: Int) -> Int {
            parent.pages.count
        }
        func collectionView(
            _ collectionView: UICollectionView,
            cellForItemAt indexPath: IndexPath
        ) -> UICollectionViewCell {
            guard
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: "c",
                    for: indexPath
                ) as? CompositeStripCell
            else {
                assertionFailure("CompositeStripCell registration is inconsistent.")
                return UICollectionViewCell()
            }
            configure(cell, indexPath.item)
            return cell
        }
        func configure(_ c: CompositeStripCell, _ i: Int) {
            guard parent.pages.indices.contains(i) else { return }
            let p = parent.pages[i]
            c.set(
                ExportService.workspaceThumbnail(for: p), selected: p.id == parent.selectedID,
                hidden: p.isHiddenFromPreviewAndOutput, number: i + 1)
        }
        func collectionView(_ c: UICollectionView, didSelectItemAt ip: IndexPath) {
            parent.selectedID = parent.pages[ip.item].id
        }
        @objc func press(_ g: UILongPressGestureRecognizer) {
            guard let c = collection else { return }
            let point = g.location(in: c)
            switch g.state {
            case .began:
                guard let ip = c.indexPathForItem(at: point) else { return }
                start = ip.item
                proposed = ip.item
                startPoint = point
                dragged = false
                leftSafe = false
                edgeUnlocked = false
                if let cell = c.cellForItem(at: ip), let snap = cell.snapshotView(afterScreenUpdates: true) {
                    snap.frame = cell.frame
                    snap.layer.zPosition = 1000
                    c.addSubview(snap)
                    snapshot = snap
                    snapshotTouchOffset = CGPoint(x: point.x - snap.center.x, y: point.y - snap.center.y)
                }
                parent.selectedID = parent.pages[ip.item].id
            case .changed:
                guard start != nil else { return }
                if let origin = startPoint, hypot(point.x - origin.x, point.y - origin.y) > 8 {
                    dragged = true
                }
                let safe = c.bounds.insetBy(dx: 64, dy: 0)
                if safe.contains(point) { leftSafe = true }
                let edge: CGFloat = 44
                func speed(_ penetration: CGFloat) -> CGFloat {
                    let progress = min(max(penetration / edge, 0), 1)
                    return 2 + 12 * progress * progress
                }
                if leftSafe && point.x < c.contentOffset.x + edge {
                    velocity = -speed(c.contentOffset.x + edge - point.x)
                    startDisplay()
                } else if leftSafe && point.x > c.contentOffset.x + c.bounds.width - edge {
                    velocity = speed(point.x - (c.contentOffset.x + c.bounds.width - edge))
                    startDisplay()
                } else {
                    stopDisplay()
                }
                snapshot?.center = CGPoint(
                    x: point.x - snapshotTouchOffset.x, y: point.y - snapshotTouchOffset.y)
                if let to = c.indexPathForItem(at: point)?.item { proposed = to }
            case .ended:
                stopDisplay()
                snapshot?.removeFromSuperview()
                snapshot = nil
                if dragged, let from = start, let to = proposed, from != to,
                    parent.pages.indices.contains(from)
                {
                    parent.pages = CompositeLayoutPolicy.moving(
                        parent.pages,
                        from: from,
                        to: to
                    )
                } else if !dragged, let i = start, parent.pages.indices.contains(i) {
                    parent.zoomPage = parent.pages[i]
                }
                start = nil
                proposed = nil
                startPoint = nil
            default:
                stopDisplay()
                start = nil
                startPoint = nil
            }
        }
        func startDisplay() {
            if display != nil { return }
            display = CADisplayLink(target: self, selector: #selector(tick))
            display?.add(to: .main, forMode: .common)
        }
        @objc func tick() {
            guard let c = collection else { return }
            let minimum = -c.adjustedContentInset.left
            let maximum = max(minimum, c.contentSize.width - c.bounds.width + c.adjustedContentInset.right)
            let oldOffset = c.contentOffset.x
            let newOffset = min(maximum, max(minimum, oldOffset + velocity))
            c.contentOffset.x = newOffset
            if let snapshot {
                snapshot.center.x += newOffset - oldOffset
            }
        }
        func stopDisplay() {
            display?.invalidate()
            display = nil
            velocity = 0
        }
    }
}
final class CompositeStripCell: UICollectionViewCell {
    let image = UIImageView()
    let badge = UILabel()
    let hiddenBadge = UIImageView(image: UIImage(systemName: "eye.slash.fill"))
    override init(frame: CGRect) {
        super.init(frame: frame)
        image.contentMode = .scaleAspectFit
        [image, badge, hiddenBadge].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        badge.textAlignment = .center
        badge.font = .boldSystemFont(ofSize: 12)
        badge.textColor = .white
        badge.backgroundColor = .systemGray
        badge.layer.cornerRadius = 11
        badge.clipsToBounds = true
        NSLayoutConstraint.activate([
            image.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            image.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            image.topAnchor.constraint(equalTo: contentView.topAnchor),
            image.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            badge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -3),
            badge.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -3),
            badge.widthAnchor.constraint(equalToConstant: 22),
            badge.heightAnchor.constraint(equalToConstant: 22),
            hiddenBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            hiddenBadge.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
        ])
        contentView.layer.cornerRadius = 8
        contentView.clipsToBounds = true
    }
    required init?(coder: NSCoder) {
        fatalError("CompositeStripCell is created programmatically.")
    }
    func set(_ value: UIImage?, selected: Bool, hidden h: Bool, number: Int) {
        image.image = value
        image.alpha = h ? 0.58 : 1
        hiddenBadge.isHidden = !h
        badge.text = "\(number)"
        contentView.layer.borderWidth = selected ? 3 : 1
        contentView.layer.borderColor = (selected ? UIColor.tintColor : UIColor.separator).cgColor
    }
}
