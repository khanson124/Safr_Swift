//
//  QRCodeImageView.swift
//  Safr
//

import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct QRCodeImageView: View {
    let value: String
    var size: CGFloat = 220

    var body: some View {
        if let image = generateQRCode(from: value) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .padding(SafrTheme.Spacing.md)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: SafrTheme.Radius.sm))
        } else {
            RoundedRectangle(cornerRadius: SafrTheme.Radius.sm)
                .fill(SafrTheme.Colors.surface)
                .frame(width: size, height: size)
                .overlay {
                    Text("QR unavailable")
                        .foregroundStyle(SafrTheme.Colors.textSecondary)
                }
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
