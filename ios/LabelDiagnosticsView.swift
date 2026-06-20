//
//  LabelDiagnosticsView.swift
//  MealTracker
//
//  Debug-only viewer for label recognition diagnostics.
//

import SwiftUI
import Combine

#if DEBUG
struct LabelDiagnosticsView: View {
    @State private var events: [LabelDiagnosticsEvent] = []
    @State private var cancellable: AnyCancellable?

    @State private var expandedIDs: Set<UUID> = []
    @State private var showingShareSheet = false

    var body: some View {
        VStack(spacing: 0) {
            if events.isEmpty {
                Text(NSLocalizedString("label_diag.empty", comment: "No diagnostics yet."))
                    .foregroundStyle(.secondary)
                    .padding()
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(events) { evt in
                                VStack(alignment: .leading, spacing: 8) {
                                    header(for: evt)

                                    if expandedIDs.contains(evt.id) {
                                        if let msg = evt.message, !msg.isEmpty {
                                            GroupBox(label: Text(NSLocalizedString("label_diag.group.message", comment: "Message"))) {
                                                Text(msg)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                        }
                                        if let fields = evt.fieldsFilled, !fields.isEmpty {
                                            GroupBox(label: Text(NSLocalizedString("label_diag.group.fields_filled", comment: "Fields Filled"))) {
                                                Text(fields.joined(separator: ", "))
                                                    .font(.caption2.monospaced())
                                                    .foregroundStyle(.secondary)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                        }
                                    }
                                }
                                .id(evt.id)
                                .contentShape(Rectangle())
                                .onTapGesture { toggleExpanded(evt.id) }
                                .padding(12)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.tertiarySystemGroupedBackground))
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: events.count) { _ in
                        if let last = events.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("label_diag.title", comment: "Label Diagnostics"))
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    UIPasteboard.general.string = exportText()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .accessibilityLabel(NSLocalizedString("label_diag.copy", comment: "Copy"))

                if #available(iOS 16.0, *) {
                    ShareLink(items: [exportText()]) {
                        Image(systemName: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }

                Button(role: .destructive) {
                    Task { await LabelDiagnosticsStore.shared.clear() }
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(NSLocalizedString("label_diag.clear", comment: "Clear"))
            }
        }
        .onAppear {
            Task {
                let current = await LabelDiagnosticsStore.shared.snapshotEvents()
                await MainActor.run { self.events = current }
            }
            self.cancellable = LabelDiagnosticsStore.shared.eventsPublisher
                .receive(on: DispatchQueue.main)
                .sink { new in
                    self.events = new
                }
        }
        .onDisappear {
            cancellable?.cancel()
            cancellable = nil
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityView(activityItems: [exportText()])
        }
    }

    private func header(for evt: LabelDiagnosticsEvent) -> some View {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SSS"
        let ts = df.string(from: evt.timestamp)

        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(ts)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.primary)

            stageBadge(evt.stage)

            Text(summaryLine(for: evt))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)
        }
        .padding(.vertical, 2)
    }

    private func summaryLine(for e: LabelDiagnosticsEvent) -> String {
        var parts: [String] = [localizedStageName(e.stage)]
        if let deg = e.rotationDegrees { parts.append("rot=\(deg)°") }
        if let code = e.code { parts.append("code=\(code)") }
        if let len = e.textLength { parts.append("textLen=\(len)") }
        if let cnt = e.parsedFieldCount { parts.append("parsed=\(cnt)") }
        if let key = e.upsertKey { parts.append("key=\(key)") }
        return parts.joined(separator: " ")
    }

    @ViewBuilder
    private func stageBadge(_ stage: LabelDiagStage) -> some View {
        let (label, color): (String, Color) = {
            switch stage {
            case .analyzeStart:        return (NSLocalizedString("label_diag.stage.start", comment: "Start"), .blue)
            case .imagePrepared:       return (NSLocalizedString("label_diag.stage.image", comment: "Image"), .teal)
            case .rotationAttempt:     return (NSLocalizedString("label_diag.stage.rotate", comment: "Rotate"), .indigo)
            case .barcodeDecoded:      return (NSLocalizedString("label_diag.stage.barcode", comment: "Barcode"), .green)
            case .barcodeUnreadable:   return (NSLocalizedString("label_diag.stage.unreadable", comment: "Unreadable"), .orange)
            case .barcodeNone:         return (NSLocalizedString("label_diag.stage.no_barcode", comment: "No Barcode"), .gray)
            case .ocrStartFast:        return (NSLocalizedString("label_diag.stage.ocr_fast", comment: "OCR Fast"), .purple)
            case .ocrStartAccurate:    return (NSLocalizedString("label_diag.stage.ocr_accurate", comment: "OCR Acc"), .purple)
            case .ocrFinished:         return (NSLocalizedString("label_diag.stage.ocr_done", comment: "OCR Done"), .mint)
            case .parseResult:         return (NSLocalizedString("label_diag.stage.parsed", comment: "Parsed"), .cyan)
            case .applyToForm:         return (NSLocalizedString("label_diag.stage.applied", comment: "Applied"), .green)
            case .ocrUpsertAttempt:    return (NSLocalizedString("label_diag.stage.upsert", comment: "Upsert"), .brown)
            case .ocrUpsertSuccess:    return (NSLocalizedString("label_diag.stage.saved", comment: "Saved"), .green)
            case .ocrUpsertFailure:    return (NSLocalizedString("label_diag.stage.save_error", comment: "Save Err"), .red)
            case .analyzeComplete:     return (NSLocalizedString("label_diag.stage.complete", comment: "Complete"), .green)
            case .analyzeError:        return (NSLocalizedString("label_diag.stage.error", comment: "Error"), .red)
            }
        }()

        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(.white)
            .background(Capsule().fill(color))
            .accessibilityLabel(localizedStageName(stage))
    }

    private func localizedStageName(_ stage: LabelDiagStage) -> String {
        switch stage {
        case .analyzeStart:        return NSLocalizedString("label_diag.stage.start", comment: "Start")
        case .imagePrepared:       return NSLocalizedString("label_diag.stage.image", comment: "Image")
        case .rotationAttempt:     return NSLocalizedString("label_diag.stage.rotate", comment: "Rotate")
        case .barcodeDecoded:      return NSLocalizedString("label_diag.stage.barcode", comment: "Barcode")
        case .barcodeUnreadable:   return NSLocalizedString("label_diag.stage.unreadable", comment: "Unreadable")
        case .barcodeNone:         return NSLocalizedString("label_diag.stage.no_barcode", comment: "No Barcode")
        case .ocrStartFast:        return NSLocalizedString("label_diag.stage.ocr_fast", comment: "OCR Fast")
        case .ocrStartAccurate:    return NSLocalizedString("label_diag.stage.ocr_accurate", comment: "OCR Acc")
        case .ocrFinished:         return NSLocalizedString("label_diag.stage.ocr_done", comment: "OCR Done")
        case .parseResult:         return NSLocalizedString("label_diag.stage.parsed", comment: "Parsed")
        case .applyToForm:         return NSLocalizedString("label_diag.stage.applied", comment: "Applied")
        case .ocrUpsertAttempt:    return NSLocalizedString("label_diag.stage.upsert", comment: "Upsert")
        case .ocrUpsertSuccess:    return NSLocalizedString("label_diag.stage.saved", comment: "Saved")
        case .ocrUpsertFailure:    return NSLocalizedString("label_diag.stage.save_error", comment: "Save Error")
        case .analyzeComplete:     return NSLocalizedString("label_diag.stage.complete", comment: "Complete")
        case .analyzeError:        return NSLocalizedString("label_diag.stage.error", comment: "Error")
        }
    }

    private func toggleExpanded(_ id: UUID) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }

    private func exportText() -> String {
        var out: [String] = []
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        for e in events {
            var header = "[\(df.string(from: e.timestamp))] \(localizedStageName(e.stage))"
            if let deg = e.rotationDegrees { header += " rot=\(deg)" }
            if let code = e.code { header += " code=\(code)" }
            if let len = e.textLength { header += " textLen=\(len)" }
            if let cnt = e.parsedFieldCount { header += " parsed=\(cnt)" }
            if let key = e.upsertKey { header += " key=\(key)" }
            out.append(header)
            if let fields = e.fieldsFilled, !fields.isEmpty {
                out.append(NSLocalizedString("label_diag.export.fields_filled", comment: "Fields Filled:"))
                out.append(fields.joined(separator: ", "))
            }
            if let msg = e.message, !msg.isEmpty {
                out.append(NSLocalizedString("label_diag.export.message", comment: "Message:"))
                out.append(msg)
            }
            out.append("") // blank line
        }
        return out.joined(separator: "\n")
    }
}

// Simple UIActivityViewController wrapper for SwiftUI (DEBUG only)
private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
