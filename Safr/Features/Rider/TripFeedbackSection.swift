//
//  TripFeedbackSection.swift
//  Safr
//

import SwiftUI

struct TripFeedbackSection: View {
    let existingFeedback: TripFeedback?
    @Binding var rating: Int
    @Binding var comment: String
    @Binding var selectedTags: Set<TripFeedbackTag>
    var isSubmitting: Bool
    let onSubmit: () -> Void

    var body: some View {
        InfoCard(title: "Trip feedback") {
            if let existingFeedback {
                readOnlySummary(existingFeedback)
            } else {
                editableForm
            }
        }
    }

    @ViewBuilder
    private var editableForm: some View {
        Text("Rate your trip experience")
            .font(.subheadline)
            .foregroundStyle(SafrTheme.Colors.textSecondary)

        HStack(spacing: SafrTheme.Spacing.sm) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    rating = value
                } label: {
                    Image(systemName: value <= rating ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundStyle(value <= rating ? SafrTheme.Colors.accentWarm : SafrTheme.Colors.textSecondary)
                }
            }
        }

        FlowLayout(spacing: SafrTheme.Spacing.sm) {
            ForEach(TripFeedbackTag.allCases, id: \.self) { tag in
                Button {
                    if selectedTags.contains(tag) {
                        selectedTags.remove(tag)
                    } else {
                        selectedTags.insert(tag)
                    }
                } label: {
                    Text(tag.label)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, SafrTheme.Spacing.sm)
                        .padding(.vertical, SafrTheme.Spacing.xs)
                        .background(selectedTags.contains(tag) ? SafrTheme.Colors.accent.opacity(0.2) : SafrTheme.Colors.surface)
                        .foregroundStyle(selectedTags.contains(tag) ? SafrTheme.Colors.accent : SafrTheme.Colors.textSecondary)
                        .clipShape(Capsule())
                }
            }
        }

        SafrTextField(title: "Comment (optional)", text: $comment)

        SafrPrimaryButton(title: "Submit feedback", isLoading: isSubmitting, isDisabled: rating < 1) {
            onSubmit()
        }
    }

    private func readOnlySummary(_ feedback: TripFeedback) -> some View {
        VStack(alignment: .leading, spacing: SafrTheme.Spacing.sm) {
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { value in
                    Image(systemName: value <= feedback.rating ? "star.fill" : "star")
                        .foregroundStyle(SafrTheme.Colors.accentWarm)
                }
            }

            if let tags = feedback.tags, !tags.isEmpty {
                Text(tags.map(\.label).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(SafrTheme.Colors.textSecondary)
            }

            if let comment = feedback.comment, !comment.isEmpty {
                Text(comment)
                    .foregroundStyle(SafrTheme.Colors.textPrimary)
            }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var frames: [CGRect] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}
