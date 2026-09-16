import Foundation

nonisolated enum ProjectBrowserMovementPolicy {
    static func move(
        tokens: [String], to destination: UUID?,
        projects: inout [NarabiProject], folders: inout [ProjectFolder]
    ) {
        for id in projectIDs(tokens) {
            if let index = projects.firstIndex(where: { $0.id == id }) {
                projects[index].folderID = destination
                projects[index].browserOrder = nextProjectOrder(in: destination, projects: projects)
            }
        }
        if destination == nil {
            for id in folderIDs(tokens) {
                if let index = folders.firstIndex(where: { $0.id == id }) {
                    folders[index].browserOrder = nextRootOrder(projects: projects, folders: folders)
                }
            }
        }
        ProjectBrowserPolicy.normalizeOrders(projects: &projects, folders: &folders)
    }

    static func relocateDragged(
        tokens: [String], to folderID: UUID?, target targetToken: String, placeAfter: Bool,
        projects: inout [NarabiProject], folders: inout [ProjectFolder]
    ) {
        var destination = destinationTokens(folderID: folderID, projects: projects, folders: folders)
        destination.removeAll { tokens.contains($0) }
        let insertion: Int
        if targetToken == "__end__" {
            insertion = destination.count
        } else if let targetIndex = destination.firstIndex(of: targetToken) {
            insertion = min(targetIndex + (placeAfter ? 1 : 0), destination.count)
        } else {
            insertion = destination.count
        }
        let movable = tokens.filter {
            if case .project? = ProjectBrowserMutationPolicy.Token($0) { return true }
            return folderID == nil && ProjectBrowserMutationPolicy.Token($0) != nil
        }
        destination.insert(contentsOf: movable, at: insertion)
        for id in projectIDs(tokens) {
            if let index = projects.firstIndex(where: { $0.id == id }) {
                projects[index].folderID = folderID
            }
        }
        apply(destination, folderID: folderID, projects: &projects, folders: &folders)
        ProjectBrowserPolicy.normalizeOrders(projects: &projects, folders: &folders)
    }

    static func reorder(
        tokens: [String], in folderID: UUID?, target targetToken: String, placeAfter: Bool,
        projects: inout [NarabiProject], folders: inout [ProjectFolder]
    ) {
        var ordered = destinationTokens(folderID: folderID, projects: projects, folders: folders)
        let moving = ordered.filter { tokens.contains($0) }
        ordered.removeAll { moving.contains($0) }
        guard let targetIndex = ordered.firstIndex(of: targetToken) else { return }
        ordered.insert(contentsOf: moving, at: min(targetIndex + (placeAfter ? 1 : 0), ordered.count))
        apply(ordered, folderID: folderID, projects: &projects, folders: &folders)
    }

    private static func destinationTokens(
        folderID: UUID?, projects: [NarabiProject], folders: [ProjectFolder]
    ) -> [String] {
        if let folderID {
            return ProjectBrowserPolicy.projects(in: folderID, projects: projects)
                .map { ProjectBrowserMutationPolicy.Token.project($0.id).rawValue }
        }
        return ProjectBrowserPolicy.rootItems(projects: projects, folders: folders).compactMap { record in
            if let folder = record.folder {
                return ProjectBrowserMutationPolicy.Token.folder(folder.id).rawValue
            }
            if let project = record.project {
                return ProjectBrowserMutationPolicy.Token.project(project.id).rawValue
            }
            return nil
        }
    }

    private static func apply(
        _ tokens: [String], folderID: UUID?,
        projects: inout [NarabiProject], folders: inout [ProjectFolder]
    ) {
        for (order, rawValue) in tokens.enumerated() {
            guard let token = ProjectBrowserMutationPolicy.Token(rawValue) else { continue }
            switch token {
            case .folder(let id):
                guard folderID == nil,
                    let index = folders.firstIndex(where: { $0.id == id })
                else { continue }
                folders[index].browserOrder = order
            case .project(let id):
                guard let index = projects.firstIndex(where: { $0.id == id }) else { continue }
                projects[index].folderID = folderID
                projects[index].browserOrder = order
            }
        }
    }

    private static func projectIDs(_ tokens: [String]) -> [UUID] {
        tokens.compactMap {
            guard case .project(let id)? = ProjectBrowserMutationPolicy.Token($0) else { return nil }
            return id
        }
    }

    private static func folderIDs(_ tokens: [String]) -> [UUID] {
        tokens.compactMap {
            guard case .folder(let id)? = ProjectBrowserMutationPolicy.Token($0) else { return nil }
            return id
        }
    }

    private static func nextProjectOrder(in folderID: UUID?, projects: [NarabiProject]) -> Int {
        projects.filter { $0.folderID == folderID }.map(\.browserOrder).max().map { $0 + 1 } ?? 0
    }

    private static func nextRootOrder(
        projects: [NarabiProject], folders: [ProjectFolder]
    ) -> Int {
        max(
            folders.map(\.browserOrder).max() ?? -1,
            projects.filter { $0.folderID == nil }.map(\.browserOrder).max() ?? -1
        ) + 1
    }
}
