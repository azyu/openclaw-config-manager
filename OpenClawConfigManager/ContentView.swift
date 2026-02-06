import SwiftUI

struct ContentView: View {
    @State private var viewModel = ConfigViewModel()
    
    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    HStack {
                        Text("OpenClaw Config Manager")
                            .font(.headline)
                        Spacer()
                        Button {
                            if let url = URL(string: "https://openclaw.ai") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .buttonStyle(.plain)
                        .help("Visit OpenClaw website")
                    }
                    
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
            
            Section("Status") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(viewModel.gatewayOnline ? .green : .red)
                            .font(.system(size: 8))
                        Text("OpenClaw Gateway")
                        Spacer()
                        Text(viewModel.gatewayOnline ? "online" : "offline")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(viewModel.isDirty ? .orange : .green)
                            .font(.system(size: 8))
                        Text("Config File")
                        Spacer()
                        Button {
                            NSWorkspace.shared.open(ConfigFileManager.configURL)
                        } label: {
                            Text(ConfigFileManager.configURL.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Open config file")
                    }
                    
                    if let lastUpdated = viewModel.lastUpdated {
                        HStack {
                            Spacer()
                            Text("last updated: \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .accessibilityIdentifier("statusLabel")
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 640)
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
