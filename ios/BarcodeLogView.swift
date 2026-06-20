//
//  BarcodeLogView.swift
//  MealTracker
//
//  Debug-only viewer for the barcode structured log.
//

import SwiftUI
import Combine

#if DEBUG
struct BarcodeLogView: View {
    @State private var events: [BarcodeLogEvent] = []
    @State private var cancellable: AnyCancellable?

    // Expanded states per event
    @State private var expandedIDs: Set<UUID> = []

    // Fallback share sheet state for iOS < 16
    @State private var showingShareSheet = false

    var body: some View {
        VStack(spacing: 0) {
            if events.isEmpty {
                Text(NSLocalizedString("barcode_log.empty", comment: "No log entries yet."))
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
                                        if let src = evt.sourceJSON, !src.isEmpty {
                                            GroupBox(label: Text(NSLocalizedString("barcode_log.group.source", comment: "Source"))) {
                                                ScrollView(.horizontal, showsIndicators: true) {
                                                    Text(src)
                                                        .font(.caption2.monospaced())
                                                        .foregroundStyle(.secondary)
                                                        .textSelection(.enabled)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                }
                                            }
                                        }

                                        if let steps = evt.conversions, !steps.isEmpty {
                                            GroupBox(label: Text(NSLocalizedString("barcode_log.group.conversions", comment: "Conversions"))) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    ForEach(steps.indices, id: \.self) { i in
                                                        Text("• " + steps[i])
                                                            .font(.caption2)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                        }

                                        if let entry = evt.entry, let pretty = BarcodeLogPretty.prettyEntry(entry) {
                                            GroupBox(label: Text(NSLocalizedString("barcode_log.group.entry", comment: "Entry"))) {
                                                ScrollView(.horizontal, showsIndicators: true) {
                                                    Text(pretty)
                                                        .font(.caption2.monospaced())
                                                        .foregroundStyle(.secondary)
                                                        .textSelection(.enabled)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                }
                                            }
                                        }

                                        if let err = evt.error, !err.isEmpty {
                                            GroupBox(label: Text(NSLocalizedString("barcode_log.group.error", comment: "Error"))) {
                                                Text(err)
                                                    .font(.caption2)
                                                    .foregroundStyle(.red)
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
        .navigationTitle(NSLocalizedString("barcode_log.title", comment: "Barcode Log"))
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    UIPasteboard.general.string = exportText()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .accessibilityLabel(NSLocalizedString("barcode_log.copy", comment: "Copy"))

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
                    Task { await BarcodeLogStore.shared.clear() }
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(NSLocalizedString("barcode_log.clear", comment: "Clear"))
            }
        }
        .onAppear {
            Task {
                let current = await BarcodeLogStore.shared.snapshotEvents()
                await MainActor.run { self.events = current }
            }
            self.cancellable = BarcodeLogStore.shared.eventsPublisher
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

    private func header(for evt: BarcodeLogEvent) -> some View {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SSS"
        let ts = df.string(from: evt.timestamp)

        let code: String = {
            if let norm = evt.codeNormalized, !norm.isEmpty { return norm }
            if let raw = evt.codeRaw, !raw.isEmpty { return raw }
            return NSLocalizedString("barcode_log.no_code", comment: "No code")
        }()

        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(ts)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.primary)

            stageBadge(evt.stage)

            Text(localizedStageName(evt.stage))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(code)
                .font(.caption2.monospaced())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func stageBadge(_ stage: BarcodeLogStage) -> some View {
        let (label, color): (String, Color) = {
            switch stage {
            case .scanDetected:   return (NSLocalizedString("barcode_log.stage.scan", comment: "Scan"), .blue)
            case .normalizeCode:  return (NSLocalizedString("barcode_log.stage.normalize", comment: "Normalize"), .teal)
            case .localLookupHit: return (NSLocalizedString("barcode_log.stage.local_hit", comment: "Local Hit"), .green)
            case .localLookupMiss:return (NSLocalizedString("barcode_log.stage.local_miss", comment: "Local Miss"), .orange)
            case .offFetchV2:     return (NSLocalizedString("barcode_log.stage.off_v2", comment: "OFF v2"), .indigo)
            case .offFetchV1:     return (NSLocalizedString("barcode_log.stage.off_v1", comment: "OFF v1"), .purple)
            case .offDecodeError: return (NSLocalizedString("barcode_log.stage.off_error", comment: "OFF Error"), .red)
            case .offMapStart:    return (NSLocalizedString("barcode_log.stage.map_start", comment: "Map Start"), .gray)
            case .offConversion:  return (NSLocalizedString("barcode_log.stage.convert", comment: "Convert"), .brown)
            case .offMapResult:   return (NSLocalizedString("barcode_log.stage.map_result", comment: "Map Result"), .mint)
            case .upsertAttempt:  return (NSLocalizedString("barcode_log.stage.upsert", comment: "Upsert"), .cyan)
            case .upsertSuccess:  return (NSLocalizedString("barcode_log.stage.saved", comment: "Saved"), .green)
            case .upsertFailure:  return (NSLocalizedString("barcode_log.stage.save_error", comment: "Save Error"), .red)
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

    private func localizedStageName(_ stage: BarcodeLogStage) -> String {
        switch stage {
        case .scanDetected:   return NSLocalizedString("barcode_log.stage.scan", comment: "Scan")
        case .normalizeCode:  return NSLocalizedString("barcode_log.stage.normalize", comment: "Normalize")
        case .localLookupHit: return NSLocalizedString("barcode_log.stage.local_hit", comment: "Local Hit")
        case .localLookupMiss:return NSLocalizedString("barcode_log.stage.local_miss", comment: "Local Miss")
        case .offFetchV2:     return NSLocalizedString("barcode_log.stage.off_v2", comment: "OFF v2")
        case .offFetchV1:     return NSLocalizedString("barcode_log.stage.off_v1", comment: "OFF v1")
        case .offDecodeError: return NSLocalizedString("barcode_log.stage.off_error", comment: "OFF Error")
        case .offMapStart:    return NSLocalizedString("barcode_log.stage.map_start", comment: "Map Start")
        case .offConversion:  return NSLocalizedString("barcode_log.stage.convert", comment: "Convert")
        case .offMapResult:   return NSLocalizedString("barcode_log.stage.map_result", comment: "Map Result")
        case .upsertAttempt:  return NSLocalizedString("barcode_log.stage.upsert", comment: "Upsert")
        case .upsertSuccess:  return NSLocalizedString("barcode_log.stage.saved", comment: "Saved")
        case .upsertFailure:  return NSLocalizedString("barcode_log.stage.save_error", comment: "Save Error")
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
            if let c = e.codeNormalized ?? e.codeRaw { header += " code=\(c)" }
            out.append(header)
            if let src = e.sourceJSON, !src.isEmpty {
                out.append(NSLocalizedString("barcode_log.export.source", comment: "Source:"))
                out.append(src)
            }
            if let steps = e.conversions, !steps.isEmpty {
                out.append(NSLocalizedString("barcode_log.export.conversions", comment: "Conversions:"))
                for s in steps { out.append(" - \(s)") }
            }
            if let entry = e.entry, let pretty = BarcodeLogPretty.prettyEntry(entry) {
                out.append(NSLocalizedString("barcode_log.export.entry", comment: "Entry:"))
                out.append(pretty)
            }
            if let err = e.error, !err.isEmpty {
                let prefix = NSLocalizedString("barcode_log.export.error_prefix", comment: "Error: ")
                out.append(prefix + err)
            }
            out.append("") // blank line
        }
        return out.joined(separator: "\n")
    }
}

// Simple UIActivityViewController wrapper for SwiftUI
private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
