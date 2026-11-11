import Foundation

/// Loads the question bank out of the bundle's `content` folder.
struct ContentRepository {
    let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func load() throws -> Bank {
        func read(_ path: String) throws -> String {
            // "questions/linux.json" → directory "content/questions", file "linux", extension "json".
            let directory: String
            let fileName: String
            if let slash = path.lastIndex(of: "/") {
                directory = "content/" + path[..<slash]
                fileName = String(path[path.index(after: slash)...])
            } else {
                directory = "content"
                fileName = path
            }
            let name = (fileName as NSString).deletingPathExtension
            let `extension` = (fileName as NSString).pathExtension
            guard let url = bundle.url(forResource: name, withExtension: `extension`, subdirectory: directory)
            else { throw BankError.invalid("Missing bundled file content/\(path)") }
            return try String(contentsOf: url, encoding: .utf8)
        }
        let manifest = try read("manifest.json")
        let categories = try read("categories.json")
        let skills = try read("skills.json")
        let questionJsons = try BankJSON.parseManifest(manifest).map { name -> String in
            try read("questions/\(name)")
        }
        return try BankJSON.parse(categoriesJson: categories, skillsJson: skills, questionJsons: questionJsons)
    }
}
