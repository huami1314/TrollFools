//
//  newAppListView.swift
//  TrollFools
//
//  Created by huami on 2024/3/19.
//

import SwiftUI
import CocoaLumberjackSwift

struct AppListView: View {
    @EnvironmentObject var appList: AppListModel
    @State private var isUsingOfficialIcon = false
    @State private var isEditing = false
    @State var isErrorOccurred: Bool = false
    @State var lastError: Error?
    @State var isFirstLaunch: Bool = false
    @State var selectorOpenedURL: URL? = nil
    
    var appNameString: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "TrollFools"
    }

    var appVersionString: String {
        String(format: "v%@ (%@)_huami",
               Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0",
               Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0")
    }

    var appString: String {
        let currentYear = Calendar.current.component(.year, from: Date())
        return String(format: """
    %@ %@ %@ © %d
    %@
    %@
    """, appNameString, appVersionString, NSLocalizedString("Copyright", comment: ""), currentYear, NSLocalizedString("Made with ♥ by OwnGoal Studio", comment: ""), NSLocalizedString("@huamidev Add some features", comment: ""), "TG：@huamidev")
    }

    let repoURL = URL(string: "https://github.com/Lessica/TrollFools")

    func filteredAppList(_ apps: [App]) -> some View {
        ForEach(apps) { app in
            NavigationLink {
                if appList.isSelectorMode, let selectorURL = appList.selectorURL {
                    InjectView(app, urlList: [selectorURL])
                } else {
                    OptionView(app)
                }
            } label: {
                if #available(iOS 16, *) {
                    AppListCell(app: app)
                } else {
                    AppListCell(app: app)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    var appListFooterView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appString)
                .font(.footnote)

            if let repoURL = repoURL {
                Button {
                    UIApplication.shared.open(repoURL)
                } label: {
                    Text(NSLocalizedString("Source Code", comment: ""))
                        .font(.footnote)
                }
            }
        }
    }

    var appListFooter: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !appList.filter.showPatchedOnly {
                Text(NSLocalizedString("Only removable system applications are eligible and listed.", comment: ""))
                    .font(.footnote)
            }

            if !appList.isSelectorMode {
                if #available(iOS 16, *) {
                    appListFooterView
                        .padding(.top, 8)
                } else {
                    appListFooterView
                        .padding(.top, 2)
                }
            }
        }
    }

    var appListView: some View {
        List {
            if AppListModel.hasTrollStore && appList.isRebuildNeeded {
                Section {
                    Button {
                        rebuildIconCache()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("Rebuild Icon Cache", comment: ""))
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text(NSLocalizedString("You need to rebuild the icon cache in TrollStore to apply changes.", comment: ""))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if appList.isRebuilding {
                                if #available(iOS 16, *) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .controlSize(.large)
                                } else {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(2.0)
                                }
                            } else {
                                Image(systemName: "timelapse")
                                    .font(.title)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(appList.isRebuilding)
                }
            }

            Section {
                ForEach(appList.displayedApplications) { app in
                    NavigationLink {
                        if appList.isSelectorMode, let selectorURL = appList.selectorURL {
                            InjectView(app, urlList: [selectorURL])
                        } else {
                            OptionView(app)
                        }
                    } label: {
                        AppListCell(app: app)
                    }
                }
            } footer: {
                if !appList.filter.isSearching {
                    VStack(alignment: .leading, spacing: 20) {
                        if !appList.filter.showPatchedOnly {
                            Text(NSLocalizedString("Only removable system applications are eligible and listed.", comment: ""))
                                .font(.footnote)
                            
                            if appList.unsupportedCount > 0 {
                                Text(String(format: NSLocalizedString("%d applications are not supported.", comment: ""), appList.unsupportedCount))
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if !appList.isSelectorMode {
                            if #available(iOS 16.0, *) {
                                appListFooterView
                                    .padding(.top, 8)
                            } else {
                                appListFooterView
                                    .padding(.top, 2)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(appList.isSelectorMode ? NSLocalizedString("Select Application to Inject", comment: "") : NSLocalizedString("TrollFools", comment: ""))
        .navigationBarTitleDisplayMode(appList.isSelectorMode ? .inline : .automatic)
        .background(Group {
            NavigationLink(isActive: $isErrorOccurred) {
                FailureView(
                    title: NSLocalizedString("Error", comment: ""),
                    error: lastError
                )
            } label: { }
        })
        .gesture(
            DragGesture()
                .onEnded { value in
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) {
                        if value.translation.width > 100 {
                            switch appList.selectedFilter {
                            case .all:
                                appList.selectedFilter = .system
                            case .user:
                                appList.selectedFilter = .all
                            case .troll:
                                appList.selectedFilter = .user
                            case .system:
                                appList.selectedFilter = .troll
                            }
                        } else if value.translation.width < -100 {
                            switch appList.selectedFilter {
                            case .all:
                                appList.selectedFilter = .user
                            case .user:
                                appList.selectedFilter = .troll
                            case .troll:
                                appList.selectedFilter = .system
                            case .system:
                                appList.selectedFilter = .all
                            }
                        }
                    }
                }
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Button(NSLocalizedString("Name (A-Z)", comment: "")) {
                        appList.sortOrder = .ascending
                        appList.performFilter()
                    }
                    Button(NSLocalizedString("Name (Z-A)", comment: "")) {
                        appList.sortOrder = .descending
                        appList.performFilter()
                    }
                    Button(action: toggleAppIcon) {
                        Text(isUsingOfficialIcon ? NSLocalizedString("Switch to Default Icon", comment: "") : NSLocalizedString("Switch to Official Icon", comment: ""))
                    }
                    Button(action: clearCache) {
                        Text(NSLocalizedString("Clear Temp Cache", comment: ""))
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                }
                .accessibilityLabel(NSLocalizedString("Sort Order", comment: ""))
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        appList.filter.showPatchedOnly.toggle()
                        appList.performFilter()
                    }
                } label: {
                    if #available(iOS 15, *) {
                        Image(systemName: appList.filter.showPatchedOnly 
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    } else {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
                .accessibilityLabel(NSLocalizedString("Show Patched Only", comment: ""))
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                if #available(iOS 15, *) {
                    // iOS 15 及以上的搜索框和功能
                    VStack {
                        // 分类列
                        Picker("", selection: $appList.selectedFilter) {
                            Text(NSLocalizedString("All", comment: "")).tag(AppListModel.Filter.all)
                            Text(NSLocalizedString("User", comment: "")).tag(AppListModel.Filter.user)
                            Text(NSLocalizedString("Troll", comment: "")).tag(AppListModel.Filter.troll)
                            Text(NSLocalizedString("System", comment: "")).tag(AppListModel.Filter.system)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        // iOS 15 的搜索框
                        appListView
                            .refreshable {
                                withAnimation {
                                    appList.reload()
                                }
                            }
                            .searchable(
                                text: $appList.filter.searchKeyword,
                                placement: .automatic,
                                prompt: (appList.filter.showPatchedOnly
                                         ? NSLocalizedString("Search Patched…", comment: "")
                                         : NSLocalizedString("Search…", comment: ""))
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                    }
                } else {
                    // iOS 14 自定义搜索框和按钮
                    VStack {
                        HStack(spacing: 0) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                    .padding(10)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(6)
                                TextField(NSLocalizedString("Search…", comment: ""), text: $appList.filter.searchKeyword, onEditingChanged: { editing in
                                    withAnimation {
                                        isEditing = editing
                                    }
                                })
                                .padding(10)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                .frame(maxWidth: .infinity)
                            }
                            .frame(maxWidth: .infinity)

                            if isEditing {
                                Button(action: {
                                    withAnimation {
                                        appList.filter.searchKeyword = ""
                                        isEditing = false
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    }
                                }) {
                                    Text(NSLocalizedString("Cancel", comment: ""))
                                        .foregroundColor(.blue)
                                        .padding(2)
                                }
                                .transition(.move(edge: .trailing))
                                .frame(width: 60)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top) // 添加顶部内边距以与分类列对齐

                        // 分类列
                        Picker("", selection: $appList.selectedFilter) {
                            Text(NSLocalizedString("All", comment: "")).tag(AppListModel.Filter.all)
                            Text(NSLocalizedString("User", comment: "")).tag(AppListModel.Filter.user)
                            Text(NSLocalizedString("Troll", comment: "")).tag(AppListModel.Filter.troll)
                            Text(NSLocalizedString("System", comment: "")).tag(AppListModel.Filter.system)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        appListView
                    }
                }
            }
        }
        .onAppear {
            checkFirstLaunch()
            checkCurrentIcon()
        }
        .alert(isPresented: $isFirstLaunch) {
            Alert(
                title: Text("Notification"),
                message: Text("This software is an open-source project TrollFools.\nIf you have purchased it, you should understand what this means.\nVisit the project address in the footer for more information.\nModified version by huami.\nChange Lessica to huami1314 to redirect to this project.\nTG: @huamidev\nThis popup will only display once.\nThanks to the original author i_82.")
                    .font(.subheadline),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(item: $selectorOpenedURL) { url in
            AppListView()
                .environmentObject(AppListModel(selectorURL: url))
        }
        .onOpenURL { url in
            guard url.isFileURL, ["dylib", "deb"].contains(url.pathExtension.lowercased()) else {
                return
            }
            selectorOpenedURL = preprocessURL(url)
        }
    }

    private func clearCache() {
        do {
            let tempDir = try FileManager.default.url(
                for: .itemReplacementDirectory,
                in: .userDomainMask,
                appropriateFor: URL(fileURLWithPath: NSHomeDirectory()),
                create: true
            ).deletingLastPathComponent()
            
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            
            for url in contents {
                // DDLogInfo("[SystemCache] 正在清理临时目录: \(url.path)")
                try? fileManager.removeItem(at: url)
            }
            
            // DDLogInfo("[SystemCache] 系统临时缓存清理完成")
        } catch {
            // DDLogInfo("[SystemCache] 清理系统缓存失败: \(error.localizedDescription)")
        }
    }

    private func toggleAppIcon() {
        let newIcon = isUsingOfficialIcon ? nil : "AppIcon-official"
        
        UIApplication.shared.setAlternateIconName(newIcon) { error in
            if let error = error {
                print("Failed to set icon: \(error)")
            }
        }
        
        isUsingOfficialIcon.toggle()
    }
    
    private func checkCurrentIcon() {
        let currentIconName = UIApplication.shared.alternateIconName
        DispatchQueue.main.async {
            self.isUsingOfficialIcon = (currentIconName == "AppIcon-official")
        }
    }

    private func checkFirstLaunch() {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "TFlaunch") {
            defaults.set(true, forKey: "TFlaunch")
            isFirstLaunch = true
        } else {
            isFirstLaunch = false
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private func rebuildIconCache() {
        withAnimation {
            appList.isRebuilding = true
        }

        DispatchQueue.global(qos: .userInteractive).async {
            defer {
                DispatchQueue.main.async {
                    withAnimation {
                        appList.isRebuilding = false
                    }
                }
            }

            do {
                try appList.rebuildIconCache()

                DispatchQueue.main.async {
                    withAnimation {
                        appList.isRebuildNeeded = false
                    }
                }
            } catch {
                DDLogError("\(error)", ddlog: InjectorV3.main.logger)
                
                DispatchQueue.main.async {
                    lastError = error
                    isErrorOccurred = true
                }
            }
        }
    }

    private func preprocessURL(_ url: URL) -> URL {
        let isInbox = url.path.contains("/Documents/Inbox/")
        guard isInbox else {
            return url
        }
        let fileNameNoExt = url.deletingPathExtension().lastPathComponent
        let fileNameComps = fileNameNoExt.components(separatedBy: CharacterSet(charactersIn: "._- "))
        guard let lastComp = fileNameComps.last, fileNameComps.count > 1, lastComp.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil else {
            return url
        }
        let newURL = url.deletingLastPathComponent()
            .appendingPathComponent(String(fileNameNoExt.prefix(fileNameNoExt.count - lastComp.count - 1)))
            .appendingPathExtension(url.pathExtension)
        do {
            try? FileManager.default.removeItem(at: newURL)
            try FileManager.default.copyItem(at: url, to: newURL)
            return newURL
        } catch {
            return url
        }
    }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}
