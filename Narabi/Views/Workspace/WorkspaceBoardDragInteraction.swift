import UIKit

extension WorkspaceBoardController {
    @objc func handleEditorPress(_ recognizer: UILongPressGestureRecognizer) {
        handlePress(recognizer, sourceArea: .editor, collection: editorCollection)
    }

    @objc func handleTrayPress(_ recognizer: UILongPressGestureRecognizer) {
        handlePress(recognizer, sourceArea: .tray, collection: trayCollection)
    }

    func handlePress(
        _ recognizer: UILongPressGestureRecognizer,
        sourceArea: WorkspaceArea,
        collection: UICollectionView
    ) {
        let local = recognizer.location(in: collection)
        let windowPoint = recognizer.location(in: view)

        switch recognizer.state {
        case .began:
            // A second long press is intentionally ignored. Do not toggle its
            // recognizer because resetting one recognizer can disturb the active drag
            // and the second-finger pan that is allowed to scroll the workspace.
            guard dragArea == nil else {

                return
            }
            didDragDuringCurrentPress = false
            autoScrollUnlocked = false
            autoScrollLeftSafeZone = false
            guard let indexPath = collection.indexPathForItem(at: local) else { return }
            guard
                beginOperation(
                    area: sourceArea, index: indexPath.item, collection: collection, windowPoint: windowPoint)
            else {
                recognizer.isEnabled = false
                recognizer.isEnabled = true
                return
            }
            activeDragRecognizer = recognizer

        case .changed:
            guard recognizer === activeDragRecognizer else { return }
            guard let dragView else { return }
            let movement = hypot(
                windowPoint.x - dragStartFingerPoint.x,
                windowPoint.y - dragStartFingerPoint.y
            )
            if movement >= 8 {
                didDragDuringCurrentPress = true
                let safeBounds: CGRect
                let edgeBounds: CGRect
                if sourceArea == .tray {
                    safeBounds = collection.bounds.insetBy(dx: 64, dy: 0)
                    edgeBounds = collection.bounds.insetBy(dx: 28, dy: 0)
                } else {
                    safeBounds = collection.bounds.insetBy(dx: 0, dy: 64)
                    edgeBounds = collection.bounds.insetBy(dx: 0, dy: 28)
                }
                if safeBounds.contains(local) { autoScrollLeftSafeZone = true }
                if autoScrollLeftSafeZone && !edgeBounds.contains(local) { autoScrollUnlocked = true }
                dragBecameMovement = true
            }
            let pointInOverlay = view.convert(windowPoint, to: dragOverlayView)
            dragView.center = CGPoint(
                x: pointInOverlay.x - touchOffsetInsideDragView.x,
                y: pointInOverlay.y - touchOffsetInsideDragView.y
            )
            for (index, backing) in dragBackingViews.enumerated() {
                let depth = CGFloat(dragBackingViews.count - index)
                backing.center = CGPoint(x: dragView.center.x + depth * 7, y: dragView.center.y - depth * 7)
            }
            updateAutoScroll(for: sourceArea, collection: collection, localPoint: local)

        case .ended:
            guard recognizer === activeDragRecognizer else { return }
            finishOperation(at: windowPoint)

        case .cancelled, .failed:
            guard recognizer === activeDragRecognizer else { return }
            cancelOperation()

        default:
            break
        }
    }

    func beginOperation(
        area: WorkspaceArea,
        index: Int,
        collection: UICollectionView,
        windowPoint: CGPoint
    ) -> Bool {
        let item: ProjectPage
        let selected: [UUID]

        switch area {
        case .editor:
            guard project.pages.indices.contains(index) else { return false }
            item = project.pages[index]
            if editorSelectionMode {
                guard editorSelection.contains(item.id) else { return false }
                selected = editorSelection
            } else {
                selected = [item.id]
            }
        case .tray:
            guard project.tray.indices.contains(index) else { return false }
            item = project.tray[index]
            if traySelectionMode {
                guard traySelection.contains(item.id) else { return false }
                selected = traySelection
            } else {
                selected = [item.id]
            }
        }

        guard
            let cell = collection.cellForItem(
                at: IndexPath(item: index, section: 0)
            ) as? WorkspaceCell,
            let preview = cell.snapshotView(afterScreenUpdates: true)
        else {
            return false
        }

        dragArea = area
        dragIDs = selected
        dragStartIndex = index
        dragBecameMovement = false
        dragStartFingerPoint = windowPoint
        activeCell = cell

        let frameInBoard = collection.convert(cell.frame, to: dragOverlayView)
        preview.frame = frameInBoard
        preview.layer.cornerRadius = 8
        preview.layer.masksToBounds = true
        preview.layer.borderWidth = 3
        preview.layer.borderColor = (UIColor(named: "AccentColor") ?? .systemGray).cgColor
        preview.isUserInteractionEnabled = false

        touchOffsetInsideDragView = CGPoint(
            x: windowPoint.x - preview.center.x,
            y: windowPoint.y - preview.center.y
        )

        if selected.count > 1 {
            let accent = UIColor(named: "AccentColor") ?? .systemBlue
            for layerIndex in stride(from: min(selected.count - 1, 2), through: 1, by: -1) {
                let backing = UIView(
                    frame: frameInBoard.offsetBy(dx: CGFloat(layerIndex * 7), dy: CGFloat(-layerIndex * 7)))
                backing.backgroundColor = .secondarySystemBackground
                backing.layer.cornerRadius = 8
                backing.layer.borderWidth = 2
                backing.layer.borderColor = accent.cgColor
                backing.isUserInteractionEnabled = false
                dragOverlayView.addSubview(backing)
                dragBackingViews.append(backing)
            }
            let countBadge = UILabel()
            countBadge.text = selected.count > 99 ? "99+" : "\(selected.count)"
            countBadge.textAlignment = .center
            countBadge.textColor = .white
            countBadge.backgroundColor = accent
            countBadge.font = .boldSystemFont(ofSize: selected.count > 99 ? 11 : 14)
            countBadge.layer.cornerRadius = 15
            countBadge.clipsToBounds = true
            countBadge.frame = CGRect(x: preview.bounds.maxX - 27, y: -6, width: 30, height: 30)
            preview.addSubview(countBadge)
        }

        dragOverlayView.addSubview(preview)
        dragOverlayView.bringSubviewToFront(preview)
        dragView = preview
        cell.setLongPressActive(true)

        // 1本目の指による標準スクロールを停止します。
        editorCollection.panGestureRecognizer.isEnabled = false
        trayCollection.panGestureRecognizer.isEnabled = false

        // 長押し成立後に有効化するため、すでに接触中の1本目は拾わず、
        // その後に置かれた別の指だけをスクロール用として扱います。
        editorSecondaryPan.isEnabled = true
        traySecondaryPan.isEnabled = true

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        return true
    }

    func finishOperation(at point: CGPoint) {
        defer { restoreCellsAndClear() }
        guard let area = dragArea, !dragIDs.isEmpty else { return }

        let target = targetAt(point)

        if !dragBecameMovement {
            if dragIDs.count == 1, let item = item(for: dragIDs[0], area: area) {
                events?.preview(item: item, title: previewTitle(area: area, id: item.id))
            }
            return
        }

        switch (area, target.area) {
        case (.editor, .editor):
            if target.index != dragStartIndex || dragIDs.count > 1 {
                events?.moveWithin(area: .editor, ids: dragIDs, destination: target.index)
            }

        case (.tray, .tray):
            if normalizedTrayDestination(target.index) != dragStartIndex || dragIDs.count > 1 {
                events?.moveWithin(area: .tray, ids: dragIDs, destination: target.index)
            }

        case (.editor, .tray):
            events?.moveEditorToTray(ids: dragIDs, destination: target.index)

        case (.tray, .editor):
            events?.moveTrayToEditor(
                ids: dragIDs,
                destination: target.index,
                destinationItemID: target.itemID
            )
        }

    }

    func targetAt(_ point: CGPoint) -> DropTarget {
        let editorFrame = editorCollection.convert(editorCollection.bounds, to: view)
        let trayFrame = trayCollection.convert(trayCollection.bounds, to: view)

        if trayFrame.contains(point) {
            let local = view.convert(point, to: trayCollection)
            if let indexPath = trayCollection.indexPathForItem(at: local) {
                return DropTarget(area: .tray, index: indexPath.item, itemID: project.tray[indexPath.item].id)
            }
            return DropTarget(area: .tray, index: project.tray.count, itemID: nil)
        }

        if editorFrame.contains(point) {
            let local = view.convert(point, to: editorCollection)
            if let indexPath = editorCollection.indexPathForItem(at: local) {
                return DropTarget(
                    area: .editor, index: indexPath.item, itemID: project.pages[indexPath.item].id)
            }
            return DropTarget(area: .editor, index: project.pages.count, itemID: nil)
        }

        return DropTarget(
            area: areaClosest(to: point),
            index: areaClosest(to: point) == .tray ? project.tray.count : project.pages.count, itemID: nil)
    }

    func areaClosest(to point: CGPoint) -> WorkspaceArea {
        let trayFrame = trayCollection.convert(trayCollection.bounds, to: view)
        return WorkspaceDragPolicy.closestArea(point: point, trayFrame: trayFrame)
    }

    func normalizedTrayDestination(_ destination: Int) -> Int {
        WorkspaceDragPolicy.normalizedTrayDestination(
            dragStartIndex: dragStartIndex,
            trayCount: project.tray.count,
            destination: destination
        )
    }

    func item(for id: UUID, area: WorkspaceArea) -> ProjectPage? {
        switch area {
        case .editor: return project.pages.first { $0.id == id }
        case .tray: return project.tray.first { $0.id == id }
        }
    }

    func previewTitle(area: WorkspaceArea, id: UUID) -> String {
        switch area {
        case .editor:
            if let index = project.pages.firstIndex(where: { $0.id == id }) {
                return L10n.format("preview.page", index + 1)
            }
            return L10n.text("preview.pageGeneric", "ページプレビュー")
        case .tray:
            return L10n.text("preview.material", "素材プレビュー")
        }
    }

    func restoreCellsAndClear() {
        stopAutoScroll()
        dragView?.removeFromSuperview()
        dragBackingViews.forEach { $0.removeFromSuperview() }
        dragBackingViews.removeAll()
        dragView = nil
        activeCell?.setLongPressActive(false)
        activeCell = nil
        activeDragRecognizer = nil
        dragArea = nil
        dragIDs.removeAll()
        dragBecameMovement = false

        editorSecondaryPan.isEnabled = false
        traySecondaryPan.isEnabled = false
        editorCollection.panGestureRecognizer.isEnabled = true
        trayCollection.panGestureRecognizer.isEnabled = true
    }

    func configureSecondaryScrollRecognizers() {
        editorSecondaryPan.minimumNumberOfTouches = 1
        editorSecondaryPan.maximumNumberOfTouches = 1
        editorSecondaryPan.cancelsTouchesInView = true
        editorSecondaryPan.delegate = self
        editorSecondaryPan.isEnabled = false
        editorCollection.addGestureRecognizer(editorSecondaryPan)

        traySecondaryPan.minimumNumberOfTouches = 1
        traySecondaryPan.maximumNumberOfTouches = 1
        traySecondaryPan.cancelsTouchesInView = true
        traySecondaryPan.delegate = self
        traySecondaryPan.isEnabled = false
        trayCollection.addGestureRecognizer(traySecondaryPan)
    }

    func updateAutoScroll(for area: WorkspaceArea, collection: UICollectionView, localPoint: CGPoint) {
        guard dragBecameMovement, autoScrollUnlocked else {
            stopAutoScroll()
            return
        }
        let velocity = WorkspaceDragPolicy.autoScrollVelocity(
            area: area,
            trayCollapsed: project.isTrayCollapsed,
            contentOffset: collection.contentOffset,
            bounds: collection.bounds,
            localPoint: localPoint
        )
        guard velocity != .zero else {
            stopAutoScroll()
            return
        }
        autoScrollCollection = collection
        autoScrollVelocity = velocity
        if autoScrollDisplayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(autoScrollTick))
            link.add(to: .main, forMode: .common)
            autoScrollDisplayLink = link
        }
    }

    @objc func autoScrollTick() {
        guard let collection = autoScrollCollection else {
            stopAutoScroll()
            return
        }
        collection.contentOffset = WorkspaceDragPolicy.clampedContentOffset(
            current: collection.contentOffset,
            velocity: autoScrollVelocity,
            contentSize: collection.contentSize,
            bounds: collection.bounds,
            adjustedInsets: collection.adjustedContentInset
        )
    }

    func stopAutoScroll() {
        autoScrollDisplayLink?.invalidate()
        autoScrollDisplayLink = nil
        autoScrollCollection = nil
        autoScrollVelocity = .zero
    }

    @objc func handleEditorSecondaryPan(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            editorSecondaryStartOffset = editorCollection.contentOffset
        case .changed:
            let translation = recognizer.translation(in: editorCollection)
            let minimum = -editorCollection.adjustedContentInset.top
            let maximum = max(
                minimum,
                editorCollection.contentSize.height
                    - editorCollection.bounds.height
                    + editorCollection.adjustedContentInset.bottom
            )
            editorCollection.contentOffset.y = min(
                max(editorSecondaryStartOffset.y - translation.y, minimum),
                maximum
            )
        case .ended, .cancelled, .failed:
            recognizer.setTranslation(.zero, in: editorCollection)
        default:
            break
        }
    }

    @objc func handleTraySecondaryPan(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            traySecondaryStartOffset = trayCollection.contentOffset
        case .changed:
            let translation = recognizer.translation(in: trayCollection)
            let minimum = -trayCollection.adjustedContentInset.left
            let maximum = max(
                minimum,
                trayCollection.contentSize.width
                    - trayCollection.bounds.width
                    + trayCollection.adjustedContentInset.right
            )
            trayCollection.contentOffset.x = min(
                max(traySecondaryStartOffset.x - translation.x, minimum),
                maximum
            )
        case .ended, .cancelled, .failed:
            recognizer.setTranslation(.zero, in: trayCollection)
        default:
            break
        }
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        let validPairs: [(UIGestureRecognizer?, UIGestureRecognizer)] = [
            (editorPrimaryPress, editorSecondaryPan),
            (trayPrimaryPress, editorSecondaryPan),
            (editorPrimaryPress, traySecondaryPan),
            (trayPrimaryPress, traySecondaryPan),
        ]

        return validPairs.contains { primary, secondary in
            guard let primary else { return false }
            return (gestureRecognizer === primary && otherGestureRecognizer === secondary)
                || (gestureRecognizer === secondary && otherGestureRecognizer === primary)
        }
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Custom secondary scrolling must never wait for the disabled built-in scroll pan.
        if gestureRecognizer === editorSecondaryPan
            || gestureRecognizer === traySecondaryPan
        {
            return false
        }
        return false
    }

    func cancelOperation() {
        restoreCellsAndClear()
    }
}

struct DropTarget {
    let area: WorkspaceArea
    let index: Int
    let itemID: UUID?
}
