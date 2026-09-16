import SwiftUI
import UIKit

struct PlacementGestureSurface: UIViewRepresentable {
    @Binding var scale: Double
    @Binding var offsetX: Double
    @Binding var offsetY: Double
    @Binding var rotation: Double
    let scaleRange: ClosedRange<Double>
    let offsetLimits: () -> (x: Double, y: Double)
    let openPreview: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true

        let touch = UILongPressGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.touch(_:)))
        touch.minimumPressDuration = 0
        touch.allowableMovement = .greatestFiniteMagnitude
        touch.cancelsTouchesInView = false
        touch.delegate = context.coordinator

        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.pinch(_:)))
        pinch.delegate = context.coordinator
        let rotate = UIRotationGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.rotate(_:)))
        rotate.delegate = context.coordinator

        view.addGestureRecognizer(touch)
        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(rotate)
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) { context.coordinator.parent = self }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: PlacementGestureSurface
        private var startPoint = CGPoint.zero
        private var startX = 0.0, startY = 0.0, startScale = 1.0, startRotation = 0.0
        private var exceededEightPoints = false
        private var usedTwoFingers = false
        private var previewReady = false
        private var holdWork: DispatchWorkItem?

        init(_ parent: PlacementGestureSurface) { self.parent = parent }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            guard gestureRecognizer.view === otherGestureRecognizer.view else { return false }
            let own = [gestureRecognizer, otherGestureRecognizer]
            let containsTwoFingerGesture = own.contains {
                $0 is UIPinchGestureRecognizer || $0 is UIRotationGestureRecognizer
            }
            let containsPlacementGesture = own.allSatisfy {
                $0 is UILongPressGestureRecognizer || $0 is UIPinchGestureRecognizer
                    || $0 is UIRotationGestureRecognizer
            }
            return containsTwoFingerGesture && containsPlacementGesture
        }

        private func cancelHold() {
            holdWork?.cancel()
            holdWork = nil
        }
        private func beginHold() {
            cancelHold()
            previewReady = false
            let work = DispatchWorkItem { [weak self] in
                guard let self, !self.exceededEightPoints, !self.usedTwoFingers else { return }
                self.previewReady = true
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
            holdWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
        }

        @objc func touch(_ g: UILongPressGestureRecognizer) {
            guard let view = g.view else { return }
            let point = g.location(in: view)
            switch g.state {
            case .began:
                startPoint = point
                startX = parent.offsetX
                startY = parent.offsetY
                exceededEightPoints = false
                usedTwoFingers = false
                beginHold()
            case .changed:
                let dx = point.x - startPoint.x
                let dy = point.y - startPoint.y
                if hypot(dx, dy) >= 8 {
                    exceededEightPoints = true
                    previewReady = false
                    cancelHold()
                }
                let limits = parent.offsetLimits()
                parent.offsetX = min(
                    limits.x, max(-limits.x, startX + Double(dx / max(view.bounds.width, 1)) * 2))
                parent.offsetY = min(
                    limits.y, max(-limits.y, startY + Double(dy / max(view.bounds.height, 1)) * 2))
            case .ended:
                cancelHold()
                if previewReady && !exceededEightPoints && !usedTwoFingers {
                    parent.offsetX = startX
                    parent.offsetY = startY
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    parent.openPreview()
                } else if !exceededEightPoints {
                    parent.offsetX = startX
                    parent.offsetY = startY
                }
            case .cancelled, .failed:
                cancelHold()
                if !usedTwoFingers {
                    parent.offsetX = startX
                    parent.offsetY = startY
                }
            default: break
            }
        }

        private func beginTwoFinger() {
            usedTwoFingers = true
            previewReady = false
            cancelHold()
        }
        @objc func pinch(_ g: UIPinchGestureRecognizer) {
            switch g.state {
            case .began:
                beginTwoFinger()
                startScale = parent.scale
            case .changed:
                parent.scale = min(
                    parent.scaleRange.upperBound,
                    max(parent.scaleRange.lowerBound, startScale * Double(g.scale)))
            default: break
            }
        }
        @objc func rotate(_ g: UIRotationGestureRecognizer) {
            switch g.state {
            case .began:
                beginTwoFinger()
                startRotation = parent.rotation
            case .changed:
                var value = startRotation + Double(g.rotation) * 180.0 / Double.pi
                while value > 180 { value -= 360 }
                while value < -180 { value += 360 }
                parent.rotation = value
            case .ended: parent.rotation = parent.rotation.rounded()
            default: break
            }
        }
    }
}
