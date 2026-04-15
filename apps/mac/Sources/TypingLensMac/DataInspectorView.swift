import AppKit
import Capture
import SwiftUI

struct DataInspectorView: View {
    @ObservedObject var captureService: CaptureService

    @State private var descriptors: [CaptureService.StoreFileDescriptor] = []
    @State private var statusMessage: String?
    @State private var isPresentingDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Local data inspector")
                        .font(.title2.weight(.semibold))
                    Text("Everything Typing Lens persists, in one place.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(descriptors) { descriptor in
                        descriptorRow(descriptor)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityLabel("Status: \(statusMessage)")
            }

            HStack(spacing: 12) {
                Button {
                    refreshDescriptors()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .accessibilityHint("Re-reads file sizes and modification timestamps")

                Spacer()

                Button {
                    runExportFlow()
                } label: {
                    Label("Export all data...", systemImage: "square.and.arrow.up")
                }
                .accessibilityHint("Copies every persisted file to a folder you choose")

                Button(role: .destructive) {
                    isPresentingDeleteConfirmation = true
                } label: {
                    Label("Delete all data...", systemImage: "trash")
                }
                .tint(.red)
                .accessibilityHint("Permanently removes every locally persisted file")
            }
        }
        .padding(24)
        .frame(width: 640, height: 460)
        .onAppear { refreshDescriptors() }
        .alert("Delete all local data?", isPresented: $isPresentingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete everything", role: .destructive) { runDeleteFlow() }
        } message: {
            Text("This removes your typing profile, manual exclusions, and the practice evidence ledger. The app will return to a fresh state. This cannot be undone.")
        }
    }

    private func descriptorRow(_ descriptor: CaptureService.StoreFileDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(descriptor.label)
                    .font(.headline)
                Spacer()
                if descriptor.exists, let size = descriptor.sizeBytes {
                    Text(formattedSize(size))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text("(empty)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Text(descriptor.path)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
            if let modified = descriptor.lastModified {
                Text("Last modified \(modified.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(descriptor.label). \(descriptor.exists ? formattedSize(descriptor.sizeBytes ?? 0) : "Empty"). Path \(descriptor.path).")
    }

    private func refreshDescriptors() {
        descriptors = captureService.currentStoreFileDescriptors()
    }

    private func runExportFlow() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Export Folder"
        panel.title = "Export Typing Lens data"
        panel.message = "Pick a folder to copy your local data files into."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let written = try captureService.exportAllStores(to: url)
            statusMessage = "Exported \(written.count) file\(written.count == 1 ? "" : "s") to \(url.lastPathComponent)."
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
        }
        refreshDescriptors()
    }

    private func runDeleteFlow() {
        do {
            try captureService.deleteAllStoredData()
            statusMessage = "All local data deleted."
        } catch {
            statusMessage = "Delete failed: \(error.localizedDescription)"
        }
        refreshDescriptors()
    }

    private func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
