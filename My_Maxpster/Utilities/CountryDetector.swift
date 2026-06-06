//
//  CountryDetector.swift
//  My_Maxpster
//
//  Extracts a country name from a free-form Mapstr address, since their CSV/GeoJSON
//  exports don't include an explicit country field. Matches the trailing token(s)
//  against a known multilingual list and normalizes to an English canonical name.
//

import Foundation

enum CountryDetector {
    /// Returns a canonical English country name found at the end of `address`, or
    /// an empty string if no known country is matched.
    nonisolated static func country(in address: String) -> String {
        let cleaned = address
            .replacingOccurrences(of: ",", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "" }

        let tokens = cleaned.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
        // Try the trailing 1..3 tokens, longest first ("United States", "Republic", etc.)
        for tailCount in stride(from: min(3, tokens.count), through: 1, by: -1) {
            let candidate = tokens.suffix(tailCount).joined(separator: " ")
            if let normalized = normalize(candidate) {
                return normalized
            }
        }
        return ""
    }

    nonisolated private static func normalize(_ raw: String) -> String? {
        let key = raw
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
        return aliases[key]
    }

    /// Aliases → canonical English name. Includes English, French, native, and shorthand forms.
    nonisolated private static let aliases: [String: String] = {
        var d: [String: String] = [:]
        func add(_ canonical: String, _ forms: [String]) {
            d[canonical.lowercased()] = canonical
            for f in forms {
                let key = f.lowercased().folding(options: .diacriticInsensitive, locale: .current)
                d[key] = canonical
            }
        }
        add("United States",  ["united states", "usa", "u.s.a.", "u.s.", "us", "etats-unis", "états-unis"])
        add("United Kingdom", ["united kingdom", "uk", "great britain", "royaume-uni", "england"])
        add("France",         ["france"])
        add("Germany",        ["germany", "allemagne", "deutschland"])
        add("Italy",          ["italy", "italie", "italia"])
        add("Spain",          ["spain", "espagne", "españa", "espana"])
        add("Portugal",       ["portugal"])
        add("Netherlands",    ["netherlands", "pays-bas", "nederland", "holland"])
        add("Belgium",        ["belgium", "belgique", "belgië", "belgie"])
        add("Luxembourg",     ["luxembourg"])
        add("Switzerland",    ["switzerland", "suisse", "schweiz", "svizzera"])
        add("Austria",        ["austria", "autriche", "österreich", "osterreich"])
        add("Ireland",        ["ireland", "irlande", "éire", "eire"])
        add("Greece",         ["greece", "grèce", "grece", "ellada", "elláda"])
        add("Denmark",        ["denmark", "danemark", "danmark"])
        add("Sweden",         ["sweden", "suède", "suede", "sverige"])
        add("Norway",         ["norway", "norvège", "norvege", "norge"])
        add("Finland",        ["finland", "finlande", "suomi"])
        add("Iceland",        ["iceland", "islande", "ísland", "island"])
        add("Poland",         ["poland", "pologne", "polska"])
        add("Czech Republic", ["czech republic", "république tchèque", "republique tcheque", "tchequie", "czechia", "česko", "ceska republika"])
        add("Slovenia",       ["slovenia", "slovénie", "slovenia"])
        add("Slovakia",       ["slovakia", "slovaquie", "slovensko"])
        add("Hungary",        ["hungary", "hongrie", "magyarország", "magyarorszag"])
        add("Romania",        ["romania", "roumanie", "românia"])
        add("Bulgaria",       ["bulgaria", "bulgarie"])
        add("Croatia",        ["croatia", "croatie", "hrvatska"])
        add("Serbia",         ["serbia", "serbie", "srbija"])
        add("Russia",         ["russia", "russie"])
        add("Ukraine",        ["ukraine"])
        add("Turkey",         ["turkey", "turquie", "türkiye", "turkiye"])
        add("Cyprus",         ["cyprus", "chypre"])
        add("Malta",          ["malta", "malte"])
        add("Canada",         ["canada"])
        add("Mexico",         ["mexico", "mexique", "méxico"])
        add("Cuba",           ["cuba"])
        add("Bahamas",        ["bahamas"])
        add("Costa Rica",     ["costa rica"])
        add("Brazil",         ["brazil", "brésil", "bresil", "brasil"])
        add("Argentina",      ["argentina", "argentine"])
        add("Chile",          ["chile", "chili"])
        add("Peru",           ["peru", "pérou", "perou"])
        add("Colombia",       ["colombia", "colombie"])
        add("China",          ["china", "chine", "中国"])
        add("Japan",          ["japan", "japon", "nippon", "日本"])
        add("South Korea",    ["south korea", "corée du sud", "coree du sud", "korea"])
        add("Thailand",       ["thailand", "thaïlande", "thailande"])
        add("Vietnam",        ["vietnam", "viêt nam", "viet nam"])
        add("Singapore",      ["singapore", "singapour"])
        add("Indonesia",      ["indonesia", "indonésie", "indonesie"])
        add("Malaysia",       ["malaysia", "malaisie"])
        add("Philippines",    ["philippines"])
        add("India",          ["india", "inde"])
        add("Australia",      ["australia", "australie"])
        add("New Zealand",    ["new zealand", "nouvelle-zélande", "nouvelle zelande"])
        add("South Africa",   ["south africa", "afrique du sud"])
        add("Morocco",        ["morocco", "maroc"])
        add("Tunisia",        ["tunisia", "tunisie"])
        add("Egypt",          ["egypt", "égypte", "egypte"])
        add("United Arab Emirates", ["united arab emirates", "uae", "emirats arabes unis", "émirats arabes unis"])
        add("Israel",         ["israel", "israël"])
        add("French Polynesia", ["french polynesia", "polynésie française", "polynesie francaise"])
        return d
    }()
}
