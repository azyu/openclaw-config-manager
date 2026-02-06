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
    
    // Internal
    private var document: ConfigDocument = ConfigDocument()
    private var originalSelection: ModelSelection?
    
    init() {
        load()
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
    
    /// Reload from disk, discarding unsaved changes
    func reload() { load() }
    
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
}
