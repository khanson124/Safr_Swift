//
//  DocumentUploadField.swift
//  Safr
//

import SwiftUI

struct DocumentUploadField: View {
    let label: String
    var helper: String?
    var previewURL: String?
    var previewImage: UIImage?
    var fileLabel: String?
    var isUploading = false
    var onTakePhoto: () -> Void
    var onChooseFromLibrary: () -> Void
    var onRemove: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: SafrTheme.Spacing.sm) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SafrTheme.Colors.textPrimary)

            if let helper, !helper.isEmpty {
                Text(helper)
                    .font(.caption)
                    .foregroundStyle(SafrTheme.Colors.textSecondary)
            }

            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: SafrTheme.Radius.sm))
            } else if let previewURL, let url = URL(string: previewURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        RoundedRectangle(cornerRadius: SafrTheme.Radius.sm)
                            .fill(SafrTheme.Colors.surface)
                            .overlay { ProgressView().tint(SafrTheme.Colors.accent) }
                    }
                }
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: SafrTheme.Radius.sm))
            }

            if let fileLabel, !fileLabel.isEmpty {
                Text(fileLabel)
                    .font(.caption)
                    .foregroundStyle(SafrTheme.Colors.textSecondary)
            }

            HStack(spacing: SafrTheme.Spacing.sm) {
                Button("Take photo", action: onTakePhoto)
                    .buttonStyle(.bordered)
                    .tint(SafrTheme.Colors.accent)

                Button("Choose photo", action: onChooseFromLibrary)
                    .buttonStyle(.bordered)
                    .tint(SafrTheme.Colors.accent)

                if onRemove != nil, previewImage != nil || previewURL != nil {
                    Button("Remove", role: .destructive, action: { onRemove?() })
                        .buttonStyle(.bordered)
                }
            }
            .font(.caption.weight(.semibold))

            if isUploading {
                HStack(spacing: SafrTheme.Spacing.sm) {
                    ProgressView().tint(SafrTheme.Colors.accent)
                    Text("Uploading…")
                        .font(.caption)
                        .foregroundStyle(SafrTheme.Colors.textSecondary)
                }
            }
        }
        .padding(SafrTheme.Spacing.md)
        .background(SafrTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: SafrTheme.Radius.sm))
    }
}
