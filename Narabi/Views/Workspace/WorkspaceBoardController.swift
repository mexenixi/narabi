import SwiftUI
import UIKit

@MainActor
final class WorkspaceBoardController: UIViewController,
    UICollectionViewDataSource,
    UICollectionViewDataSourcePrefetching,
    UICollectionViewDelegate,
    UIGestureRecognizerDelegate
{
    weak var events: WorkspaceBoardEvents?
    var toggleTraySelectionMode: (() -> Void)?
    var toggleTrayCollapsed: (() -> Void)?
    var deleteTraySelection: (() -> Void)?
    var selectAllTrayItems: (() -> Void)?
    var clearTraySelectionItems: (() -> Void)?

    var project = NarabiProject()
    var editorSelection: [UUID] = []
    var traySelection: [UUID] = []
    var editorSelectionMode = false
    var traySelectionMode = false
    var previousEditorSelection: [UUID] = []
    var previousTraySelection: [UUID] = []

    let editorCollection: UICollectionView
    let trayCollection: UICollectionView
    let trayHeaderView = UIView()
    let dragOverlayView = UIView()
    let trayTitleLabel = UILabel()
    var trayHeightConstraint: NSLayoutConstraint?
    var didDragDuringCurrentPress = false
    var autoScrollUnlocked = false
    var autoScrollLeftSafeZone = false
    var autoScrollDisplayLink: CADisplayLink?
    weak var autoScrollCollection: UICollectionView?
    var autoScrollVelocity = CGPoint.zero
    let traySelectionCountLabel = UILabel()
    let traySelectAllButton = UIButton(type: .system)
    let trayClearButton = UIButton(type: .system)
    let trayDeleteButton = UIButton(type: .system)
    let traySelectButton = UIButton(type: .system)
    let editorLayout = UICollectionViewFlowLayout()
    let trayLayout = UICollectionViewFlowLayout()

    var dragArea: WorkspaceArea?
    var dragIDs: [UUID] = []
    var dragStartIndex = 0
    var dragBecameMovement = false
    var dragStartFingerPoint = CGPoint.zero
    weak var activeCell: WorkspaceCell?
    var dragView: UIView?
    var dragBackingViews: [UIView] = []
    var touchOffsetInsideDragView = CGPoint.zero
    var editorPrimaryPress: UILongPressGestureRecognizer?
    var trayPrimaryPress: UILongPressGestureRecognizer?
    weak var activeDragRecognizer: UILongPressGestureRecognizer?

    lazy var editorSecondaryPan = UIPanGestureRecognizer(
        target: self,
        action: #selector(handleEditorSecondaryPan(_:))
    )
    lazy var traySecondaryPan = UIPanGestureRecognizer(
        target: self,
        action: #selector(handleTraySecondaryPan(_:))
    )
    var editorSecondaryStartOffset = CGPoint.zero
    var traySecondaryStartOffset = CGPoint.zero

    init() {
        editorLayout.minimumInteritemSpacing = 8
        editorLayout.minimumLineSpacing = 8
        editorLayout.sectionInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        trayLayout.scrollDirection = .horizontal
        trayLayout.minimumInteritemSpacing = 8
        trayLayout.minimumLineSpacing = 8
        trayLayout.sectionInset = UIEdgeInsets(top: 5, left: 8, bottom: 5, right: 8)

        editorCollection = UICollectionView(frame: .zero, collectionViewLayout: editorLayout)
        trayCollection = UICollectionView(frame: .zero, collectionViewLayout: trayLayout)
        super.init(nibName: nil, bundle: nil)
        editorCollection.semanticContentAttribute = .forceLeftToRight
        trayCollection.semanticContentAttribute = .forceLeftToRight
        dragOverlayView.semanticContentAttribute = .forceLeftToRight
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        WorkspaceThumbnailLoader.shared.removeAll()
        dragView?.removeFromSuperview()
        dragBackingViews.forEach { $0.removeFromSuperview() }
        dragBackingViews.removeAll(keepingCapacity: false)
    }

    required init?(coder: NSCoder) {
        fatalError("WorkspaceBoardController is created programmatically.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        editorCollection.backgroundColor = .clear
        editorCollection.alwaysBounceVertical = true
        editorCollection.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 180, right: 0)
        editorCollection.verticalScrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 180, right: 0)

        trayHeaderView.backgroundColor = .systemBackground
        trayTitleLabel.text = "⌄"
        trayTitleLabel.isUserInteractionEnabled = true
        trayTitleLabel.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(toggleTrayVisibility)))
        trayTitleLabel.accessibilityLabel = L10n.text("workspace.tray.toggle", "素材欄を開閉")
        trayTitleLabel.font = .preferredFont(forTextStyle: .headline)
        trayTitleLabel.textAlignment = .center
        traySelectionCountLabel.font = .preferredFont(forTextStyle: .caption1)
        traySelectionCountLabel.textColor = .secondaryLabel
        trayDeleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
        trayDeleteButton.tintColor = .systemRed
        trayDeleteButton.accessibilityLabel = L10n.text("selection.delete", "選択項目を削除")
        traySelectAllButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
        traySelectAllButton.accessibilityLabel = L10n.text("selection.selectAll", "全選択")
        traySelectAllButton.addTarget(self, action: #selector(selectAllTrayItemsNow), for: .touchUpInside)
        trayClearButton.setImage(UIImage(systemName: "circle"), for: .normal)
        trayClearButton.accessibilityLabel = L10n.text("selection.clearAll", "全解除")
        trayClearButton.addTarget(self, action: #selector(clearTraySelectionNow), for: .touchUpInside)
        trayDeleteButton.addTarget(self, action: #selector(deleteSelectedTrayItems), for: .touchUpInside)
        traySelectButton.addTarget(self, action: #selector(toggleTraySelection), for: .touchUpInside)

        [
            trayTitleLabel, traySelectionCountLabel, traySelectAllButton, trayClearButton, trayDeleteButton,
            traySelectButton,
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            trayHeaderView.addSubview($0)
        }

        trayCollection.backgroundColor = UIColor.tertiarySystemFill
        trayCollection.layer.cornerRadius = 10
        trayCollection.layer.borderWidth = 1
        trayCollection.layer.borderColor = UIColor.separator.cgColor
        trayCollection.clipsToBounds = true

        dragOverlayView.backgroundColor = .clear
        dragOverlayView.isUserInteractionEnabled = false
        dragOverlayView.translatesAutoresizingMaskIntoConstraints = false

        [editorCollection, trayCollection].forEach { collectionView in
            collectionView.dataSource = self
            collectionView.prefetchDataSource = self
            collectionView.delegate = self
            collectionView.register(
                WorkspaceCell.self,
                forCellWithReuseIdentifier: WorkspaceCell.reuseID
            )
            collectionView.translatesAutoresizingMaskIntoConstraints = false
            collectionView.clipsToBounds = true
            collectionView.layer.masksToBounds = true
            view.addSubview(collectionView)
        }

        trayHeaderView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(trayHeaderView)

        view.addSubview(dragOverlayView)
        view.bringSubviewToFront(dragOverlayView)

        let editorPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleEditorPress(_:))
        )
        editorPress.minimumPressDuration = 0.18
        editorPress.allowableMovement = 1000
        editorPress.numberOfTouchesRequired = 1
        editorPress.cancelsTouchesInView = true
        editorPress.delegate = self
        editorPrimaryPress = editorPress
        editorCollection.addGestureRecognizer(editorPress)

        let trayPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleTrayPress(_:))
        )
        trayPress.minimumPressDuration = 0.18
        trayPress.allowableMovement = 1000
        trayPress.numberOfTouchesRequired = 1
        trayPress.cancelsTouchesInView = true
        trayPress.delegate = self
        trayPrimaryPress = trayPress
        trayCollection.addGestureRecognizer(trayPress)

        configureSecondaryScrollRecognizers()

        NSLayoutConstraint.activate([
            editorCollection.topAnchor.constraint(equalTo: view.topAnchor),
            editorCollection.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            editorCollection.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            trayHeaderView.topAnchor.constraint(equalTo: editorCollection.bottomAnchor, constant: 4),
            trayHeaderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            trayHeaderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            trayHeaderView.heightAnchor.constraint(equalToConstant: 44),

            trayTitleLabel.leadingAnchor.constraint(equalTo: trayHeaderView.leadingAnchor, constant: 10),
            trayTitleLabel.centerYAnchor.constraint(equalTo: trayHeaderView.centerYAnchor),
            trayTitleLabel.widthAnchor.constraint(equalToConstant: 44),
            trayTitleLabel.heightAnchor.constraint(equalToConstant: 44),
            traySelectionCountLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: trayTitleLabel.trailingAnchor, constant: 8),
            traySelectionCountLabel.centerYAnchor.constraint(equalTo: trayHeaderView.centerYAnchor),
            traySelectAllButton.leadingAnchor.constraint(
                equalTo: traySelectionCountLabel.trailingAnchor, constant: 10),
            traySelectAllButton.centerYAnchor.constraint(equalTo: trayHeaderView.centerYAnchor),
            trayClearButton.leadingAnchor.constraint(
                equalTo: traySelectAllButton.trailingAnchor, constant: 10),
            trayClearButton.centerYAnchor.constraint(equalTo: trayHeaderView.centerYAnchor),
            trayDeleteButton.leadingAnchor.constraint(equalTo: trayClearButton.trailingAnchor, constant: 10),
            trayDeleteButton.centerYAnchor.constraint(equalTo: trayHeaderView.centerYAnchor),
            traySelectButton.leadingAnchor.constraint(equalTo: trayDeleteButton.trailingAnchor, constant: 10),
            traySelectButton.trailingAnchor.constraint(equalTo: trayHeaderView.trailingAnchor, constant: -16),
            traySelectButton.centerYAnchor.constraint(equalTo: trayHeaderView.centerYAnchor),

            trayCollection.topAnchor.constraint(equalTo: trayHeaderView.bottomAnchor),
            trayCollection.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            trayCollection.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            trayCollection.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            {
                let c = trayCollection.heightAnchor.constraint(equalToConstant: 116)
                trayHeightConstraint = c
                return c
            }(),

            dragOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            dragOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dragOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dragOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // 表示階層を明示的に固定します。
        // 編集欄は常に最背面、移動中画像だけが最前面です。
        view.sendSubviewToBack(editorCollection)
        view.insertSubview(trayCollection, aboveSubview: editorCollection)
        view.insertSubview(trayHeaderView, aboveSubview: trayCollection)
        view.bringSubviewToFront(dragOverlayView)

    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let availableWidth = editorCollection.bounds.width
        let columns = WorkspaceLayoutPolicy.editorColumnCount(
            isPad: traitCollection.userInterfaceIdiom == .pad,
            availableWidth: availableWidth
        )
        editorLayout.itemSize = WorkspaceLayoutPolicy.editorItemSize(
            availableWidth: availableWidth,
            columns: columns,
            leftInset: editorLayout.sectionInset.left,
            rightInset: editorLayout.sectionInset.right,
            interitemSpacing: editorLayout.minimumInteritemSpacing
        )
        trayLayout.itemSize = CGSize(width: 88, height: 106)

        // 少数ページでも下方向へ十分にスクロールでき、空白へドロップできます。
        let minimumScrollableHeight = editorCollection.bounds.height + 180
        if editorCollection.contentSize.height < minimumScrollableHeight {
            editorCollection.contentInset.bottom = 180
        }

        enforceLayerOrder()
    }

    func enforceLayerOrder() {
        view.sendSubviewToBack(editorCollection)
        view.insertSubview(trayCollection, aboveSubview: editorCollection)
        view.insertSubview(trayHeaderView, aboveSubview: trayCollection)
        view.bringSubviewToFront(dragOverlayView)
    }

    func apply(
        project: NarabiProject,
        editorSelection: [UUID],
        traySelection: [UUID],
        editorSelectionMode: Bool,
        traySelectionMode: Bool
    ) {
        let previousProject = self.project
        let oldEditorIDs = previousProject.pages.map(\.id)
        let oldTrayIDs = previousProject.tray.map(\.id)
        let editorIDs = project.pages.map(\.id)
        let trayIDs = project.tray.map(\.id)

        self.project = project
        self.editorSelection = editorSelection
        self.traySelection = traySelection
        self.editorSelectionMode = editorSelectionMode
        self.traySelectionMode = traySelectionMode
        traySelectButton.setTitle(nil, for: .normal)
        traySelectButton.setImage(
            UIImage(systemName: traySelectionMode ? "checkmark.circle.fill" : "checkmark.circle"),
            for: .normal)
        traySelectButton.accessibilityLabel =
            traySelectionMode ? L10n.text("common.done", "完了") : L10n.text("common.select", "選択")
        traySelectionCountLabel.text =
            traySelectionMode ? L10n.format("selection.count", traySelection.count) : ""
        traySelectionCountLabel.isHidden = !traySelectionMode
        traySelectButton.setTitle(nil, for: .normal)
        traySelectButton.setImage(
            UIImage(systemName: traySelectionMode ? "checkmark.circle.fill" : "checkmark.circle"),
            for: .normal)
        traySelectButton.accessibilityLabel =
            traySelectionMode ? L10n.text("common.done", "完了") : L10n.text("common.select", "選択")
        traySelectAllButton.isHidden = !traySelectionMode
        trayClearButton.isHidden = !traySelectionMode
        trayDeleteButton.isHidden = !traySelectionMode
        let collapsed = project.isTrayCollapsed
        trayTitleLabel.text = collapsed ? "⌃" : "⌄"
        trayCollection.isHidden = collapsed
        trayHeightConstraint?.constant = collapsed ? 0 : 116
        editorCollection.contentInset.bottom = collapsed ? 8 : 180
        editorCollection.verticalScrollIndicatorInsets.bottom = collapsed ? 8 : 180

        guard dragView == nil else { return }
        updateCollection(editorCollection, oldIDs: oldEditorIDs, newIDs: editorIDs)
        updateCollection(trayCollection, oldIDs: oldTrayIDs, newIDs: trayIDs)
        reloadChangedCells(
            in: editorCollection, oldItems: previousProject.pages, newItems: project.pages,
            oldSelection: self.previousEditorSelection, newSelection: editorSelection)
        reloadChangedCells(
            in: trayCollection, oldItems: previousProject.tray, newItems: project.tray,
            oldSelection: self.previousTraySelection, newSelection: traySelection)
        refreshVisibleMetadata(
            in: editorCollection, items: project.pages, selection: editorSelection, showsPageNumber: true)
        refreshVisibleMetadata(
            in: trayCollection, items: project.tray, selection: traySelection, showsPageNumber: false)
        previousEditorSelection = editorSelection
        previousTraySelection = traySelection
    }

    @objc func toggleTrayVisibility() {
        toggleTrayCollapsed?()
    }

    @objc func toggleTraySelection() {
        toggleTraySelectionMode?()
    }

    @objc func selectAllTrayItemsNow() { selectAllTrayItems?() }
    @objc func clearTraySelectionNow() { clearTraySelectionItems?() }
    @objc func deleteSelectedTrayItems() { deleteTraySelection?() }
}
