import Foundation

nonisolated enum ProjectBrowserPolicy {
    static func rootItems(projects: [NarabiProject], folders: [ProjectFolder]) -> [ProjectBrowserRecord] {
        let folderRecords = folders.map { ProjectBrowserRecord(folder: $0, project: nil) }
        let projectRecords = projects.filter { $0.folderID == nil }
            .map { ProjectBrowserRecord(folder: nil, project: $0) }
        return (folderRecords + projectRecords).sorted { order($0) < order($1) }
    }

    static func projects(in folderID: UUID, projects: [NarabiProject]) -> [NarabiProject] {
        projects.filter { $0.folderID == folderID }.sorted { $0.browserOrder < $1.browserOrder }
    }

    static func searchItems(
        _ query: String, projects: [NarabiProject], folders: [ProjectFolder], locale: Locale = .current
    ) -> [ProjectBrowserRecord] {
        let normalizedQuery = normalized(query, locale: locale)
        let folderRecords =
            folders
            .filter {
                normalized($0.name, locale: locale).contains(normalizedQuery)
            }
            .map { ProjectBrowserRecord(folder: $0, project: nil) }
        let names = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0.name) })
        let projectRecords =
            projects
            .filter { project in
                let folderName = project.folderID.flatMap { names[$0] } ?? ""
                return normalized(project.outputName + " " + folderName, locale: locale)
                    .contains(normalizedQuery)
            }
            .map { ProjectBrowserRecord(folder: nil, project: $0) }
        return folderRecords + projectRecords
    }

    static func normalizeOrders(projects: inout [NarabiProject], folders: inout [ProjectFolder]) {
        for (index, record) in rootItems(projects: projects, folders: folders).enumerated() {
            if let folder = record.folder,
                let target = folders.firstIndex(where: { $0.id == folder.id })
            {
                folders[target].browserOrder = index
            }
            if let project = record.project,
                let target = projects.firstIndex(where: { $0.id == project.id })
            {
                projects[target].browserOrder = index
            }
        }
        for folder in folders {
            for (index, project) in Self.projects(in: folder.id, projects: projects).enumerated() {
                if let target = projects.firstIndex(where: { $0.id == project.id }) {
                    projects[target].browserOrder = index
                }
            }
        }
    }

    private static func normalized(_ value: String, locale: Locale) -> String {
        value.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: locale)
    }

    private static func order(_ record: ProjectBrowserRecord) -> Int {
        record.folder?.browserOrder ?? record.project?.browserOrder ?? 0
    }
}
