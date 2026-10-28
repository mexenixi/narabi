import CoreGraphics

nonisolated enum WorkspaceDragPreviewPolicy {
    static func normalizedSize(
        sourceSize: CGSize,
        editorItemSize: CGSize,
        trayItemSize: CGSize
    ) -> CGSize {
        guard sourceSize.width > 0, sourceSize.height > 0 else { return sourceSize }
        let editorLong = max(editorItemSize.width, editorItemSize.height)
        let trayLong = max(trayItemSize.width, trayItemSize.height)
        guard editorLong > 0, trayLong > 0 else { return sourceSize }
        let targetLong = sqrt(editorLong * trayLong)
        let sourceLong = max(sourceSize.width, sourceSize.height)
        let scale = targetLong / sourceLong
        return CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
    }
}
