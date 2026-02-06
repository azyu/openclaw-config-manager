import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class ConfigViewModel {
    // State
    var selectedPrimary: String = ""
    var selectedFallbacks: [String] = []
    var availableModels: [ModelInfo] { ModelCatalog.availableModels }
    
    // Status
    var statusMessage: String = ""
    var lastError: Error?
    var showConflictAlert: Bool = false
    var isLoading: Bool = false
    var isDirty: Bool = false
    var loadedAt: Date?
    var savedAt: Date?
    var configFileModificationDate: Date?
    var lastUpdated: Date?
    
    // Gateway Status
    var gatewayOnline: Bool = false
    var gatewayLastChecked: Date?
    private var gatewayCheckTask: Task<Void, Never>?
    
    // Internal
    private var document: ConfigDocument = ConfigDocument()
    private var originalSelection: ModelSelection?
    
    init() {
        load()
        startGatewayHealthCheck()
        lastUpdated = Date()
    }
    
    /// Load config from disk
    func load() {
        isLoading = true
        defer { isLoading = false }
        do {
            document = try ConfigFileManager.load()
            
            if let attributes = try? FileManager.default.attributesOfItem(atPath: ConfigFileManager.configURL.path),
               let date = attributes[.modificationDate] as? Date {
                configFileModificationDate = date
            }
            
            ModelCatalog.discoverModels(from: document.root)
            
            let (selection, warning) = ConfigModelAccess.readModelSelection(from: document.root)
            selectedPrimary = selection.primary
            selectedFallbacks = selection.fallbacks
            originalSelection = selection
            isDirty = false
            loadedAt = Date()
            lastError = nil
            statusMessage = warning ?? "Loaded"
        } catch {
            lastError = error
            statusMessage = "Load failed: \(error.localizedDescription)"
        }
    }
    
    func reload() {
        load()
        Task { await checkGatewayHealth() }
        lastUpdated = Date()
    }
    
    /// Save current selection to disk
    func save(force: Bool = false) {
        let selection = ModelSelection(primary: selectedPrimary, fallbacks: selectedFallbacks).normalized()
        guard !selection.primary.isEmpty else {
            statusMessage = "Primary model is required"
            return
        }
        
        if !force {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: ConfigFileManager.configURL.path),
               let currentMtime = attributes[.modificationDate] as? Date,
               let lastMtime = configFileModificationDate,
               currentMtime > lastMtime {
                showConflictAlert = true
                return
            }
        }
        
        do {
            ConfigModelAccess.writeModelSelection(selection, to: &document.root)
            try ConfigFileManager.save(document)
            
            if let attributes = try? FileManager.default.attributesOfItem(atPath: ConfigFileManager.configURL.path),
               let date = attributes[.modificationDate] as? Date {
                configFileModificationDate = date
            }
            
            originalSelection = selection
            isDirty = false
            savedAt = Date()
            lastError = nil
            statusMessage = "Saved successfully"
        } catch {
            lastError = error
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }
    
    /// Check if current state differs from loaded state
    func updateDirtyState() {
        let current = ModelSelection(primary: selectedPrimary, fallbacks: selectedFallbacks).normalized()
        isDirty = current != originalSelection
    }
    
    // Fallback management
    func addFallback() {
        selectedFallbacks.append("")
        updateDirtyState()
    }
    
    func removeFallback(at index: Int) {
        guard selectedFallbacks.indices.contains(index) else { return }
        selectedFallbacks.remove(at: index)
        updateDirtyState()
    }
    
    func moveFallback(from source: IndexSet, to destination: Int) {
        selectedFallbacks.move(fromOffsets: source, toOffset: destination)
        updateDirtyState()
    }
    
    func startGatewayHealthCheck() {
        gatewayCheckTask?.cancel()
        gatewayCheckTask = Task {
            while !Task.isCancelled {
                await checkGatewayHealth()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }
    
    func checkGatewayHealth() async {
        let url = URL(string: "http://127.0.0.1:18789/")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                gatewayOnline = (200...299).contains(httpResponse.statusCode)
            } else {
                gatewayOnline = false
            }
        } catch {
            gatewayOnline = false
        }
        gatewayLastChecked = Date()
    }
}
