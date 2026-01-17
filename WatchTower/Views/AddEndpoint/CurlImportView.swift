//
//  CurlImportView.swift
//  WatchTower
//

import SwiftUI
import UniformTypeIdentifiers

struct CurlImportView: View {
    let onSave: (APIEndpoint) -> Void
    let onBulkSave: ([APIEndpoint]) -> Void

    enum ImportMode: String, CaseIterable {
        case paste = "Paste"
        case file = "Import Files"
        case postman = "Postman"
    }

    @State private var importMode: ImportMode = .file
    @State private var pollingInterval: PollingInterval = .fifteenMinutes

    // Paste mode state
    @State private var curlCommand = ""
    @State private var name = ""
    @State private var parseError: String?
    @State private var parsedCommand: ParsedCurlCommand?

    // File import mode state
    @State private var importedFiles: [ImportedCurlFile] = []
    @State private var isShowingFilePicker = false

    // Postman import mode state
    @State private var postmanRequests: [ParsedPostmanRequest] = []
    @State private var isShowingPostmanFilePicker = false
    @State private var postmanCollectionName: String?
    @State private var postmanParseError: String?

    private let curlParser = CurlParserService()
    private let postmanParser = PostmanParserService()

    var body: some View {
        VStack(spacing: 0) {
            Picker("Import Mode", selection: $importMode) {
                ForEach(ImportMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            switch importMode {
            case .paste:
                pasteView
            case .file:
                fileImportView
            case .postman:
                postmanImportView
            }
        }
    }

    // MARK: - Paste Mode View

    private var pasteView: some View {
        Form {
            Section {
                TextField("Endpoint Name", text: $name)
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("Name")
            }

            Section {
                TextEditor(text: $curlCommand)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .onChange(of: curlCommand) { _, newValue in
                        parseCurlCommand(newValue)
                    }
                    .onDrop(of: [.fileURL, .plainText], isTargeted: nil) { providers in
                        handleDrop(providers: providers)
                        return true
                    }

                if let error = parseError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                if let parsed = parsedCommand {
                    parsedCommandPreview(parsed)
                }
            } header: {
                Text("cURL Command")
            } footer: {
                Text("Paste or drag a curl file here. Headers, body, and method will be auto-detected.")
            }

            Section {
                Picker("Polling Interval", selection: $pollingInterval) {
                    ForEach(PollingInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
            } header: {
                Text("Monitoring")
            }

            Section {
                Button(action: createSingleEndpoint) {
                    Text("Add Endpoint")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isPasteValid)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - File Import Mode View

    private var fileImportView: some View {
        VStack(spacing: 0) {
            // File picker button and polling interval
            HStack {
                Button(action: { isShowingFilePicker = true }) {
                    Label("Select Curl Files", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)

                Spacer()

                Picker("Polling Interval", selection: $pollingInterval) {
                    ForEach(PollingInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .frame(width: 180)
            }
            .padding()

            Divider()

            if importedFiles.isEmpty {
                emptyFileStateView
            } else {
                fileListView
            }

            Divider()

            // Import button
            HStack {
                if !importedFiles.isEmpty {
                    Button("Clear All") {
                        importedFiles.removeAll()
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                let validCount = importedFiles.filter { $0.isSelected && $0.isValid }.count
                Button("Import \(validCount) Endpoint\(validCount == 1 ? "" : "s")") {
                    importSelectedEndpoints()
                }
                .buttonStyle(.borderedProminent)
                .disabled(validCount == 0)
            }
            .padding()
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.plainText, .text, UTType(filenameExtension: "curl") ?? .plainText],
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
    }

    // MARK: - Postman Import Mode View

    private var postmanImportView: some View {
        VStack(spacing: 0) {
            // File picker button and polling interval
            HStack {
                Button(action: { isShowingPostmanFilePicker = true }) {
                    Label("Select Postman Collection", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.bordered)

                Spacer()

                Picker("Polling Interval", selection: $pollingInterval) {
                    ForEach(PollingInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .frame(width: 180)
            }
            .padding()

            if let collectionName = postmanCollectionName {
                HStack {
                    Label(collectionName, systemImage: "folder.fill")
                        .font(.headline)
                    Spacer()
                    Text("\(postmanRequests.count) request\(postmanRequests.count == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            Divider()

            if let error = postmanParseError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)

                    Text("Failed to parse collection")
                        .font(.headline)

                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if postmanRequests.isEmpty {
                emptyPostmanStateView
            } else {
                postmanRequestListView
            }

            Divider()

            // Import button
            HStack {
                if !postmanRequests.isEmpty {
                    Button("Clear All") {
                        postmanRequests.removeAll()
                        postmanCollectionName = nil
                        postmanParseError = nil
                    }
                    .buttonStyle(.bordered)

                    Button(postmanRequests.allSatisfy({ $0.isSelected }) ? "Deselect All" : "Select All") {
                        let allSelected = postmanRequests.allSatisfy { $0.isSelected }
                        for index in postmanRequests.indices {
                            postmanRequests[index].isSelected = !allSelected
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                let selectedCount = postmanRequests.filter { $0.isSelected }.count
                Button("Import \(selectedCount) Endpoint\(selectedCount == 1 ? "" : "s")") {
                    importSelectedPostmanRequests()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCount == 0)
            }
            .padding()
        }
        .fileImporter(
            isPresented: $isShowingPostmanFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handlePostmanFileSelection(result)
        }
    }

    private var emptyPostmanStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "shippingbox")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Postman collection imported")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Click \"Select Postman Collection\" to import a .json collection file exported from Postman")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var postmanRequestListView: some View {
        List {
            ForEach($postmanRequests) { $request in
                PostmanRequestRow(request: $request)
            }
        }
        .listStyle(.inset)
    }

    private var emptyFileStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No curl files imported")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Click \"Select Curl Files\" to browse for .txt or .curl files containing curl commands")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var fileListView: some View {
        List {
            ForEach($importedFiles) { $file in
                ImportedFileRow(file: $file, onRemove: {
                    importedFiles.removeAll { $0.id == file.id }
                })
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Shared Components

    @ViewBuilder
    private func parsedCommandPreview(_ parsed: ParsedCurlCommand) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("URL", value: parsed.url)
            LabeledContent("Method", value: parsed.method.rawValue)

            if !parsed.headers.isEmpty {
                DisclosureGroup("Headers (\(parsed.headers.count))") {
                    ForEach(Array(parsed.headers.keys.sorted()), id: \.self) { key in
                        LabeledContent(key, value: parsed.headers[key] ?? "")
                    }
                }
            }

            if let body = parsed.body {
                DisclosureGroup("Body") {
                    Text(body)
                        .font(.caption.monospaced())
                }
            }
        }
        .padding(.vertical, 8)
        .foregroundStyle(.secondary)
    }

    // MARK: - Validation

    private var isPasteValid: Bool {
        !name.isEmpty && parsedCommand != nil && parseError == nil
    }

    // MARK: - Helpers

    private func extractEndpointName(from urlString: String) -> String {
        guard let url = URL(string: urlString) else {
            return "New Endpoint"
        }

        // Get the path, removing leading slash
        var path = url.path
        if path.hasPrefix("/") {
            path = String(path.dropFirst())
        }

        // If path is empty or just "/", use host
        if path.isEmpty {
            return url.host ?? "New Endpoint"
        }

        // Clean up the path - remove trailing slashes
        if path.hasSuffix("/") {
            path = String(path.dropLast())
        }

        // If path is too long, use just the last component
        if path.count > 40 {
            return url.lastPathComponent.isEmpty ? (url.host ?? "New Endpoint") : url.lastPathComponent
        }

        return path
    }

    // MARK: - Actions

    private func parseCurlCommand(_ command: String) {
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            parsedCommand = nil
            parseError = nil
            return
        }

        do {
            parsedCommand = try curlParser.parse(command)
            parseError = nil

            if name.isEmpty, let urlString = parsedCommand?.url {
                name = extractEndpointName(from: urlString)
            }
        } catch {
            parseError = error.localizedDescription
            parsedCommand = nil
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            // Try to load as file URL first
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                    guard error == nil,
                          let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else {
                        return
                    }

                    // Read file contents
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }

                        if let content = try? String(contentsOf: url, encoding: .utf8) {
                            DispatchQueue.main.async {
                                self.curlCommand = content
                            }
                        }
                    } else {
                        // Try without security scope for regular file drops
                        if let content = try? String(contentsOf: url, encoding: .utf8) {
                            DispatchQueue.main.async {
                                self.curlCommand = content
                            }
                        }
                    }
                }
                return
            }

            // Fallback to plain text
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
                    guard error == nil else { return }

                    var text: String?
                    if let string = item as? String {
                        text = string
                    } else if let data = item as? Data {
                        text = String(data: data, encoding: .utf8)
                    }

                    if let text = text {
                        DispatchQueue.main.async {
                            self.curlCommand = text
                        }
                    }
                }
            }
        }
    }

    private func createSingleEndpoint() {
        guard let parsed = parsedCommand else { return }

        let endpoint = APIEndpoint(
            name: name,
            url: parsed.url,
            method: parsed.method,
            headers: parsed.headers,
            body: parsed.body,
            pollingInterval: pollingInterval
        )

        onSave(endpoint)
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    let fileName = url.deletingPathExtension().lastPathComponent

                    var importedFile = ImportedCurlFile(
                        fileName: fileName,
                        rawContent: content
                    )

                    do {
                        let parsed = try curlParser.parse(content)
                        importedFile.parsedCommand = parsed
                        importedFile.name = extractEndpointName(from: parsed.url)
                    } catch {
                        importedFile.parseError = error.localizedDescription
                    }

                    importedFiles.append(importedFile)
                } catch {
                    let importedFile = ImportedCurlFile(
                        fileName: url.lastPathComponent,
                        rawContent: "",
                        parseError: "Failed to read file: \(error.localizedDescription)"
                    )
                    importedFiles.append(importedFile)
                }
            }
        case .failure(let error):
            print("File selection failed: \(error.localizedDescription)")
        }
    }

    private func importSelectedEndpoints() {
        let endpoints = importedFiles
            .filter { $0.isSelected && $0.isValid }
            .compactMap { file -> APIEndpoint? in
                guard let parsed = file.parsedCommand else { return nil }
                return APIEndpoint(
                    name: file.name,
                    url: parsed.url,
                    method: parsed.method,
                    headers: parsed.headers,
                    body: parsed.body,
                    pollingInterval: pollingInterval
                )
            }

        onBulkSave(endpoints)
    }

    private func handlePostmanFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            guard url.startAccessingSecurityScopedResource() else {
                postmanParseError = "Unable to access the selected file"
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                let requests = try postmanParser.parse(data)

                postmanRequests = requests
                postmanCollectionName = url.deletingPathExtension().lastPathComponent
                postmanParseError = nil
            } catch {
                postmanParseError = error.localizedDescription
                postmanRequests = []
                postmanCollectionName = nil
            }

        case .failure(let error):
            postmanParseError = error.localizedDescription
        }
    }

    private func importSelectedPostmanRequests() {
        let endpoints = postmanRequests
            .filter { $0.isSelected }
            .map { request -> APIEndpoint in
                APIEndpoint(
                    name: request.name,
                    url: request.parsedCommand.url,
                    method: request.parsedCommand.method,
                    headers: request.parsedCommand.headers,
                    body: request.parsedCommand.body,
                    pollingInterval: pollingInterval
                )
            }

        onBulkSave(endpoints)
    }
}

// MARK: - Supporting Types

struct ImportedCurlFile: Identifiable {
    let id = UUID()
    var fileName: String
    var rawContent: String
    var name: String = ""
    var parsedCommand: ParsedCurlCommand?
    var parseError: String?
    var isSelected: Bool = true

    var isValid: Bool {
        parsedCommand != nil && parseError == nil
    }
}

struct ImportedFileRow: View {
    @Binding var file: ImportedCurlFile
    let onRemove: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("", isOn: $file.isSelected)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .disabled(!file.isValid)

                Image(systemName: file.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(file.isValid ? .green : .red)

                VStack(alignment: .leading, spacing: 2) {
                    TextField("Name", text: $file.name)
                        .textFieldStyle(.plain)
                        .font(.headline)

                    Text(file.fileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let parsed = file.parsedCommand {
                    Text(parsed.method.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.borderless)

                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
            }

            if isExpanded {
                if let error = file.parseError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                } else if let parsed = file.parsedCommand {
                    VStack(alignment: .leading, spacing: 4) {
                        LabeledContent("URL", value: parsed.url)
                            .font(.caption)

                        if !parsed.headers.isEmpty {
                            Text("Headers: \(parsed.headers.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if parsed.body != nil {
                            Text("Has request body")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading, 24)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Postman Request Row

struct PostmanRequestRow: View {
    @Binding var request: ParsedPostmanRequest

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("", isOn: $request.isSelected)
                    .toggleStyle(.checkbox)
                    .labelsHidden()

                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    TextField("Name", text: $request.name)
                        .textFieldStyle(.plain)
                        .font(.headline)

                    if let folderPath = request.folderPath {
                        Text(folderPath)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                Text(request.parsedCommand.method.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(methodColor(for: request.parsedCommand.method).opacity(0.2))
                    .foregroundStyle(methodColor(for: request.parsedCommand.method))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.borderless)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    LabeledContent("URL", value: request.parsedCommand.url)
                        .font(.caption)

                    if !request.parsedCommand.headers.isEmpty {
                        Text("Headers: \(request.parsedCommand.headers.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if request.parsedCommand.body != nil {
                        Text("Has request body")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 24)
            }
        }
        .padding(.vertical, 4)
    }

    private func methodColor(for method: HTTPMethod) -> Color {
        switch method {
        case .GET:
            return .green
        case .POST:
            return .blue
        case .PUT:
            return .orange
        case .PATCH:
            return .purple
        case .DELETE:
            return .red
        case .HEAD, .OPTIONS:
            return .gray
        }
    }
}

#Preview {
    CurlImportView(onSave: { _ in }, onBulkSave: { _ in })
        .frame(width: 500, height: 500)
}
