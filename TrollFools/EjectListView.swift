//
//  EjectListView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/20.
//

import SwiftUI
import ZIPFoundation
import UniformTypeIdentifiers
import CocoaLumberjackSwift

struct EjectListView: View {
    @StateObject var ejectList: EjectListModel

    init(_ app: App) {
        _ejectList = StateObject(wrappedValue: EjectListModel(app))
    }

    @State var isErrorOccurred: Bool = false
    @State var lastError: Error?

    @State var isDeletingAll = false
    @StateObject var viewControllerHost = ViewControllerHost()

    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showingExportDialog = false
    @State private var zipFileURL: URL?

    var deleteAllButtonLabel: some View {
        HStack {
            Label(NSLocalizedString("Eject All", comment: ""), systemImage: "eject")
            Spacer()
            if isDeletingAll {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
    }

    var deleteAllButton: some View {
        if #available(iOS 15, *) {
            Button(role: .destructive) {
                deleteAll()
            } label: {
                deleteAllButtonLabel
            }
        } else {
            Button {
                deleteAll()
            } label: {
                deleteAllButtonLabel
            }
        }
    }

    var headerView: some View {
        Text(ejectList.filteredPlugIns.isEmpty
             ? NSLocalizedString("No Injected Plug-Ins", comment: "")
             : NSLocalizedString("Injected Plug-Ins", comment: ""))
            .font(.footnote)
    }

    var footerView: some View {
        Text(NSLocalizedString("Some plug-ins were not injected by TrollFools, please eject them with caution.", comment: ""))
            .font(.footnote)
    }

    var ejectListView: some View {
        List {
            Section {
                ForEach(ejectList.filteredPlugIns) { plugin in
                    if #available(iOS 16, *) {
                        PlugInCell(plugIn: plugin)
                            .environmentObject(ejectList)
                    } else {
                        // let _ = DDLogInfo("[EjectListView] 插件: \(plugin.url.path), \(ejectList.app.name)")
                        PlugInCell(plugIn: plugin)
                            .environmentObject(ejectList)
                            .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: delete)
            } header: {
                if #available(iOS 15, *) {
                    headerView
                } else {
                    headerView
                        .padding(.horizontal, 16)
                }
            }

            if !ejectList.filter.isSearching && !ejectList.filteredPlugIns.isEmpty {
                Section {
                    deleteAllButton
                        .disabled(isDeletingAll)
                        .foregroundColor(isDeletingAll ? .secondary : .red)
                } footer: {
                    if ejectList.app.isFromTroll {
                        if #available(iOS 15, *) {
                            footerView
                        } else {
                            footerView
                                .padding(.horizontal, 16)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("Plug-Ins", comment: ""))
        .animation(.easeOut, value: ejectList.filter.isSearching)
        .background(Group {
            NavigationLink(isActive: $isErrorOccurred) {
                FailureView(
                    title: NSLocalizedString("Error", comment: ""),
                    error: lastError
                )
            } label: { }
        })
        .onViewWillAppear { viewController in
            viewControllerHost.viewController = viewController
        }
    }

    var exportButton: some View {
        Button(action: {
            Task {
                await exportPlugIns()
            }
        }) {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(ejectList.filteredPlugIns.isEmpty)
    }

    func exportPlugIns() async {
        guard !ejectList.filteredPlugIns.isEmpty else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMdd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let zipFileName = "\(ejectList.app.name)Plugins_\(timestamp)"
        let zipFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(zipFileName).zip")

        do {
            let fileManager = FileManager.default
            let archive = try Archive(url: zipFileURL, accessMode: .create)

            for plugin in ejectList.filteredPlugIns {
                let entryPath = "\(plugin.url.lastPathComponent)"
                
                guard fileManager.fileExists(atPath: plugin.url.path) else {
                    DDLogInfo("File not found: \(plugin.url.path)")
                    continue
                }
                
                try archive.addEntry(
                    with: entryPath, 
                    fileURL: plugin.url, 
                    compressionMethod: .deflate
                )
            }

            await MainActor.run {
                showDocumentPicker(for: zipFileURL)
            }
        } catch {
            DDLogInfo("Export error: \(error)")
            await MainActor.run {
                lastError = error
                isErrorOccurred = true
            }
        }
    }

    func showDocumentPicker(for url: URL) {
        guard let viewController = viewControllerHost.viewController else { return }
        
        let documentPicker = UIDocumentPickerViewController(forExporting: [url])
        documentPicker.modalPresentationStyle = .formSheet
        
        viewController.present(documentPicker, animated: true)
    }

    var body: some View {
        if #available(iOS 15, *) {
            ejectListView
                .refreshable {
                    withAnimation {
                        ejectList.reload()
                    }
                }
                .searchable(
                    text: $ejectList.filter.searchKeyword,
                    placement: .automatic,
                    prompt: NSLocalizedString("Search…", comment: "")
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        exportButton
                    }
                }
        } else {
            ejectListView
        }
    }

    func delete(at offsets: IndexSet) {
        do {
            let plugInsToRemove = offsets.map { ejectList.filteredPlugIns[$0] }
            let plugInURLsToRemove = plugInsToRemove.map { $0.url }
            try InjectorV3(ejectList.app.url).eject(plugInURLsToRemove)

            ejectList.app.reload()
            ejectList.reload()
        } catch {
            DDLogError("\(error)", ddlog: InjectorV3.main.logger)
            lastError = error
            isErrorOccurred = true
        }
    }

    func deleteAll() {
        do {
            let injector = try InjectorV3(ejectList.app.url)

            let view = viewControllerHost.viewController?
                .navigationController?.view

            view?.isUserInteractionEnabled = false

            withAnimation {
                isDeletingAll = true
            }

            DispatchQueue.global(qos: .userInteractive).async {
                defer {
                    DispatchQueue.main.async {
                        withAnimation {
                            ejectList.app.reload()
                            ejectList.reload()
                            isDeletingAll = false
                        }

                        view?.isUserInteractionEnabled = true
                    }
                }

                do {
                    try injector.ejectAll()
                } catch {
                    DispatchQueue.main.async {
                        withAnimation {
                            isDeletingAll = false
                        }

                        DDLogError("\(error)", ddlog: InjectorV3.main.logger)
                        lastError = error
                        isErrorOccurred = true
                    }
                }
            }
        } catch {
            lastError = error
            isErrorOccurred = true
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ShareSheet>) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        if #available(iOS 15.0, *) {
            if let sheet = controller.sheetPresentationController {
                sheet.detents = [.medium()]
                sheet.prefersGrabberVisible = true
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ShareSheet>) {}
}

struct ZIPDocument: FileDocument {
    var url: URL
    
    static var readableContentTypes: [UTType] { [.zip] }
    
    init(url: URL) {
        self.url = url
    }
    
    init(configuration: ReadConfiguration) throws {
        url = URL(fileURLWithPath: "")
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return try FileWrapper(url: url, options: .immediate)
    }
}

