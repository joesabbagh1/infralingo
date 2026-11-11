import Foundation

enum BankError: LocalizedError {
    case invalid(String)

    var errorDescription: String? { if case .invalid(let message) = self { message } else { nil } }
}

enum BankJSON {
    private struct CategoryDto: Decodable {
        let id: String
        let title: String
        let blurb: String
        let order: Int
    }

    private struct SkillDto: Decodable {
        let id: String
        let categoryId: String
        let title: String
        let order: Int
    }

    private struct QuestionDto: Decodable {
        let id: String
        let skillId: String
        let difficulty: String
        let prompt: String
        let choices: [String]
        let answer: Int
        let explanation: String
    }

    private struct ManifestDto: Decodable {
        let questionFiles: [String]
    }

    static func parseManifest(_ raw: String) throws -> [String] {
        try JSONDecoder().decode(ManifestDto.self, from: Data(raw.utf8)).questionFiles
    }

    static func parse(categoriesJson: String, skillsJson: String, questionJsons: [String]) throws -> Bank {
        let decoder = JSONDecoder()
        let categories = try decoder.decode([CategoryDto].self, from: Data(categoriesJson.utf8)).map {
            Category(id: $0.id, title: $0.title, blurb: $0.blurb, order: $0.order)
        }
        let skills = try decoder.decode([SkillDto].self, from: Data(skillsJson.utf8)).map {
            Skill(id: $0.id, categoryId: $0.categoryId, title: $0.title, order: $0.order)
        }
        let questions = try questionJsons.flatMap { raw -> [Question] in
            try decoder.decode([QuestionDto].self, from: Data(raw.utf8)).map { dto in
                Question(
                    id: dto.id,
                    skillId: dto.skillId,
                    difficulty: Difficulty.parse(dto.difficulty),
                    prompt: dto.prompt.trimmingCharacters(in: .whitespacesAndNewlines),
                    choices: dto.choices.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
                    answerIndex: dto.answer,
                    explanation: dto.explanation.trimmingCharacters(in: .whitespacesAndNewlines),
                )
            }
        }
        try validate(categories: categories, skills: skills, questions: questions)
        return Bank(
            categories: categories.sorted { $0.order < $1.order },
            skills: skills.sorted { ($0.categoryId, $0.order) < ($1.categoryId, $1.order) },
            questions: questions,
        )
    }

    static func validate(categories: [Category], skills: [Skill], questions: [Question]) throws {
        func check(_ condition: Bool, _ message: @autoclosure () -> String) throws {
            if !condition { throw BankError.invalid(message()) }
        }
        let categoryIds = categories.map(\.id)
        try check(categoryIds.count == Set(categoryIds).count, "Duplicate category id")
        let skillIds = skills.map(\.id)
        try check(skillIds.count == Set(skillIds).count, "Duplicate skill id")
        let questionIds = questions.map(\.id)
        try check(questionIds.count == Set(questionIds).count, "Duplicate question id")
        let categorySet = Set(categoryIds)
        for skill in skills {
            try check(categorySet.contains(skill.categoryId), "Skill \(skill.id) has unknown category \(skill.categoryId)")
        }
        let skillSet = Set(skillIds)
        for question in questions {
            try check(skillSet.contains(question.skillId), "Question \(question.id) has unknown skill \(question.skillId)")
            try check(question.choices.count == 4, "Question \(question.id) needs 4 choices")
            try check(question.choices.count == Set(question.choices).count, "Question \(question.id) has duplicate choices")
            try check(question.choices.indices.contains(question.answerIndex), "Question \(question.id) has a bad answer index")
            try check(!question.prompt.trimmingCharacters(in: .whitespaces).isEmpty, "Question \(question.id) has an empty prompt")
            try check(!question.explanation.trimmingCharacters(in: .whitespaces).isEmpty, "Question \(question.id) has an empty explanation")
        }
        let bySkill = Dictionary(grouping: questions, by: \.skillId)
        for skill in skills {
            let count = bySkill[skill.id]?.count ?? 0
            try check(count >= 4, "Skill \(skill.id) has \(count) questions, need at least 4")
        }
        let skillCategory = Dictionary(skills.map { ($0.id, $0.categoryId) }, uniquingKeysWith: { a, _ in a })
        for category in categories {
            let medium = questions.contains { question in
                skillCategory[question.skillId] == category.id && question.difficulty == .medium
            }
            try check(medium, "Category \(category.id) has no medium question for placement")
        }
    }
}
