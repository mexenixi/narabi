import UIKit

extension WorkspaceBoardController {
    func reloadChangedCells(
        in collection: UICollectionView, oldItems: [ProjectPage], newItems: [ProjectPage],
        oldSelection: [UUID], newSelection: [UUID]
    ) {
        guard oldItems.map(\.id) == newItems.map(\.id) else { return }
        let oldNumbers = Dictionary(
            uniqueKeysWithValues: oldSelection.enumerated().map { ($0.element, $0.offset) })
        let newNumbers = Dictionary(
            uniqueKeysWithValues: newSelection.enumerated().map { ($0.element, $0.offset) })
        let paths = newItems.indices.compactMap { index -> IndexPath? in
            let changed =
                oldItems[index] != newItems[index]
                || oldNumbers[newItems[index].id] != newNumbers[newItems[index].id]
            return changed ? IndexPath(item: index, section: 0) : nil
        }
        let visible = Set(collection.indexPathsForVisibleItems)
        let targets = paths.filter { visible.contains($0) }
        guard !targets.isEmpty else { return }
        UIView.performWithoutAnimation { collection.reloadItems(at: targets) }
    }

    func updateCollection(_ collection: UICollectionView, oldIDs: [UUID], newIDs: [UUID]) {
        guard oldIDs != newIDs else { return }

        // The common drag result is one existing page moved within the same area.
        // Preserve its cell and rendered thumbnail instead of rebuilding every visible cell.
        if oldIDs.count == newIDs.count, Set(oldIDs) == Set(newIDs),
            let move = singleMove(from: oldIDs, to: newIDs)
        {
            UIView.performWithoutAnimation {
                collection.performBatchUpdates {
                    collection.moveItem(
                        at: IndexPath(item: move.from, section: 0),
                        to: IndexPath(item: move.to, section: 0)
                    )
                }
            }
            return
        }

        // Cross-area and grouped edits can change counts. Keep the proven fallback.
        UIView.performWithoutAnimation {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            collection.reloadData()
            collection.layoutIfNeeded()
            CATransaction.commit()
        }
    }

    func singleMove(from oldIDs: [UUID], to newIDs: [UUID]) -> (from: Int, to: Int)? {
        guard oldIDs.count == newIDs.count, oldIDs != newIDs else { return nil }
        for from in oldIDs.indices {
            var candidate = oldIDs
            let moved = candidate.remove(at: from)
            for to in newIDs.indices {
                var test = candidate
                test.insert(moved, at: to)
                if test == newIDs { return (from, to) }
            }
        }
        return nil
    }

    func refreshVisibleMetadata(
        in collection: UICollectionView,
        items: [ProjectPage],
        selection: [UUID],
        showsPageNumber: Bool
    ) {
        let numbers = Dictionary(
            uniqueKeysWithValues: selection.enumerated().map { ($0.element, $0.offset + 1) })
        for path in collection.indexPathsForVisibleItems where items.indices.contains(path.item) {
            guard let cell = collection.cellForItem(at: path) as? WorkspaceCell else { continue }
            let item = items[path.item]
            cell.updateMetadata(
                item: item,
                pageNumber: showsPageNumber ? path.item + 1 : nil,
                selectionNumber: numbers[item.id]
            )
        }
    }

    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let items = collectionView === editorCollection ? project.pages : project.tray
        for indexPath in indexPaths where items.indices.contains(indexPath.item) {
            let item = items[indexPath.item]
            let maximumPixel = 420
            let key = WorkspaceCell.thumbnailKey(for: item, maximumPixel: maximumPixel)
            WorkspaceThumbnailLoader.shared.prefetch(
                page: item, key: key, maximumPixel: CGFloat(maximumPixel))
        }
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        collectionView === editorCollection ? project.pages.count : project.tray.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: WorkspaceCell.reuseID,
                for: indexPath
            ) as? WorkspaceCell
        else {
            return UICollectionViewCell()
        }

        if collectionView === editorCollection {
            let item = project.pages[indexPath.item]
            cell.configure(
                item: item,
                pageNumber: indexPath.item + 1,
                selectionNumber: editorSelection.firstIndex(of: item.id).map { $0 + 1 }
            )
        } else {
            let item = project.tray[indexPath.item]
            cell.configure(
                item: item,
                pageNumber: nil,
                selectionNumber: traySelection.firstIndex(of: item.id).map { $0 + 1 }
            )
        }
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        guard editorSecondaryPan.state == .possible,
            traySecondaryPan.state == .possible
        else {
            return
        }
        if collectionView === editorCollection {
            guard project.pages.indices.contains(indexPath.item) else { return }
            events?.tap(item: project.pages[indexPath.item], area: .editor)
        } else {
            guard project.tray.indices.contains(indexPath.item) else { return }
            events?.tap(item: project.tray[indexPath.item], area: .tray)
        }
    }
}
