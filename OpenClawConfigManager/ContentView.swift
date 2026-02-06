import SwiftUI

struct ContentView: View {
    @State private var viewModel = ConfigViewModel()
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Button {
                        viewModel.reload()
                    } label: {
                        Label("Reload", systemImage: "arrow.clockwise")
                    }
                    .help("Discard unsaved changes and reload from disk")
                    .accessibilityIdentifier("reloadButton")
                    
                    Spacer()
                    
                    Button {
                        viewModel.save()
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .help("Save changes to config file (creates backup)")
                    .disabled(viewModel.selectedPrimary.isEmpty)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("saveButton")
                    
                    Spacer()
                    
                    Button(role: .destructive) {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Label("Quit", systemImage: "power")
                    }
                }
            }
            
            Section("Primary Model") {
                Picker("Model", selection: $viewModel.selectedPrimary) {
                    Text("Select a model...").tag("")
                    ForEach(ModelCatalog.availableModels) { model in
                        Text(model.id)
                            .tag(model.id)
                    }
                    if !viewModel.selectedPrimary.isEmpty && 
                       !ModelCatalog.availableModels.contains(where: { $0.id == viewModel.selectedPrimary }) {
                        Text("\(viewModel.selectedPrimary) (Unknown)")
                            .tag(viewModel.selectedPrimary)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("primaryModelPicker")
                .onChange(of: viewModel.selectedPrimary) { viewModel.updateDirtyState() }
            }
            
            Section("Fallback Models") {
                if viewModel.selectedFallbacks.isEmpty {
                    Text("No fallback models configured")
                        .foregroundStyle(.secondary)
                } else {
                    List {
                        ForEach(viewModel.selectedFallbacks.indices, id: \.self) { index in
                            FallbackRow(
                                selection: $viewModel.selectedFallbacks[index],
                                onRemove: { viewModel.removeFallback(at: index) }
                            )
                            .onChange(of: viewModel.selectedFallbacks[index]) { viewModel.updateDirtyState() }
                        }
                        .onMove { viewModel.moveFallback(from: $0, to: $1) }
                        .onDelete { viewModel.removeFallback(at: $0.first!) }
                    }
                }
                
                Button {
                    viewModel.addFallback()
                } label: {
                    Label("Add Fallback", systemImage: "plus.circle")
                }
                .accessibilityIdentifier("addFallbackButton")
            }
            
            Section("Editing") {
                LabeledContent("File") {
                    Text(ConfigFileManager.configURL.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Text("Backups are created before each save")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Section("Status") {
                HStack {
                    if viewModel.isDirty {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text("Unsaved changes")
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text(viewModel.statusMessage)
                    }
                }
                
                HStack {
                    if let loadedAt = viewModel.loadedAt {
                        Text("Loaded: \(loadedAt.formatted(date: .omitted, time: .shortened))")
                    }
                    Spacer()
                    if let savedAt = viewModel.savedAt {
                        Text("Saved: \(savedAt.formatted(date: .omitted, time: .shortened))")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("statusLabel")
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 640)
        .alert("Error", isPresented: Binding(
            get: { viewModel.lastError != nil },
            set: { if !$0 { viewModel.lastError = nil } }
        )) {
            Button("OK") { viewModel.lastError = nil }
        } message: {
            Text(viewModel.lastError?.localizedDescription ?? "")
        }
        .accessibilityIdentifier("errorAlert")
        .alert("File Modified Externally", isPresented: $viewModel.showConflictAlert) {
            Button("Overwrite", role: .destructive) {
                viewModel.save(force: true)
                viewModel.showConflictAlert = false
            }
            Button("Cancel", role: .cancel) {
                viewModel.showConflictAlert = false
            }
        } message: {
            Text("The configuration file has been modified by another process. Do you want to overwrite it?")
        }
        .onAppear {
            // Ensure config is loaded when popover appears
            if viewModel.selectedPrimary.isEmpty && viewModel.lastError == nil {
                viewModel.reload()
            }
        }
    }
}

struct FallbackRow: View {
    @Binding var selection: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Picker("Fallback", selection: $selection) {
                Text("Select...").tag("")
                ForEach(ModelCatalog.availableModels) { model in
                    Text(model.id).tag(model.id)
                }
                if !selection.isEmpty && !ModelCatalog.availableModels.contains(where: { $0.id == selection }) {
                    Text("\(selection) (Unknown)").tag(selection)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            
            Button(role: .destructive) {
                onRemove()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }
}
