//
//  EmergencyContactsView.swift
//  Safr
//

import SwiftUI

struct EmergencyContactsView: View {
    @Environment(SessionManager.self) private var session

    @State private var contacts: [EmergencyContact] = []
    @State private var isRefreshing = false
    @State private var isSaving = false
    @State private var deletingId: String?
    @State private var errorMessage: String?
    @State private var contactToDelete: EmergencyContact?

    @State private var name = ""
    @State private var phoneNumber = ""
    @State private var relationship = ""
    @State private var isPrimary = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SafrTheme.Spacing.lg) {
                addForm

                if contacts.isEmpty && !isRefreshing {
                    Text("No emergency contacts yet. Add someone Safr can notify during SOS.")
                        .font(.subheadline)
                        .foregroundStyle(SafrTheme.Colors.textSecondary)
                } else {
                    contactsList
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
        .navigationTitle("Emergency contacts")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadContacts()
        }
        .task {
            await loadContacts()
        }
        .alert("Remove contact?", isPresented: deleteAlertBinding) {
            Button("Cancel", role: .cancel) {
                contactToDelete = nil
            }
            Button("Remove", role: .destructive) {
                if let contact = contactToDelete {
                    Task { await deleteContact(contact) }
                }
                contactToDelete = nil
            }
        } message: {
            if let contact = contactToDelete {
                Text("Remove \(contact.name) from your emergency contacts?")
            }
        }
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { contactToDelete != nil },
            set: { isPresented in
                if !isPresented { contactToDelete = nil }
            }
        )
    }

    private var addForm: some View {
        InfoCard(title: "Add contact") {
            SafrTextField(title: "Name", text: $name, textContentType: .name)
            SafrTextField(
                title: "Phone (E.164, e.g. +18761234567)",
                text: $phoneNumber,
                keyboardType: .phonePad,
                textContentType: .telephoneNumber
            )
            SafrTextField(title: "Relationship (optional)", text: $relationship)

            Toggle(isOn: $isPrimary) {
                Text("Primary contact")
                    .foregroundStyle(SafrTheme.Colors.textPrimary)
            }
            .tint(SafrTheme.Colors.accent)

            SafrPrimaryButton(title: "Save contact", isLoading: isSaving, isDisabled: !canSave) {
                Task { await addContact() }
            }
        }
    }

    private var contactsList: some View {
        InfoCard(title: "Saved contacts") {
            ForEach(contacts) { contact in
                HStack(alignment: .top, spacing: SafrTheme.Spacing.md) {
                    VStack(alignment: .leading, spacing: SafrTheme.Spacing.xs) {
                        HStack(spacing: SafrTheme.Spacing.sm) {
                            Text(contact.name)
                                .font(.headline)
                                .foregroundStyle(SafrTheme.Colors.textPrimary)
                            if contact.isPrimary == true {
                                StatusChip(label: "Primary", tone: .safe)
                            }
                        }
                        Text(contact.phoneNumber)
                            .foregroundStyle(SafrTheme.Colors.textSecondary)
                        if let relationship = contact.relationship, !relationship.isEmpty {
                            Text(relationship)
                                .font(.caption)
                                .foregroundStyle(SafrTheme.Colors.textSecondary)
                        }
                    }

                    Spacer()

                    Button(role: .destructive) {
                        contactToDelete = contact
                    } label: {
                        if deletingId == contact.id {
                            ProgressView().tint(SafrTheme.Colors.danger)
                        } else {
                            Image(systemName: "trash")
                                .foregroundStyle(SafrTheme.Colors.danger)
                        }
                    }
                    .disabled(deletingId != nil)
                }
                .padding(.vertical, SafrTheme.Spacing.xs)
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isPhoneValid(phoneNumber)
    }

    private func isPhoneValid(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let regex = try? NSRegularExpression(pattern: "^\\+?[1-9]\\d{7,14}$") else { return false }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        return regex.firstMatch(in: trimmed, range: range) != nil
    }

    private func loadContacts() async {
        guard let token = session.accessToken else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            contacts = try await APIClient.shared.listEmergencyContacts(token: token)
            errorMessage = nil
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addContact() async {
        guard let token = session.accessToken else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let contact = try await APIClient.shared.addEmergencyContact(
                token: token,
                request: AddEmergencyContactRequest(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                    relationship: relationship.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? nil
                        : relationship.trimmingCharacters(in: .whitespacesAndNewlines),
                    isPrimary: isPrimary ? true : nil
                )
            )

            var remaining = contacts.filter { $0.id != contact.id }
            if contact.isPrimary == true {
                remaining = remaining.map { entry in
                    var updated = entry
                    updated.isPrimary = false
                    return updated
                }
            }
            contacts = [contact] + remaining

            name = ""
            phoneNumber = ""
            relationship = ""
            isPrimary = false
            errorMessage = nil
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteContact(_ contact: EmergencyContact) async {
        guard let token = session.accessToken else { return }
        deletingId = contact.id
        defer { deletingId = nil }

        do {
            _ = try await APIClient.shared.deleteEmergencyContact(token: token, contactId: contact.id)
            contacts.removeAll { $0.id == contact.id }
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
        EmergencyContactsView()
    }
    .environment(SessionManager())
}
