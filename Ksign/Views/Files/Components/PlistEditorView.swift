//
//  PlistEditorView.swift
//  Ksign
//
//  Created by Nagata Asami on 5/22/25.
//

import SwiftUI

struct PlistEditorView: View {
    let fileURL: URL
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel = PlistEditorViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            contentView
        }
        .onAppear {
            viewModel.loadPlist(from: fileURL)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private var headerView: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.accentColor)
            }
            
            Spacer()
            
            Text(fileURL.lastPathComponent)
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button {
                viewModel.savePlist()
            } label: {
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private var contentView: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading plist...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text("Error")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.plistItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("Empty Property List")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("This property list contains no items")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                plistContentView
            }
        }
    }
    
    private var plistContentView: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Root Dictionary")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("\(viewModel.plistItems.count) item\(viewModel.plistItems.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            
            List {
                ForEach(viewModel.plistItems) { item in
                    PlistItemRow(item: item)
                }
            }
            .listStyle(.plain)
        }
    }
}

struct PlistItemRow: View {
    let item: PlistItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.key)
                .font(.body)
                .fontWeight(.medium)
            
            HStack {
                Text(item.type)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .foregroundColor(.accentColor)
                    .cornerRadius(4)
                Spacer()
                Text(item.displayValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
class PlistEditorViewModel: ObservableObject {
    
    @Published var plistItems: [PlistItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var fileURL: URL?
    private var plistDict: [String: Any] = [:]
    
    func loadPlist(from url: URL) {
        print("PlistEditorViewModel.loadPlist called with: \(url.path)")
        fileURL = url
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let data = try Data(contentsOf: url)
                
                var format = PropertyListSerialization.PropertyListFormat.xml
                if let dict = try PropertyListSerialization.propertyList(
                    from: data,
                    options: .mutableContainersAndLeaves,
                    format: &format
                ) as? [String: Any] {
                    
                    await MainActor.run {
                        plistDict = dict
                        _processPlistData()
                        isLoading = false
                        print("PlistEditorViewModel: Successfully loaded \(plistItems.count) items")
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "The file is not a valid property list."
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load property list: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    func savePlist() {
        guard let fileURL = fileURL else { return }
        
        Task {
            do {
                let data = try PropertyListSerialization.data(
                    fromPropertyList: plistDict,
                    format: .xml,
                    options: 0
                )
                try data.write(to: fileURL)
                print("Plist saved successfully")
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save property list: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func _processPlistData() {
        plistItems = plistDict.map { key, value in
            let type = _getTypeString(for: value)
            let displayValue = _getDisplayValue(for: value)
            return PlistItem(
                key: key,
                value: String(describing: value),
                type: type,
                displayValue: displayValue
            )
        }.sorted { $0.key < $1.key }
    }
    
    private func _getTypeString(for value: Any) -> String {
        switch value {
        case is String:
            return "String"
        case is Int:
            return "Integer"
        case is Double, is Float:
            return "Number"
        case is Bool:
            return "Boolean"
        case is Date:
            return "Date"
        case is Data:
            return "Data"
        case is [Any]:
            return "Array"
        case is [String: Any]:
            return "Dictionary"
        default:
            return "Unknown"
        }
    }
    
    private func _getDisplayValue(for value: Any) -> String {
        switch value {
        case let boolValue as Bool:
            return boolValue ? "YES" : "NO"
        case let dataValue as Data:
            return "(\(dataValue.count) bytes)"
        case let arrayValue as [Any]:
            return "(\(arrayValue.count) items)"
        case let dictValue as [String: Any]:
            return "(\(dictValue.count) keys)"
        default:
            let stringValue = String(describing: value)
            return stringValue.count > 50 ? String(stringValue.prefix(50)) + "..." : stringValue
        }
    }
}

struct PlistItem: Identifiable {
    let id = UUID()
    let key: String
    let value: String
    let type: String
    let displayValue: String
}
