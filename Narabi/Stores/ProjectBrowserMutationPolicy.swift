import Foundation

nonisolated enum ProjectBrowserMutationPolicy {
    enum Token: Equatable {
        case project(UUID)
        case folder(UUID)

        init?(_ rawValue: String) {
            let parts = rawValue.split(separator: ":", maxSplits: 1)
            guard parts.count == 2, let id = UUID(uuidString: String(parts[1])) else { return nil }
            switch parts[0] {
            case "project": self = .project(id)
            case "folder": self = .folder(id)
            default: return nil
            }
        }

        var rawValue: String {
            switch self {
            case .project(let id): return "project:\(id.uuidString)"
            case .folder(let id): return "folder:\(id.uuidString)"
            }
        }
    }

    static func duplicate(
        tokens: [String], projects: inout [NarabiProject], folders: inout [ProjectFolder],
        now: () -> Date = Date.init, makeID: () -> UUID = UUID.init
    ) {
        for token in tokens.compactMap(Token.init) {
            switch token {
            case .project(let id):
                guard let original = projects.first(where: { $0.id == id }) else { continue }
                var copy = deepCopy(original, now: now(), makeID: makeID)
                copy.browserOrder = original.browserOrder + 1
                projects.append(copy)
                shiftProjects(
                    after: original.browserOrder, folderID: original.folderID,
                    excluding: copy.id, projects: &projects)
            case .folder(let id):
                guard let original = folders.first(where: { $0.id == id }) else { continue }
                var folderCopy = original
                folderCopy.id = makeID()
                folderCopy.browserOrder = original.browserOrder + 1
                folders.append(folderCopy)
                let children = ProjectBrowserPolicy.projects(in: id, projects: projects)
                for child in children {
                    var childCopy = deepCopy(child, now: now(), makeID: makeID)
                    childCopy.folderID = folderCopy.id
                    projects.append(childCopy)
                }
                shiftRoot(
                    after: original.browserOrder, excluding: folderCopy.id,
                    projects: &projects, folders: &folders)
            }
        }
    }

    static func delete(
        tokens: [String], projects: inout [NarabiProject], folders: inout [ProjectFolder]
    ) {
        let parsed = tokens.compactMap(Token.init)
        let folderIDs = Set(
            parsed.compactMap { token -> UUID? in
                if case .folder(let id) = token { return id }
                return nil
            })
        let projectIDs = Set(
            parsed.compactMap { token -> UUID? in
                if case .project(let id) = token { return id }
                return nil
            })
        projects.removeAll { project in
            projectIDs.contains(project.id)
                || project.folderID.map(folderIDs.contains) == true
        }
        folders.removeAll { folderIDs.contains($0.id) }
        ProjectBrowserPolicy.normalizeOrders(projects: &projects, folders: &folders)
    }

    private static func deepCopy(
        _ project: NarabiProject, now: Date, makeID: () -> UUID
    ) -> NarabiProject {
        var copy = project
        copy.id = makeID()
        copy.updatedAt = now
        copy.pages = copy.pages.map { page in
            var result = page
            result.id = makeID()
            return result
        }
        copy.tray = copy.tray.map { page in
            var result = page
            result.id = makeID()
            return result
        }
        copy.deleted = copy.deleted.map { page in
            var result = page
            result.id = makeID()
            return result
        }
        return copy
    }

    private static func shiftProjects(
        after order: Int, folderID: UUID?, excluding: UUID,
        projects: inout [NarabiProject]
    ) {
        for index in projects.indices
        where projects[index].folderID == folderID
            && projects[index].id != excluding
            && projects[index].browserOrder > order
        {
            projects[index].browserOrder += 1
        }
    }

    private static func shiftRoot(
        after order: Int, excluding: UUID,
        projects: inout [NarabiProject], folders: inout [ProjectFolder]
    ) {
        for index in folders.indices
        where folders[index].id != excluding && folders[index].browserOrder > order {
            folders[index].browserOrder += 1
        }
        for index in projects.indices
        where projects[index].folderID == nil && projects[index].browserOrder > order {
            projects[index].browserOrder += 1
        }
    }
}
