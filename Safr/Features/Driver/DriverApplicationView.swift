//
//  DriverApplicationView.swift
//  Safr
//

import SwiftUI

struct DriverApplicationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session

    @State private var licenseNumber = ""
    @State private var licenseExpiry = ""
    @State private var serviceArea = ""
    @State private var taxiType: DriverTaxiType = .route
    @State private var serviceRoute = ""
    @State private var originArea = ""
    @State private var destinationArea = ""
    @State private var vehicleMake = ""
    @State private var vehicleModel = ""
    @State private var vehicleColor = ""
    @State private var plateNumber = ""

    @State private var licenseImageURL: String?
    @State private var governmentIdImageURL: String?
    @State private var vehiclePhotoURL: String?

    @State private var licensePreview: UIImage?
    @State private var governmentIdPreview: UIImage?
    @State private var vehiclePhotoPreview: UIImage?

    @State private var uploadingField: UploadField?
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    @State private var imagePickerSource: ImagePickerView.Source?
    @State private var activeUploadField: UploadField?

    private enum UploadField: String {
        case license
        case governmentId
        case vehiclePhoto
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SafrTheme.Spacing.lg) {
                Text("Complete your driver application so Safr can review your documents.")
                    .font(.subheadline)
                    .foregroundStyle(SafrTheme.Colors.textSecondary)

                if session.user?.avatarUrl == nil {
                    NavigationLink {
                        ProfilePhotoView()
                    } label: {
                        Text("Add a profile photo before submitting")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SafrTheme.Colors.accentWarm)
                    }
                }

                InfoCard(title: "License & service") {
                    SafrTextField(title: "License number", text: $licenseNumber)
                    SafrTextField(title: "License expiry (YYYY-MM-DD)", text: $licenseExpiry)
                    SafrTextField(title: "Service area", text: $serviceArea)

                    Picker("Taxi type", selection: $taxiType) {
                        ForEach(DriverTaxiType.allCases, id: \.self) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(SafrTheme.Colors.accent)

                    SafrTextField(title: "Service route", text: $serviceRoute)
                    SafrTextField(title: "Origin area", text: $originArea)
                    SafrTextField(title: "Destination area", text: $destinationArea)
                }

                InfoCard(title: "Vehicle") {
                    SafrTextField(title: "Make", text: $vehicleMake)
                    SafrTextField(title: "Model", text: $vehicleModel)
                    SafrTextField(title: "Color", text: $vehicleColor)
                    SafrTextField(title: "Plate number", text: $plateNumber)
                }

                InfoCard(title: "Documents") {
                    uploadField(
                        label: "License image",
                        field: .license,
                        previewURL: licenseImageURL,
                        previewImage: licensePreview
                    )
                    uploadField(
                        label: "Government ID",
                        field: .governmentId,
                        previewURL: governmentIdImageURL,
                        previewImage: governmentIdPreview
                    )
                    uploadField(
                        label: "Vehicle photo",
                        field: .vehiclePhoto,
                        previewURL: vehiclePhotoURL,
                        previewImage: vehiclePhotoPreview
                    )
                }

                if let successMessage {
                    Text(successMessage)
                        .foregroundStyle(SafrTheme.Colors.success)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(SafrTheme.Colors.danger)
                }

                SafrPrimaryButton(title: "Submit application", isLoading: isSubmitting) {
                    Task { await submitApplication() }
                }
            }
            .padding(SafrTheme.Spacing.lg)
        }
        .safrScreenBackground()
        .navigationTitle("Driver application")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadProfile() }
        .sheet(isPresented: Binding(
            get: { imagePickerSource != nil },
            set: { isPresented in
                if !isPresented {
                    imagePickerSource = nil
                    activeUploadField = nil
                }
            }
        )) {
            if let source = imagePickerSource {
                ImagePickerView(source: source) { image in
                    Task { await uploadImage(image, for: activeUploadField) }
                }
            }
        }
    }

    @ViewBuilder
    private func uploadField(
        label: String,
        field: UploadField,
        previewURL: String?,
        previewImage: UIImage?
    ) -> some View {
        DocumentUploadField(
            label: label,
            helper: "JPEG or PNG up to 8 MB.",
            previewURL: previewURL,
            previewImage: previewImage,
            fileLabel: previewURL?.split(separator: "/").last.map(String.init),
            isUploading: uploadingField == field,
            onTakePhoto: {
                activeUploadField = field
                imagePickerSource = .camera
            },
            onChooseFromLibrary: {
                activeUploadField = field
                imagePickerSource = .photoLibrary
            },
            onRemove: {
                switch field {
                case .license:
                    licenseImageURL = nil
                    licensePreview = nil
                case .governmentId:
                    governmentIdImageURL = nil
                    governmentIdPreview = nil
                case .vehiclePhoto:
                    vehiclePhotoURL = nil
                    vehiclePhotoPreview = nil
                }
            }
        )
    }

    private func loadProfile() async {
        guard let token = session.accessToken else { return }
        guard let profile = try? await APIClient.shared.getMyDriverProfile(token: token) else { return }

        licenseNumber = profile.licenseNumber ?? ""
        licenseExpiry = profile.licenseExpiryDate ?? ""
        serviceArea = profile.serviceArea ?? ""
        taxiType = profile.taxiType ?? .route
        serviceRoute = profile.serviceRoute ?? ""
        originArea = profile.originArea ?? ""
        destinationArea = profile.destinationArea ?? ""
        vehicleMake = profile.vehicleMake ?? ""
        vehicleModel = profile.vehicleModel ?? ""
        vehicleColor = profile.vehicleColor ?? ""
        plateNumber = profile.plateNumber ?? ""
        licenseImageURL = profile.licenseImageUrl
        governmentIdImageURL = profile.governmentIdImageUrl
        vehiclePhotoURL = profile.vehiclePhotoUrl
    }

    private func uploadImage(_ image: UIImage, for field: UploadField?) async {
        guard let token = session.accessToken, let field else { return }
        guard let data = image.jpegData(compressionQuality: 0.75) else { return }

        uploadingField = field
        defer { uploadingField = nil }

        do {
            let signature = try await APIClient.shared.getDriverDocumentUploadSignature(token: token)
            let secureURL = try await CloudinaryUploadService.upload(
                signature: signature,
                imageData: data,
                fileName: "\(field.rawValue).jpg",
                mimeType: "image/jpeg"
            )

            switch field {
            case .license:
                licenseImageURL = secureURL
                licensePreview = image
            case .governmentId:
                governmentIdImageURL = secureURL
                governmentIdPreview = image
            case .vehiclePhoto:
                vehiclePhotoURL = secureURL
                vehiclePhotoPreview = image
            }
            activeUploadField = nil
            imagePickerSource = nil
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitApplication() async {
        guard let token = session.accessToken else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            _ = try await APIClient.shared.updateMyDriverProfile(
                token: token,
                request: UpdateDriverProfileRequest(
                    licenseNumber: licenseNumber.nilIfBlank,
                    licenseImageUrl: licenseImageURL,
                    licenseExpiryDate: licenseExpiry.nilIfBlank,
                    governmentIdImageUrl: governmentIdImageURL,
                    vehicleMake: vehicleMake.nilIfBlank,
                    vehicleModel: vehicleModel.nilIfBlank,
                    vehicleColor: vehicleColor.nilIfBlank,
                    plateNumber: plateNumber.nilIfBlank,
                    vehiclePhotoUrl: vehiclePhotoURL,
                    serviceArea: serviceArea.nilIfBlank,
                    taxiType: taxiType,
                    serviceRoute: serviceRoute.nilIfBlank,
                    originArea: originArea.nilIfBlank,
                    destinationArea: destinationArea.nilIfBlank
                )
            )
            try await session.refreshUser()
            successMessage = "Application submitted for review."
            errorMessage = nil
            dismiss()
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
