//
//  AppListCell.swift
//  TrollFools
//
//  Created by 82Flex on 2024/10/30.
//

import SwiftUI
import CocoaLumberjackSwift
import ZIPFoundation

struct AppListCell: View {
    @EnvironmentObject var appList: AppListModel

    @StateObject var app: App
    @State var isErrorOccurred: Bool = false
    @State var lastError: Error?
    @State var isInjectingConfiguration: Bool = false
    @State var latestBackupURL: URL?

    @available(iOS 15, *)
    var highlightedName: AttributedString {
        let name = app.name
        var attributedString = AttributedString(name)
        if let range = attributedString.range(of: appList.filter.searchKeyword, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributedString[range].foregroundColor = .accentColor
        }
        return attributedString
    }

    @available(iOS 15, *)
    var highlightedId: AttributedString {
        let id = app.id
        var attributedString = AttributedString(id)
        if let range = attributedString.range(of: appList.filter.searchKeyword, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributedString[range].foregroundColor = .accentColor
        }
        return attributedString
    }

    @ViewBuilder
    var cellContextMenu: some View {
        Button {
            launch()
        } label: {
            Label(NSLocalizedString("Launch", comment: ""), systemImage: "command")
        }

        Button {
            openInFilza()
        } label: {
            if isFilzaInstalled {
                Label(NSLocalizedString("Show in Filza", comment: ""), systemImage: "scope")
            } else {
                Label(NSLocalizedString("Filza (URL Scheme) Not Installed", comment: ""), systemImage: "xmark.octagon")
            }
        }
        .disabled(!isFilzaInstalled)

        if AppListModel.hasTrollStore && app.isAllowedToAttachOrDetach {
            if app.isDetached {
                Button {
                    do {
                        _ = try InjectorV3(app.url)
                        try InjectorV3(app.url).setMetadataDetached(false)
                        withAnimation {
                            app.reload()
                            appList.isRebuildNeeded = true
                        }
                    } catch { DDLogError("\(error)", ddlog: InjectorV3.main.logger) }
                } label: {
                    Label(NSLocalizedString("Unlock Version", comment: ""), systemImage: "lock.open")
                }
            } else {
                Button {
                    do {
                        _ = try InjectorV3(app.url)
                        try InjectorV3(app.url).setMetadataDetached(true)
                        withAnimation {
                            app.reload()
                            appList.isRebuildNeeded = true
                        }
                    } catch { DDLogError("\(error)", ddlog: InjectorV3.main.logger) }
                } label: {
                    Label(NSLocalizedString("Lock Version", comment: ""), systemImage: "lock")
                }
            }
            
            Button {
                clearAppCache()
            } label: {
                Label(NSLocalizedString("Clear App Cache", comment: ""), systemImage: "trash")
            }
            Button {
                useLastConfiguration()
            } label: {
                Label(NSLocalizedString("Use Last Configuration", comment: ""), systemImage: "gear")
            }
        }
    }

    @ViewBuilder
    var cellContextMenuWrapper: some View {
        if #available(iOS 16, *) {
            // iOS 16
            cellContextMenu
        } else {
            if #available(iOS 15, *) { }
            else {
                // iOS 14
                cellContextMenu
            }
        }
    }

    @ViewBuilder
    var cellBackground: some View {
        if #available(iOS 15, *) {
            if #available(iOS 16, *) { }
            else {
                // iOS 15
                Color.clear
                    .contextMenu {
                        if !appList.isSelectorMode {
                            cellContextMenu
                        }
                    }
                    .id(app.isDetached)
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            if #available(iOS 15, *) {
                Image(uiImage: app.alternateIcon ?? app.icon ?? UIImage())
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(uiImage: app.alternateIcon ?? app.icon ?? UIImage())
                    .resizable()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if #available(iOS 15, *) {
                        Text(highlightedName)
                            .font(.headline)
                            .lineLimit(1)
                    } else {
                        Text(app.name)
                            .font(.headline)
                            .lineLimit(1)
                    }

                    if app.isInjected {
                        Image(systemName: "bandage")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                            .accessibilityLabel(NSLocalizedString("Patched", comment: ""))
                            .transition(.opacity)
                            .animation(.easeInOut, value: app.isInjected)
                    }
                }

                if #available(iOS 15, *) {
                    Text(highlightedId)
                        .font(.subheadline)
                        .lineLimit(1)
                } else {
                    Text(app.id)
                        .font(.subheadline)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let version = app.version {
                if app.isUser && app.isDetached {
                    HStack(spacing: 4) {
                        Image(systemName: "lock")
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .accessibilityLabel(NSLocalizedString("Pinned Version", comment: ""))

                        Text(version)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text(version)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .contextMenu {
            if !appList.isSelectorMode {
                cellContextMenuWrapper
            }
        }
        .background(cellBackground)
        .background(
            ZStack {
                if isInjectingConfiguration, let backupURL = latestBackupURL {
                    NavigationLink(destination: InjectView(app, urlList: [backupURL]), isActive: $isInjectingConfiguration) {
                        EmptyView()
                    }
                    .frame(width: 0, height: 0)
                    .hidden()
                }
                
                if isErrorOccurred {
                    NavigationLink(destination: FailureView(
                        title: NSLocalizedString("Error", comment: ""),
                        error: lastError
                    ), isActive: $isErrorOccurred) {
                        EmptyView()
                    }
                    .frame(width: 0, height: 0)
                    .hidden()
                }
            }
        )
    }

    private func launch() {
        LSApplicationWorkspace.default().openApplication(withBundleID: app.id)
    }

    var isFilzaInstalled: Bool { appList.isFilzaInstalled }

    private func openInFilza() {
        appList.openInFilza(app.url)
    }

    private func useLastConfiguration() {
        do {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let backupURL = documentsURL.appendingPathComponent("TFPlugInsBackups", isDirectory: true)
            
            guard FileManager.default.fileExists(atPath: backupURL.path) else {
                DDLogError("Backup directory not found", ddlog: InjectorV3.main.logger)
                let error = NSError(
                    domain: gTrollFoolsErrorDomain,
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Backup directory not found. Please inject plugins first."]
                )
                throw error
            }
            
            let fileURLs: [URL]
            do {
                fileURLs = try FileManager.default.contentsOfDirectory(
                    at: backupURL,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: .skipsHiddenFiles
                )
            } catch {
                DDLogError("Failed to read backup directory: \(error)", ddlog: InjectorV3.main.logger)
                let readError = NSError(
                    domain: gTrollFoolsErrorDomain,
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to read backup directory: \(error.localizedDescription)"]
                )
                throw readError
            }
            
            let appBackups = fileURLs.filter { url in
                url.lastPathComponent.hasPrefix("\(app.name)Plugins_") && 
                url.pathExtension.lowercased() == "zip"
            }
            
            guard !appBackups.isEmpty else {
                DDLogError("No backup found for \(app.name)", ddlog: InjectorV3.main.logger)
                let error = NSError(
                    domain: gTrollFoolsErrorDomain,
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "No backup found for \(app.name). Please inject plugins first."]
                )
                throw error
            }
            
            let sortedBackups: [URL]
            do {
                sortedBackups = try appBackups.sorted { url1, url2 in
                    let date1 = try url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
                    let date2 = try url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
                    return date1 > date2
                }
            } catch {
                DDLogError("Failed to sort backups: \(error)", ddlog: InjectorV3.main.logger)
                let sortError = NSError(
                    domain: gTrollFoolsErrorDomain,
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to sort backups: \(error.localizedDescription)"]
                )
                throw sortError
            }
            
            let latestBackup = sortedBackups[0]
            DDLogInfo("Found latest backup: \(latestBackup.path)", ddlog: InjectorV3.main.logger)
            
            latestBackupURL = latestBackup
            isInjectingConfiguration = true
            
        } catch {
            DDLogError("\(error)", ddlog: InjectorV3.main.logger)
            lastError = error
            isErrorOccurred = true
        }
    }

    private func clearAppCache() {
        do {
            let injector = try InjectorV3(app.url)
            
            let cachePaths = [
                URL(fileURLWithPath: app.dataurl.path.replacingOccurrences(of: "/private/", with: "")).appendingPathComponent("Library/Caches"),
                URL(fileURLWithPath: app.dataurl.path.replacingOccurrences(of: "/private/", with: "")).appendingPathComponent("tmp")
            ]
            
            for path in cachePaths {
                DDLogInfo("Cleaning path: \(path.path)", ddlog: InjectorV3.main.logger)
                try injector.cmdRemove(path, recursively: true)
            }
            
            DDLogInfo("Cache cleanup completed", ddlog: InjectorV3.main.logger)
        } catch {
            DDLogError("Failed to clean cache: \(error.localizedDescription)", ddlog: InjectorV3.main.logger)
        }
    }
}
