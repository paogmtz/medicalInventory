import Foundation

// MARK: - Parsed Data Structures

/// A single extracted dose value from OCR text (e.g., "500 mg", "10 mcg/mL").
struct ParsedDose: Sendable {
    let value: String       // "500", "0.25"
    let unit: String        // "mg", "mcg", "ml"
    let rawMatch: String    // "500 mg", "10 mcg/mL"
}

/// A parsed expiration date extracted from OCR text.
struct ParsedExpiration: Sendable {
    let label: String       // "EXP", "CAD", "VENCE", etc.
    let dateString: String  // "03/2027", "15/03/2027"
    let date: Date?         // Parsed Date (last day of month for MM/YYYY formats)
}

/// A parsed package quantity from OCR text (e.g., "30 tablets", "120 mL").
struct ParsedQuantity: Sendable {
    let count: Int
    let unit: String
    let rawMatch: String
}

// MARK: - OCR Parser

/// Stateless parser that extracts structured medicine data from raw OCR text
/// using regex patterns. Supports bilingual (English + Spanish) pharmaceutical
/// packaging text.
///
/// All methods are static pure functions with no side effects or network calls.
enum OCRParser {

    // MARK: - Dose Extraction

    /// Extract dose values from text.
    ///
    /// Matches patterns such as:
    /// - Simple: "500 mg", "10 mcg", "0.25 g", "100 IU"
    /// - Compound: "10 mg/mL", "15 mg/5 mL", "100 mg/5mL"
    /// - Decimal with comma: "0,5 mg" (European notation)
    ///
    /// - Parameter text: The full OCR text (lines joined by newlines).
    /// - Returns: All matched dose values, ordered by appearance.
    static func extractDoses(from text: String) -> [ParsedDose] {
        // Numeric value (integer or decimal with . or ,)
        // Followed by a pharmaceutical unit
        // Optionally followed by a concentration denominator (/5 mL, /mL)
        let pattern = #"(\d+(?:[.,]\d+)?)\s*(mg|mcg|µg|g|kg|m[lL]|[lL]|IU|UI|mEq)(?:\s*/\s*\d*\s*m?[lL])?"#

        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: .caseInsensitive
        ) else {
            return []
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)

        return matches.compactMap { match in
            guard let valueRange = Range(match.range(at: 1), in: text),
                  let unitRange = Range(match.range(at: 2), in: text),
                  let fullRange = Range(match.range, in: text) else {
                return nil
            }
            return ParsedDose(
                value: String(text[valueRange]),
                unit: String(text[unitRange]).lowercased(),
                rawMatch: String(text[fullRange])
            )
        }
    }

    // MARK: - Form Detection

    /// Detect the pharmaceutical form from bilingual text.
    ///
    /// Scans for English and Spanish terms and maps them to `MedicineForm` cases.
    /// Returns the first match found (patterns are ordered by specificity).
    ///
    /// Supported English terms:
    ///   tablet, tab, capsule, cap, syrup, cream, ointment, drops, gtt,
    ///   injection, injectable, inj, gel, spray, solution, suspension,
    ///   patch, powder, lozenge, suppository, inhaler
    ///
    /// Supported Spanish terms:
    ///   comprimido, tableta, pastilla, gragea, capsula, jarabe, sirope,
    ///   crema, pomada, ungento, gotas, inyeccion, inyectable, solucion,
    ///   suspension, parche, sobre, supositorio, aerosol, inhalador,
    ///   ovulo, ampolla
    ///
    /// - Parameter text: The full OCR text.
    /// - Returns: The detected `MedicineForm`, or `nil` if no match.
    static func extractForm(from text: String) -> MedicineForm? {
        let mappings: [(pattern: String, form: MedicineForm)] = [
            // --- English ---
            (#"\b(?:tablets?|tabs?)\b"#,                     .tablet),
            (#"\b(?:capsules?|caps?)\b"#,                    .capsule),
            (#"\b(?:syrups?)\b"#,                            .syrup),
            (#"\b(?:creams?|ointments?|gel)\b"#,             .cream),
            (#"\b(?:drops?|gtt)\b"#,                         .drops),
            (#"\b(?:injection|injectable|inj)\b"#,           .injection),
            (#"\b(?:solution|soln?|suspension|susp)\b"#,     .syrup),
            (#"\b(?:spray|inhaler)\b"#,                      .other),
            (#"\b(?:patch(?:es)?)\b"#,                       .other),
            (#"\b(?:powder)\b"#,                             .other),
            (#"\b(?:lozenges?)\b"#,                          .tablet),
            (#"\b(?:suppository|suppositories)\b"#,          .other),

            // --- Spanish ---
            (#"\b(?:comprimidos?|tabletas?|pastillas?|grageas?)\b"#, .tablet),
            (#"\b(?:c[aá]psulas?)\b"#,                       .capsule),
            (#"\b(?:jarabes?|sirope)\b"#,                    .syrup),
            (#"\b(?:cremas?|pomadas?|ung[uü]entos?|gel)\b"#, .cream),
            (#"\b(?:gotas)\b"#,                              .drops),
            (#"\b(?:inyecci[oó]n|inyectable)\b"#,            .injection),
            (#"\b(?:soluci[oó]n|suspensi[oó]n)\b"#,         .syrup),
            (#"\b(?:sobres?)\b"#,                            .other),
            (#"\b(?:supositorio)\b"#,                        .other),
            (#"\b(?:aerosol|inhalador)\b"#,                  .other),
            (#"\b(?:[oó]vulos?)\b"#,                         .other),
            (#"\b(?:ampollas?)\b"#,                          .injection),
            (#"\b(?:parches?)\b"#,                           .other),
        ]

        let lowered = text.lowercased()

        for (pattern, form) in mappings {
            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: .caseInsensitive
            ) else {
                continue
            }
            let nsRange = NSRange(lowered.startIndex..., in: lowered)
            if regex.firstMatch(in: lowered, range: nsRange) != nil {
                return form
            }
        }

        return nil
    }

    // MARK: - Expiration Date Extraction

    /// Extract an expiration date from bilingual packaging text.
    ///
    /// Looks for a recognized label keyword followed by a date in one of many
    /// common pharmaceutical formats.
    ///
    /// Recognized labels (English):
    ///   EXP, EXPIRY, EXPIRES, EXP DATE, USE BY, BEST BEFORE
    ///
    /// Recognized labels (Spanish):
    ///   CAD, CADUCIDAD, FECHA DE CADUCIDAD, VENCE, VTO, VENCIMIENTO,
    ///   FV, FECHA DE VENCIMIENTO, VAL, VALIDEZ, FECHA DE EXPIRACION
    ///
    /// Recognized date formats:
    ///   MM/YYYY, dd/MM/YYYY, YYYY-MM-dd, dd.MM.YYYY, MM.YYYY,
    ///   MM-YYYY, dd-MM-YYYY, MMM YYYY (English/Spanish month names)
    ///
    /// For month-only formats (e.g., "03/2027"), the returned `Date` is set to
    /// the **last day** of that month, matching pharmaceutical convention.
    ///
    /// - Parameter text: The full OCR text.
    /// - Returns: A `ParsedExpiration` if found, or `nil`.
    static func extractExpiration(from text: String) -> ParsedExpiration? {
        // Label patterns (English + Spanish)
        let labelPattern = [
            #"EXP(?:IRY|IRES)?\.?\s*(?:DATE)?"#,
            #"USE\s*BY"#,
            #"BEST\s*BEFORE"#,
            #"CAD(?:UCIDAD)?"#,
            #"FECHA\s*(?:DE\s*)?(?:CADUCIDAD|VENCIMIENTO|EXPIRACI[OÓ]N)"#,
            #"VENCE"#,
            #"VTO\.?"#,
            #"VENCIMIENTO"#,
            #"FV"#,
            #"VAL(?:IDEZ)?"#,
        ].joined(separator: "|")

        // Date patterns covering multiple formats
        let datePatterns = [
            #"(\d{1,2})\s*[/.\-]\s*(\d{4})"#,                              // MM/YYYY
            #"(\d{1,2})\s*[/.\-]\s*(\d{1,2})\s*[/.\-]\s*(\d{2,4})"#,      // dd/MM/YYYY
            #"(\d{4})\s*[/.\-]\s*(\d{1,2})\s*[/.\-]\s*(\d{1,2})"#,        // YYYY-MM-dd
            #"([A-Za-zÁÉÍÓÚáéíóú]{3,})\s*[/.\-\s]\s*(\d{4})"#,           // MMM YYYY
        ].joined(separator: "|")

        let combinedPattern = "(?:\(labelPattern))[:\\s./\\-]*(?:\(datePatterns))"

        guard let regex = try? NSRegularExpression(
            pattern: combinedPattern,
            options: .caseInsensitive
        ) else {
            return nil
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let fullRange = Range(match.range, in: text) else {
            return nil
        }

        let raw = String(text[fullRange])

        // Separate the label from the date portion
        let (label, dateString) = splitLabelAndDate(from: raw)

        let parsedDate = parseDate(dateString)

        return ParsedExpiration(
            label: label,
            dateString: dateString,
            date: parsedDate
        )
    }

    // MARK: - Quantity Extraction

    /// Extract package quantity from text.
    ///
    /// Matches patterns such as:
    /// - English: "30 tablets", "120 capsules", "100 mL", "60 pills"
    /// - Spanish: "30 comprimidos", "20 capsulas", "10 sobres", "5 ampollas"
    ///
    /// - Parameter text: The full OCR text.
    /// - Returns: A `ParsedQuantity` if found, or `nil`.
    static func extractQuantity(from text: String) -> ParsedQuantity? {
        let unitTerms = [
            // English
            "tablets?", "tabs?", "capsules?", "caps?", "pills?",
            "sachets?", "ampoules?", "vials?", "pieces?", "units?",
            // Volume / weight
            "mL", "ml", "L", "l", "g", "mg",
            // Spanish
            "comprimidos?", "tabletas?", "c[aá]psulas?", "pastillas?",
            "grageas?", "sobres?", "ampollas?", "unidades?", "piezas?",
        ].joined(separator: "|")

        let pattern = #"(\d+)\s*("#  + unitTerms + ")"

        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: .caseInsensitive
        ) else {
            return nil
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let countRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text),
              let fullRange = Range(match.range, in: text),
              let count = Int(text[countRange]) else {
            return nil
        }

        return ParsedQuantity(
            count: count,
            unit: String(text[unitRange]),
            rawMatch: String(text[fullRange])
        )
    }

    // MARK: - Confidence Scoring

    /// Compute an overall confidence score (0.0 -- 1.0) for the OCR parse result.
    ///
    /// The score is a weighted combination of:
    /// - **40%** from Vision's average OCR confidence (character-level accuracy).
    /// - **15%** if a dose was extracted.
    /// - **15%** if a pharmaceutical form was detected.
    /// - **20%** if an expiration date was found and parsed.
    /// - **10%** if a package quantity was extracted.
    ///
    /// UI thresholds:
    /// - >= 0.8: High confidence (green) -- auto-fill all fields.
    /// - 0.5 -- 0.79: Medium confidence (yellow) -- auto-fill with review prompt.
    /// - < 0.5: Low confidence (orange) -- partial fill, prompt manual entry.
    static func computeConfidence(
        averageOCRConfidence: Float,
        hasDose: Bool,
        hasForm: Bool,
        hasExpiration: Bool,
        hasQuantity: Bool
    ) -> Double {
        var score = Double(averageOCRConfidence) * 0.40
        if hasDose       { score += 0.15 }
        if hasForm       { score += 0.15 }
        if hasExpiration  { score += 0.20 }
        if hasQuantity   { score += 0.10 }
        return min(score, 1.0)
    }

    // MARK: - Private Helpers

    /// Split a matched string into the label portion and the date portion.
    ///
    /// For example, "EXP: 03/2027" -> ("EXP", "03/2027").
    private static func splitLabelAndDate(from raw: String) -> (label: String, dateString: String) {
        // Find where the first digit or month-name starts
        let labelEndPatterns = [
            #"[:\s./\-]*\d"#,
            #"[:\s./\-]*[A-Za-zÁÉÍÓÚáéíóú]{3,}\s*\d{4}"#,
        ]

        for pattern in labelEndPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
               let range = Range(match.range, in: raw) {
                let label = String(raw[raw.startIndex..<range.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                let dateString = String(raw[range.lowerBound...])
                    .trimmingCharacters(in: CharacterSet.whitespaces.union(.init(charactersIn: ":.-")))
                return (label, dateString)
            }
        }

        return (raw, raw)
    }

    /// Parse date strings in common pharmaceutical formats.
    ///
    /// For month-only formats (e.g., "03/2027"), returns the **last day** of that month,
    /// following pharmaceutical convention where "EXP 03/2027" means the product expires
    /// at the end of March 2027.
    private static func parseDate(_ string: String) -> Date? {
        let cleaned = string.trimmingCharacters(in: .whitespaces)

        // Ordered list of numeric date format attempts
        let formats: [(dateFormat: String, regex: String)] = [
            ("dd/MM/yyyy", #"^\d{1,2}/\d{1,2}/\d{4}$"#),
            ("MM/yyyy",    #"^\d{1,2}/\d{4}$"#),
            ("yyyy-MM-dd", #"^\d{4}-\d{1,2}-\d{1,2}$"#),
            ("dd.MM.yyyy", #"^\d{1,2}\.\d{1,2}\.\d{4}$"#),
            ("MM.yyyy",    #"^\d{1,2}\.\d{4}$"#),
            ("MM-yyyy",    #"^\d{1,2}-\d{4}$"#),
            ("dd-MM-yyyy", #"^\d{1,2}-\d{1,2}-\d{4}$"#),
        ]

        for (fmt, pattern) in formats {
            guard cleaned.range(of: pattern, options: .regularExpression) != nil else {
                continue
            }
            let formatter = DateFormatter()
            formatter.dateFormat = fmt
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)

            if let date = formatter.date(from: cleaned) {
                if !fmt.contains("dd") {
                    // Month-only: return the last day of that month
                    return Calendar.current.date(
                        byAdding: DateComponents(month: 1, day: -1),
                        to: date
                    )
                }
                return date
            }
        }

        // Try month-name formats: "MAR 2027", "Marzo 2027", "ENE 2028"
        if let date = parseMonthNameDate(cleaned) {
            return date
        }

        return nil
    }

    /// Parse dates with textual month names in English or Spanish.
    ///
    /// Handles abbreviated ("MAR", "ENE") and full ("March", "Marzo") month names.
    /// Returns the last day of the matched month.
    private static func parseMonthNameDate(_ string: String) -> Date? {
        let monthNamePattern = #"^([A-Za-zÁÉÍÓÚáéíóú]+)\s*[/\-.\s]\s*(\d{4})$"#
        guard let regex = try? NSRegularExpression(pattern: monthNamePattern),
              let match = regex.firstMatch(
                  in: string,
                  range: NSRange(string.startIndex..., in: string)
              ),
              let monthRange = Range(match.range(at: 1), in: string),
              let yearRange = Range(match.range(at: 2), in: string) else {
            return nil
        }

        let monthStr = String(string[monthRange])
        let yearStr = String(string[yearRange])

        // Try both English and Spanish locales
        for localeId in ["en_US_POSIX", "es_ES"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: localeId)
            formatter.timeZone = TimeZone(secondsFromGMT: 0)

            // Try abbreviated month name (e.g., "MAR", "ENE")
            formatter.dateFormat = "MMM yyyy"
            if let date = formatter.date(from: "\(monthStr) \(yearStr)") {
                return Calendar.current.date(
                    byAdding: DateComponents(month: 1, day: -1),
                    to: date
                )
            }

            // Try full month name (e.g., "March", "Marzo")
            formatter.dateFormat = "MMMM yyyy"
            if let date = formatter.date(from: "\(monthStr) \(yearStr)") {
                return Calendar.current.date(
                    byAdding: DateComponents(month: 1, day: -1),
                    to: date
                )
            }
        }

        return nil
    }
}
