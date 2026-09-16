import PDFKit
import Photos
import PhotosUI
import StoreKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

enum DragArea { case editor, tray }
enum RemoveTarget { case tray, deleted }
enum TrayDropAction { case add, swap, update }

struct PendingTrayDrop {
    let sourceID: UUID
    let destinationID: UUID
}

struct EditingTarget: Identifiable {
    let id = UUID()
    let item: ProjectPage
    let area: DragArea
}

// MARK: - 編集欄・素材欄の読み取り専用プレビュー
