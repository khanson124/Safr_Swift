//
//  QRScannerView.swift
//  Safr
//

import SwiftUI
import Vision
import VisionKit

@available(iOS 16.0, *)
struct QRScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    @Binding var isLocked: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, isLocked: $isLocked)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        guard !isLocked else { return }
        if !uiViewController.isScanning {
            try? uiViewController.startScanning()
        }
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        @Binding var isLocked: Bool

        init(onScan: @escaping (String) -> Void, isLocked: Binding<Bool>) {
            self.onScan = onScan
            _isLocked = isLocked
        }

        private func handle(_ item: RecognizedItem, scanner: DataScannerViewController) {
            guard !isLocked else { return }
            if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                isLocked = true
                scanner.stopScanning()
                onScan(payload)
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            handle(item, scanner: dataScanner)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard let item = addedItems.first else { return }
            handle(item, scanner: dataScanner)
        }
    }
}
