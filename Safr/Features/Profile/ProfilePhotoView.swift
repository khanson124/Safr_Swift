//
//  ProfilePhotoView.swift
//  Safr
//

import PhotosUI
import SwiftUI

struct ProfilePhotoView: View {
    @Environment(SessionManager.self) private var session

    @State private var selectedItem: PhotosPickerItem?
    @State private var pendingImageData: Data?
    @State private var pendingMimeType = "image/jpeg"
    @State private var pendingFilename = "profile-photo.jpg"
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private var isDriver: Bool { session.user?.role == .driver }

    private var guidance: String {
        if isDriver {
            return "Drivers need a clear photo before displaying QR. Riders use this photo to confirm the person in front of them."
        }
        return "Add a photo to help drivers identify you during boarding. Optional for riders but encouraged."
    }

    var body: some View {
        ScrollView {
            VStack(spacing: SafrTheme.Spacing.lg) {
                preview

                Text(guidance)
                    .font(.subheadline)
                    .foregroundStyle(SafrTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("Choose from library")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SafrTheme.Spacing.md)
                    .background(SafrTheme.Colors.surface)
                    .foregroundStyle(SafrTheme.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: SafrTheme.Radius.md))
                }

                SafrPrimaryButton(
                    title: "Upload photo",
                    isLoading: isUploading,
                    isDisabled: pendingImageData == nil
                ) {
                    Task { await uploadPhoto() }
                }

                if let successMessage {
                    Text(successMessage)
                        .font(.subheadline)
                        .foregroundStyle(SafrTheme.Colors.success)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(SafrTheme.Colors.danger)
                }
            }
            .padding(SafrTheme.Spacing.lg)
        }
        .safrScreenBackground()
        .navigationTitle("Profile photo")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedItem) { _, item in
            Task { await loadSelectedPhoto(from: item) }
        }
    }

    @ViewBuilder
    private var preview: some View {
        ZStack {
            Circle()
                .fill(SafrTheme.Colors.surface)
                .frame(width: 140, height: 140)

            if let pendingImageData, let uiImage = UIImage(data: pendingImageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 140, height: 140)
                    .clipShape(Circle())
            } else if let avatarUrl = session.user?.avatarUrl, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholderInitials
                    }
                }
                .frame(width: 140, height: 140)
                .clipShape(Circle())
            } else {
                placeholderInitials
            }
        }
    }

    private var placeholderInitials: some View {
        Text(initials)
            .font(.largeTitle.bold())
            .foregroundStyle(SafrTheme.Colors.accent)
    }

    private var initials: String {
        (session.user?.fullName ?? "U")
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }

    private func loadSelectedPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        errorMessage = nil
        successMessage = nil

        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                pendingImageData = data
                pendingMimeType = "image/jpeg"
                pendingFilename = "profile-photo.jpg"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func uploadPhoto() async {
        guard let token = session.accessToken, let data = pendingImageData else { return }
        isUploading = true
        defer { isUploading = false }

        do {
            _ = try await APIClient.shared.uploadProfilePhoto(
                token: token,
                imageData: data,
                filename: pendingFilename,
                mimeType: pendingMimeType
            )
            try await session.refreshUser()
            pendingImageData = nil
            selectedItem = nil
            successMessage = "Profile photo updated."
            errorMessage = nil
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        ProfilePhotoView()
    }
    .environment(SessionManager())
}
