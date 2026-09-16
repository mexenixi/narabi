import SwiftUI
import UIKit

struct ProjectBrowserBoard: UIViewControllerRepresentable {
    let items: [ProjectBrowserItem]
    let selection: [UUID]
    let selectionMode: Bool
    let searchMode: Bool
    let folderID: UUID?
    let tap: (ProjectBrowserItem) -> Void
    let menu: (ProjectBrowserItem) -> Void
    let reorder: ([String], String, Bool) -> Void
    let enterFolder: (UUID, [String]) -> Void
    let returnToRoot: ([String]) -> Void

    func makeUIViewController(context: Context) -> ProjectBrowserController {
        let controller = ProjectBrowserController()
        controller.events = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: ProjectBrowserController, context: Context) {
        context.coordinator.parent = self
        controller.apply(
            items: items, selection: selection, selectionMode: selectionMode, searchMode: searchMode,
            insideFolder: folderID != nil)
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: ProjectBrowserEvents {
        var parent: ProjectBrowserBoard
        init(_ parent: ProjectBrowserBoard) { self.parent = parent }
        func tap(_ item: ProjectBrowserItem) { parent.tap(item) }
        func menu(_ item: ProjectBrowserItem) { parent.menu(item) }
        func reorder(_ tokens: [String], _ target: String, _ after: Bool) {
            parent.reorder(tokens, target, after)
        }
        func enter(_ id: UUID, _ tokens: [String]) { parent.enterFolder(id, tokens) }
        func root(_ tokens: [String]) { parent.returnToRoot(tokens) }
    }
}

protocol ProjectBrowserEvents: AnyObject {
    func tap(_ item: ProjectBrowserItem)
    func menu(_ item: ProjectBrowserItem)
    func reorder(_ tokens: [String], _ target: String, _ after: Bool)
    func enter(_ folderID: UUID, _ tokens: [String])
    func root(_ tokens: [String])
}

final class ProjectBrowserController: UIViewController, UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate
{
    weak var events: ProjectBrowserEvents?
    private var items: [ProjectBrowserItem] = []
    private var selection: [UUID] = []
    private var selectionMode = false
    private var searchMode = false
    private var insideFolder = false
    private let layout = UICollectionViewFlowLayout()
    private lazy var collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
    private var candidateIndex: Int?
    private var dragTokens: [String] = []
    private var startPoint = CGPoint.zero
    private var lastPoint = CGPoint.zero
    private var dragging = false
    private var dragView: UIView?
    private var hoverKey: String?
    private var hoverTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        layout.minimumLineSpacing = 0
        collection.backgroundColor = .clear
        collection.dataSource = self
        collection.delegate = self
        collection.register(ProjectBrowserCell.self, forCellWithReuseIdentifier: "cell")
        collection.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collection)
        NSLayoutConstraint.activate([
            collection.topAnchor.constraint(equalTo: view.topAnchor),
            collection.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collection.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collection.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(press(_:)))
        gesture.minimumPressDuration = 0.18
        gesture.allowableMovement = 1000
        gesture.delegate = self
        collection.addGestureRecognizer(gesture)
    }

    func apply(
        items: [ProjectBrowserItem], selection: [UUID], selectionMode: Bool, searchMode: Bool,
        insideFolder: Bool
    ) {
        self.items = items
        self.selection = selection
        self.selectionMode = selectionMode
        self.searchMode = searchMode
        self.insideFolder = insideFolder
        collection.reloadData()
        if dragging { updateDragPosition(lastPoint) }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath)
        -> UICollectionViewCell
    {
        guard
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "cell",
                for: indexPath
            ) as? ProjectBrowserCell
        else {
            assertionFailure("ProjectBrowserCell registration is inconsistent.")
            return UICollectionViewCell()
        }
        let item = items[indexPath.item]
        cell.configure(item: item, selectionNumber: selection.firstIndex(of: item.id).map { $0 + 1 })
        return cell
    }
    func collectionView(
        _ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize { CGSize(width: collectionView.bounds.width, height: 72) }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if items.indices.contains(indexPath.item) { events?.tap(items[indexPath.item]) }
    }

    @objc private func press(_ gesture: UILongPressGestureRecognizer) {
        let local = gesture.location(in: collection)
        let point = gesture.location(in: view)
        switch gesture.state {
        case .began:
            guard !searchMode, let indexPath = collection.indexPathForItem(at: local) else { return }
            candidateIndex = indexPath.item
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            startPoint = point
            lastPoint = point
            dragging = false
            dragTokens = []
        case .changed:
            lastPoint = point
            guard let index = candidateIndex, items.indices.contains(index) else { return }
            if !dragging && hypot(point.x - startPoint.x, point.y - startPoint.y) >= 8 {
                beginDrag(index: index, point: point)
            }
            guard dragging else { return }
            updateDragPosition(point)
            updateHover(point)
        case .ended:
            if dragging {
                finishDrag(point)
            } else if let index = candidateIndex, items.indices.contains(index) {
                events?.menu(items[index])
            }
            clearDrag()
        case .cancelled, .failed:
            clearDrag()
        default: break
        }
    }

    private func beginDrag(index: Int, point: CGPoint) {
        let item = items[index]
        dragTokens = ProjectBrowserDragPolicy.dragTokens(
            itemID: item.id,
            itemToken: item.token,
            selectionMode: selectionMode,
            selection: selection,
            items: items
        )
        guard let cell = collection.cellForItem(at: IndexPath(item: index, section: 0)) as? ProjectBrowserCell
        else { return }
        dragging = true
        let preview = cell.compactPreview(count: dragTokens.count)
        preview.center = point
        let window =
            view.window
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
            .first { $0.isKeyWindow }
        let windowPoint = view.convert(point, to: window)
        preview.center = windowPoint
        window?.addSubview(preview)
        dragView = preview
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func updateDragPosition(_ point: CGPoint) {
        guard let dragView, let host = dragView.superview else { return }
        dragView.center = view.convert(point, to: host)
    }

    private func updateHover(_ point: CGPoint) {
        guard dragging else { return }
        if ProjectBrowserDragPolicy.shouldReturnToRoot(insideFolder: insideFolder, pointY: point.y) {
            beginHover(key: "root") { [weak self] in
                guard let self else { return }
                self.events?.root(self.dragTokens)
            }
            return
        }
        let local = view.convert(point, to: collection)
        guard let indexPath = collection.indexPathForItem(at: local), items.indices.contains(indexPath.item),
            case .folder(let folder) = items[indexPath.item], let cell = collection.cellForItem(at: indexPath)
        else {
            cancelHover()
            return
        }
        let position = collection.convert(local, to: cell)
        let enterZone = ProjectBrowserDragPolicy.isFolderEnterZone(
            positionX: position.x,
            cellWidth: cell.bounds.width
        )
        guard enterZone else {
            cancelHover()
            return
        }
        beginHover(key: "folder:\(folder.id.uuidString)") { [weak self] in
            guard let self else { return }
            self.events?.enter(folder.id, self.dragTokens)
        }
    }

    private func beginHover(key: String, action: @escaping () -> Void) {
        if hoverKey == key { return }
        cancelHover()
        hoverKey = key
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: false) { [weak self] _ in
            guard let self, self.hoverKey == key, self.dragging else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            self.hoverKey = nil
            self.hoverTimer = nil
            action()
        }
    }

    private func cancelHover() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        hoverKey = nil
    }

    private func finishDrag(_ point: CGPoint) {
        cancelHover()
        let local = view.convert(point, to: collection)
        if let indexPath = collection.indexPathForItem(at: local), items.indices.contains(indexPath.item) {
            let target = items[indexPath.item]
            let after = ProjectBrowserDragPolicy.dropIsAfter(
                localY: local.y,
                itemMidY: collection.layoutAttributesForItem(at: indexPath)!.frame.midY
            )
            events?.reorder(dragTokens, target.token, after)
        } else {
            events?.reorder(dragTokens, "__end__", true)
        }
    }

    private func clearDrag() {
        cancelHover()
        dragView?.removeFromSuperview()
        dragView = nil
        candidateIndex = nil
        dragTokens = []
        dragging = false
        collection.reloadData()
    }
}

private final class ProjectBrowserCell: UICollectionViewCell {
    private let thumb = UIImageView()
    private let title = UILabel()
    private let date = UILabel()
    private let pages = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let badge = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.borderColor = UIColor.separator.cgColor
        contentView.layer.borderWidth = 0.5
        thumb.contentMode = .scaleAspectFit
        thumb.layer.cornerRadius = 5
        thumb.clipsToBounds = true
        title.numberOfLines = 2
        title.font = .preferredFont(forTextStyle: .body)
        date.font = .preferredFont(forTextStyle: .caption1)
        pages.font = .preferredFont(forTextStyle: .caption1)
        date.textAlignment = .center
        pages.textAlignment = .center
        date.textColor = .secondaryLabel
        pages.textColor = .secondaryLabel
        chevron.tintColor = .tertiaryLabel
        badge.textAlignment = .center
        badge.textColor = .white
        badge.backgroundColor = .tintColor
        badge.layer.cornerRadius = 13.5
        badge.clipsToBounds = true
        [thumb, title, date, pages, chevron, badge].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        NSLayoutConstraint.activate([
            thumb.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            thumb.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumb.widthAnchor.constraint(equalToConstant: 40),
            thumb.heightAnchor.constraint(equalToConstant: 52),
            title.leadingAnchor.constraint(equalTo: thumb.trailingAnchor, constant: 12),
            title.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            title.trailingAnchor.constraint(lessThanOrEqualTo: date.leadingAnchor, constant: -8),
            date.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            date.topAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -22),
            date.widthAnchor.constraint(equalToConstant: 84),
            pages.centerXAnchor.constraint(equalTo: date.centerXAnchor),
            pages.topAnchor.constraint(equalTo: date.bottomAnchor, constant: 5),
            chevron.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            badge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            badge.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            badge.widthAnchor.constraint(equalToConstant: 27),
            badge.heightAnchor.constraint(equalToConstant: 27),
        ])
    }
    required init?(coder: NSCoder) {
        fatalError("ProjectBrowserCell is created programmatically.")
    }

    func configure(item: ProjectBrowserItem, selectionNumber: Int?) {
        thumb.backgroundColor = .clear
        switch item {
        case .folder(let folder):
            thumb.image = UIImage(systemName: "folder.fill")
            thumb.tintColor = .tintColor
            title.text = folder.name
            date.isHidden = true
            pages.isHidden = true
            chevron.isHidden = false
        case .project(let project):
            if let data = project.previewItem?.renderedData, let image = UIImage(data: data) {
                thumb.image = PageColorRenderer.render(image, mode: project.previewItem?.colorMode ?? .color)
            } else {
                thumb.image = nil
                thumb.backgroundColor = .secondarySystemFill
            }
            title.text = project.outputName
            let calendar = Calendar.current
            date.text =
                "\(calendar.component(.year, from: project.updatedAt))/\(calendar.component(.month, from: project.updatedAt))/\(calendar.component(.day, from: project.updatedAt))"
            pages.text = "▤  \(project.pages.count)"
            date.isHidden = false
            pages.isHidden = false
            chevron.isHidden = true
        }
        badge.isHidden = selectionNumber == nil
        badge.text = selectionNumber.map(String.init)
    }

    func compactPreview(count: Int) -> UIView {
        let box = UIView()
        box.backgroundColor = .secondarySystemBackground
        box.layer.cornerRadius = 14
        box.layer.shadowColor = UIColor.black.cgColor
        box.layer.shadowOpacity = 0.22
        box.layer.shadowRadius = 5
        let image = UIImageView(image: thumb.image)
        image.tintColor = thumb.tintColor
        image.contentMode = .scaleAspectFit
        image.translatesAutoresizingMaskIntoConstraints = false
        let label = UILabel()
        label.text = title.text
        label.font = .preferredFont(forTextStyle: .headline)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(image)
        box.addSubview(label)
        box.frame = CGRect(
            x: 0, y: 0, width: min(230, max(130, label.intrinsicContentSize.width + 82)), height: 76)
        NSLayoutConstraint.activate([
            image.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            image.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            image.widthAnchor.constraint(equalToConstant: 48),
            image.heightAnchor.constraint(equalToConstant: 56),
            label.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: box.centerYAnchor),
        ])
        if count > 1 {
            let b = UILabel(frame: CGRect(x: box.bounds.maxX - 30, y: 4, width: 26, height: 26))
            b.text = "\(count)"
            b.textAlignment = .center
            b.textColor = .white
            b.backgroundColor = .tintColor
            b.layer.cornerRadius = 13
            b.clipsToBounds = true
            box.addSubview(b)
        }
        return box
    }
}
