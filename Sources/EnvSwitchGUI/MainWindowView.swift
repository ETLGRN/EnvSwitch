import SwiftUI
import AppKit

struct MainWindowView: View {
    @EnvironmentObject var model: AppModel
    @State private var newEnvName = ""
    @State private var newKey = ""
    @State private var newValue = ""
    @State private var newGroup = ""
    @State private var showFirstRun = false
    @State private var showError = false
    @State private var showHelp = false
    @State private var moveTargetRow: AppModel.VariableRow?
    @State private var moveGroupName = ""
    /// Collapsed group tokens ("env::group"), persisted as a GUI preference.
    @AppStorage("envswitch.collapsedGroups") private var collapsedGroupsData = "[]"

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { model.lastError = nil }
        } message: { Text(model.lastError ?? "") }
        .sheet(isPresented: $showFirstRun) {
            FirstRunView(onInstallHook: { model.installZshHook(); showFirstRun = false },
                         symlinkCommand: model.cliSymlinkCommand)
        }
        .sheet(isPresented: $showHelp) {
            HelpView(symlinkCommand: model.cliSymlinkCommand,
                     applyCommand: model.applyToShellCommand,
                     onInstallHook: { model.installZshHook() },
                     onClose: { showHelp = false })
        }
        .sheet(item: $moveTargetRow) { row in
            moveToGroupSheet(row)
        }
        .onChange(of: model.lastError) { _, newValue in showError = (newValue != nil) }
        .onAppear { showFirstRun = model.needsHook }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading) {
            List(selection: $model.selectedEnvironment) {
                Section("Layers") { Text("base").tag("base") }
                Section("Environments") {
                    ForEach(model.environmentNames, id: \.self) { name in
                        HStack {
                            Text(name)
                            if name == model.activeName {
                                Spacer(); Image(systemName: "largecircle.fill.circle")
                            }
                        }.tag(name)
                    }
                }
            }
            .onChange(of: model.selectedEnvironment) { _, _ in model.loadVariables() }

            HStack {
                TextField("New environment", text: $newEnvName)
                Button("Add") {
                    guard !newEnvName.isEmpty else { return }
                    model.addEnvironment(newEnvName); newEnvName = ""
                }
            }.padding(8)
        }
        .frame(minWidth: 200)
    }

    // MARK: Detail

    private var detail: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(model.selectedEnvironment ?? "—").font(.title2)
                Spacer()
                Button { showHelp = true } label: { Image(systemName: "questionmark.circle") }
                    .help("使用说明 / 安装 CLI")
                Button("Reload") { model.reloadActive() }
                    .help("Regenerate active.env now (base + active environment)")
                if let env = model.selectedEnvironment, env != "base" {
                    Button("Activate") { model.activate(env) }
                        .disabled(env == model.activeName)
                }
            }.padding(.horizontal)

            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索 key / value", text: $model.searchText)
                    .textFieldStyle(.plain)
                if !model.searchText.isEmpty {
                    Button { model.searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless)
                }
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .quaternarySystemFill)))
            .padding(.horizontal)

            variableList

            HStack {
                TextField("KEY", text: $newKey)
                TextField("value", text: $newValue)
                TextField("分组（可选）", text: $newGroup)
                    .frame(maxWidth: 140)
                if !model.groupNames.isEmpty {
                    Menu {
                        ForEach(model.groupNames, id: \.self) { g in
                            Button(g) { newGroup = g }
                        }
                    } label: { Image(systemName: "folder") }
                    .menuStyle(.borderlessButton)
                    .frame(width: 30)
                    .help("选择现有分组")
                }
                Button("Set") {
                    guard !newKey.isEmpty else { return }
                    model.setVariable(key: newKey, value: newValue, group: newGroup)
                    newKey = ""; newValue = ""; newGroup = ""
                }
            }.padding(.horizontal)

            HStack(spacing: 8) {
                Text("To apply to an already-open terminal, run:")
                    .font(.footnote).foregroundStyle(.secondary)
                Text(model.applyToShellCommand)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                Button {
                    model.copyString(model.applyToShellCommand)
                } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless)
                    .help("Copy command")
            }.padding([.horizontal, .bottom])
        }
    }

    // MARK: Grouped variable list

    private var isSearching: Bool {
        !model.searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var variableList: some View {
        let rows = model.filteredVariables
        let ungrouped = rows.filter { $0.group == nil || $0.group?.isEmpty == true }
        let groups = orderedGroups(rows)
        return List {
            sectionRows(ungrouped)
            ForEach(groups, id: \.self) { group in
                DisclosureGroup(isExpanded: expansionBinding(for: group)) {
                    sectionRows(rows.filter { $0.group == group })
                } label: {
                    Label("\(group)（\(rows.filter { $0.group == group }.count)）", systemImage: "folder")
                        .font(.callout.weight(.medium))
                }
            }
        }
        .listStyle(.inset)
    }

    /// Rows of one section (ungrouped or one group), with drag reorder inside the section.
    private func sectionRows(_ rows: [AppModel.VariableRow]) -> some View {
        ForEach(rows) { row in
            variableRow(row, sectionRows: rows)
        }
        .onMove { source, destination in
            guard !isSearching, let first = source.first else { return }
            let fromIndex = rows[first].index
            let toIndex = destination >= rows.count
                ? (rows.last.map { $0.index + 1 } ?? 0)
                : rows[destination].index
            model.moveVariable(fromIndex: fromIndex, toIndex: toIndex)
        }
        .moveDisabled(isSearching)
    }

    /// Width of the key column: sized to the longest key in the current layer,
    /// clamped so one extreme key can't push values off-screen.
    private var keyColumnWidth: CGFloat {
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let widest = model.variables
            .map { ($0.key as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        return min(max(widest + 12, 100), 280)
    }

    private func variableRow(_ row: AppModel.VariableRow, sectionRows: [AppModel.VariableRow]) -> some View {
        HStack(spacing: 12) {
            // Fixed-width key column so values line up regardless of key length.
            Text(row.key)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: keyColumnWidth, alignment: .leading)
                .textSelection(.enabled)
                .onTapGesture(count: 2) { model.copyString(row.key) }
                .help("\(row.key)（双击复制）")
            Divider().frame(height: 14)
            Text(row.value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .onTapGesture(count: 2) { model.copyValue(row) }
                .help("\(row.value)（双击复制）")
            HStack(spacing: 10) {
                Button { model.copyValue(row) } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless)
                    .help("Copy value")
                Button(role: .destructive) { model.unsetVariable(key: row.key) } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete")
            }
        }
        .contextMenu {
            Button("复制 key") { model.copyString(row.key) }
            Button("复制 value") { model.copyValue(row) }
            Divider()
            Button("上移") { moveWithinSection(row, in: sectionRows, offset: -1) }
                .disabled(isSearching || sectionRows.first?.id == row.id)
            Button("下移") { moveWithinSection(row, in: sectionRows, offset: 1) }
                .disabled(isSearching || sectionRows.last?.id == row.id)
            Divider()
            Menu("移动到分组…") {
                ForEach(model.groupNames.filter { $0 != row.group }, id: \.self) { g in
                    Button(g) { model.setGroup(key: row.key, group: g) }
                }
                Button("新建分组…") { moveGroupName = ""; moveTargetRow = row }
                if row.group != nil {
                    Divider()
                    Button("移出分组") { model.setGroup(key: row.key, group: nil) }
                }
            }
            Divider()
            Button(role: .destructive) { model.unsetVariable(key: row.key) } label: { Text("删除") }
        }
    }

    private func moveWithinSection(_ row: AppModel.VariableRow, in rows: [AppModel.VariableRow], offset: Int) {
        guard let pos = rows.firstIndex(where: { $0.id == row.id }) else { return }
        let neighbor = pos + offset
        guard rows.indices.contains(neighbor) else { return }
        // Swap with the neighbor's position in the full list.
        let from = rows[pos].index
        var to = rows[neighbor].index
        if offset > 0 { to += 1 }
        model.moveVariable(fromIndex: from, toIndex: to)
    }

    private func moveToGroupSheet(_ row: AppModel.VariableRow) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("移动「\(row.key)」到新分组").font(.headline)
            TextField("分组名称", text: $moveGroupName)
                .frame(width: 240)
            HStack {
                Spacer()
                Button("取消") { moveTargetRow = nil }
                Button("确定") {
                    let name = moveGroupName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { model.setGroup(key: row.key, group: name) }
                    moveTargetRow = nil
                }
                .keyboardShortcut(.defaultAction)
                .disabled(moveGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
    }

    // MARK: Group ordering & collapse state

    private func orderedGroups(_ rows: [AppModel.VariableRow]) -> [String] {
        var seen = Set<String>()
        var names: [String] = []
        for row in rows {
            if let g = row.group, !g.isEmpty, seen.insert(g).inserted { names.append(g) }
        }
        return names
    }

    private var collapsedGroups: Set<String> {
        get {
            guard let data = collapsedGroupsData.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return Set(arr)
        }
    }

    private func setCollapsed(_ token: String, _ collapsed: Bool) {
        var set = collapsedGroups
        if collapsed { set.insert(token) } else { set.remove(token) }
        if let data = try? JSONEncoder().encode(Array(set).sorted()),
           let text = String(data: data, encoding: .utf8) {
            collapsedGroupsData = text
        }
    }

    /// Expanded by default; collapsed state persists per environment+group.
    /// While searching, groups are forced open.
    private func expansionBinding(for group: String) -> Binding<Bool> {
        if isSearching { return .constant(true) }
        let token = "\(model.selectedEnvironment ?? "base")::\(group)"
        return Binding(
            get: { !collapsedGroups.contains(token) },
            set: { expanded in setCollapsed(token, !expanded) }
        )
    }
}
