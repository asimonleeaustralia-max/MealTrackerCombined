//
//  PhotoNutritionGuesser+Parsing.swift
//  MealTracker
//
//  OCR text recognition and nutrition parsing utilities split from PhotoNutritionGuesser.
//

import Foundation

extension PhotoNutritionGuesser {

    // MARK: - Parsing

    // DEBUG-aware entry point: forwards to diagnostics-collecting variant when DEBUG is active.
    static func parseNutrition(from rawText: String) -> GuessResult {
        #if DEBUG
        var diags: [String]? = []
        let r = parseNutrition(from: rawText, collecting: &diags)
        // We don’t emit here (caller logs); this keeps this function side-effect-free.
        return r
        #else
        var diags: [String]? = nil
        return parseNutrition_impl(from: rawText, collecting: &diags)
        #endif
    }

    #if DEBUG
    // DEBUG-only: collect human-readable diagnostics about misses and unit/keyword presence.
    static func parseNutrition(from rawText: String, collecting diags: inout [String]?) -> GuessResult {
        return parseNutrition_impl(from: rawText, collecting: &diags)
    }
    #endif

    // Core implementation with optional diagnostics sink (DEBUG passes a non-nil array).
    private static func parseNutrition_impl(from rawText: String, collecting diags: inout [String]?) -> GuessResult {
        // Normalize OCR text robustly for multilingual matching
        var normalizedLines = rawText
            .components(separatedBy: .newlines)
            .map { TextNormalizer.normalize($0) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Heuristic join for short continuation lines (helps split headers/values like "1990kJ" on new line)
        if !normalizedLines.isEmpty {
            var joined: [String] = []
            for line in normalizedLines {
                if let last = joined.last {
                    // Continuation if current line is short, starts with unit/number/punctuation, or is a header fragment
                    let isContinuation = line.count <= 6
                        || line.hasPrefix("kj")
                        || line.hasPrefix("kcal")
                        || line.range(of: #"^(per|avg|average|serve|serving|100g|100 ml|g|mg|ug|[0-9])"#, options: .regularExpression) != nil
                    if isContinuation {
                        joined[joined.count - 1] = (last + " " + line).trimmingCharacters(in: .whitespaces)
                        continue
                    }
                }
                joined.append(line)
            }
            normalizedLines = joined
        }

        let lines = normalizedLines

        var result = GuessResult()

        // If no lines at all, short-circuit
        if lines.isEmpty {
            diags?.append("No normalized lines after OCR; nothing to parse.")
            return result
        }

        // Regex helpers with non-Latin-aware boundaries
        func firstMatch(_ pattern: String, in text: String) -> NSTextCheckingResult? {
            let options: NSRegularExpression.Options = []
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            return regex.firstMatch(in: text, options: [], range: range)
        }

        func extractNumber(from line: String, group: Int, in match: NSTextCheckingResult) -> String? {
            guard let r = Range(match.range(at: group), in: line) else { return nil }
            return String(line[r])
        }

        func toInt(_ s: String?) -> Int? {
            guard var str = s?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty else { return nil }
            str = str.replacingOccurrences(of: ",", with: ".")
            if let val = Double(str) {
                return Int(round(val))
            }
            let allowed = Set("0123456789.")
            let filtered = String(str.filter { allowed.contains($0) })
            if let val = Double(filtered) {
                return Int(round(val))
            }
            return nil
        }

        // For grams: convert OCR numeric to Double (preserve decimals if present)
        func toDouble(_ s: String?) -> Double? {
            guard var str = s?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty else { return nil }
            str = str.replacingOccurrences(of: ",", with: ".")
            if let v = Double(str) { return v }
            let allowed = Set("0123456789.")
            let filtered = String(str.filter { allowed.contains($0) })
            return Double(filtered)
        }

        // For mg values we want Double for vitamins/potassium
        func toDoubleMg(_ s: String?) -> Double? {
            guard var str = s?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty else { return nil }
            str = str.replacingOccurrences(of: ",", with: ".")
            if let v = Double(str) { return v }
            let allowed = Set("0123456789.")
            let filtered = String(str.filter { allowed.contains($0) })
            return Double(filtered)
        }

        // Boundary pattern: start or separator before; separator or end after
        let BSTART = "(?:(?<=^)|(?<=[\\s,:：•·\\-\\(\\)\\[\\] ，。、 、|/]))"
        let BEND = "(?:(?=$)|(?=[\\s,:：•·\\-\\(\\)\\[\\] ，。、、|/]))"

        // Localized unit fragments
        let grams = LocalizedUnits.gramsPattern
        let milligrams = LocalizedUnits.milligramsPattern
        let micrograms = LocalizedUnits.microgramsPattern
        let kcalUnits = LocalizedUnits.kcalPattern
        let kJUnits = LocalizedUnits.kjPattern

        // Build a single alternation for keywords safely escaped
        func alternation(_ words: [String]) -> String {
            words.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        }

        func parseGramValue(_ line: String, keywords: [String]) -> Double? {
            let joined = alternation(keywords)
            let pattern = "\(BSTART)(?:\(joined))\(BEND)[^\\n\\r\\d]{0,20}([0-9]+[\\.,]?[0-9]*)\\s*(?:\(grams))\(BEND)"
            if let m = firstMatch(pattern, in: line) {
                return toDouble(extractNumber(from: line, group: 1, in: m))
            }
            return nil
        }

        // Return Int? mg (for sodium and minerals that remain Int)
        func parseMilligramValueInt(_ line: String, keywords: [String]) -> Int? {
            let joined = alternation(keywords)
            let pattern = "\(BSTART)(?:\(joined))\(BEND)[^\\n\\r\\d]{0,20}([0-9]+[\\.,]?[0-9]*)\\s*(?:\(milligrams))\(BEND)"
            if let m = firstMatch(pattern, in: line) {
                return toInt(extractNumber(from: line, group: 1, in: m))
            }
            return nil
        }

        // Return Double? mg (for vitamins and potassium)
        func parseMilligramValueDouble(_ line: String, keywords: [String]) -> Double? {
            let joined = alternation(keywords)
            let pattern = "\(BSTART)(?:\(joined))\(BEND)[^\\n\\r\\d]{0,20}([0-9]+[\\.,]?[0-9]*)\\s*(?:\(milligrams))\(BEND)"
            if let m = firstMatch(pattern, in: line) {
                return toDoubleMg(extractNumber(from: line, group: 1, in: m))
            }
            return nil
        }

        // µg -> mg as Int? (for minerals that remain Int)
        func parseMicrogramValueInt(_ line: String, keywords: [String]) -> Int? {
            let joined = alternation(keywords)
            let pattern = "\(BSTART)(?:\(joined))\(BEND)[^\\n\\r\\d]{0,20}([0-9]+[\\.,]?[0-9]*)\\s*(?:\(micrograms))\(BEND)"
            if let m = firstMatch(pattern, in: line) {
                if let micro = toInt(extractNumber(from: line, group: 1, in: m)) {
                    let mg = Int(round(Double(micro) / 1000.0))
                    return mg
                }
            }
            return nil
        }

        // µg -> mg as Double? (for vitamins and potassium)
        func parseMicrogramValueDouble(_ line: String, keywords: [String]) -> Double? {
            let joined = alternation(keywords)
            let pattern = "\(BSTART)(?:\(joined))\(BEND)[^\\n\\r\\d]{0,20}([0-9]+[\\.,]?[0-9]*)\\s*(?:\(micrograms))\(BEND)"
            if let m = firstMatch(pattern, in: line) {
                if let microStr = extractNumber(from: line, group: 1, in: m) {
                    let micro = toDoubleMg(microStr) ?? 0.0
                    return micro / 1000.0
                }
            }
            return nil
        }

        func parseSodiumOrSalt(_ line: String) -> Int? {
            if let mg = parseMilligramValueInt(line, keywords: sodiumKeys) {
                return mg
            }
            if let g = parseGramValue(line, keywords: sodiumKeys) {
                return Int(round(g * 1000.0))
            }
            // Salt line (convert g of salt to mg sodium: 1 g salt ≈ 400 mg sodium)
            if let gSalt = parseGramValue(line, keywords: saltKeys) {
                let sodiumMg = Int(round(Double(gSalt) * 400.0))
                return sodiumMg
            }
            return nil
        }

        func parseEnergy(_ line: String) -> Int? {
            // kcal direct with localized tokens
            if let mKcal = firstMatch("\(BSTART)(?:\(energyKeysKcal))\(BEND)[^\\d]{0,20}([0-9]+[\\.,]?[0-9]*)\\s*(?:\(kcalUnits))\(BEND)", in: line) {
                if let val = toInt(extractNumber(from: line, group: 1, in: mKcal)) {
                    return val
                }
            }
            // kJ conversion
            if let mKJ = firstMatch("\(BSTART)(?:\(energyKeysKJ))\(BEND)[^\\d]{0,20}([0-9]+[\\.,]?[0-9]*)\\s*(?:\(kJUnits))\(BEND)", in: line) {
                if let kj = toInt(extractNumber(from: line, group: 1, in: mKJ)) {
                    let kcal = Int(round(Double(kj) / 4.184))
                    return kcal
                }
            }
            // Bare "xxx kcal" localized, allow optional missing space after number (handled in normalizer but keep tolerant)
            if let mBare = firstMatch("([0-9]+[\\.,]?[0-9]*)\\s*(?:\(kcalUnits))\(BEND)", in: line),
               let val = toInt(extractNumber(from: line, group: 1, in: mBare)) {
                return val
            }
            return nil
        }

        // MARK: Multilingual keyword aliases

        // Carbohydrates (include AU/NZ “carbohydrate, total” variants)
        let carbsKeys: [String] = [
            "carb","carbs","carbohydrate","carbohydrates",
            "carbohydrate total","carbohydrate, total","total carbohydrate","total carbohydrates",
            "glucide","glucides","dont sucres",
            "kohlenhydrat","kohlenhydrate","davon zucker",
            "hidratos de carbono","hidratos","carbohidrato","carbohidratos","carboidrato","carboidratos",
            "carboidrati","di cui zuccheri",
            "koolhydraten","waarvan suikers",
            "kolhydrater","kulhydrater","karbohydrater",
            "węglowodany","cukry","sacharidy","cukry z toho","sacharidov","cukry z toho","szénhidrát","zaharuri","carbohidrați",
            "υδατάνθρακες","εκ των οποίων σάκχαρα",
            "karbonhidrat","şekerler",
            "углеводы","в том числе сахара","вуглеводи","в т.ч. цукри","въглехидрати","от които захари",
            "كربوهیدرات","نشويات","منها سكريات","منها سكر",
            "פחמימות","מתוכן סוכרים",
            "कार्बोहाइड्रेट","कार्ब्स","शर्करा","जिसमें शर्करा","कार्बोहाइड्रेट्स",
            "কার্বোহাইড্রেট","কার্বস","চিনি","যার মধ্যে চিনি",
            "คาร์โบไฮเดรต","คาร์บ","น้ำตาลรวม","ซึ่งน้ำตาล",
            "carbohydrat","carb","tinh bột","đường trong đó",
            "karbohidrat","karbo","gula termasuk",
            "碳水化合物","碳水","其中糖","糖",
            "炭水化物","糖質","うち糖類",
            "탄수화물","당류","그중 당류","그중당류"
        ]

        // Protein
        let proteinKeys: [String] = [
            "protein","proteins","proteína","proteínas","proteine","eiweiß","eiweiss","eiweıß",
            "proteína","proteine","proteínas",
            "proteine","протеин","белки","білки","протеини",
            "العربوين","ब्रो틴",
            "חלבון",
            "प्रोटीन","प्रोटिन","प्रोटिन",
            "প্রোটিন",
            "โปรตีน",
            "proteină","proteine","proteínas",
            "蛋白质","蛋白","たんぱく質","蛋白質","단백질"
        ]

        // Fat
        let fatKeys: [String] = [
            "fat","fats","lipid","lipids",
            "fat total","fat, total","total fat",
            "grasas","grasa","grassi","matières grasses","matiere grasse",
            "fett","fette","fette gesamt",
            "vet","vetten",
            "yağ","yağlar",
            "жиры","жир","жиры всего","жири",
            "دهون","دهن",
            "שומן",
            "वसा","चर्बी",
            "ไขมัน",
            "lemak","lemak total",
            "脂肪","總脂肪","總脂","脂質","脂肪総量",
            "지방"
        ]

        // Sugars (add AU/NZ “sugars, total” variants)
        let sugarKeys: [String] = [
            "sugars","sugar","incl. sugars","of which sugars",
            "sugars total","sugars, total","total sugars","total sugar",
            "sucre","sucres","dont sucres",
            "zucker","davon zucker",
            "azúcares","azucar","de los cuales azúcares",
            "zuccheri","di cui zuccheri",
            "açúcares","açúcar",
            "sukker","hvorav sukkerarter","sockerarter",
            "cukry","z toho cukry","z toho cukrů",
            "cukry z toho",
            "zaharuri","din care zaharuri",
            "şekerler","şeker",
            "сахара","в т.ч. сахара","цукри",
            "سكريات","سكر",
            "סוכרים",
            "शर्करा","चीनी",
            "น้ำตาล",
            "đường","đường trong đó",
            "gula",
            "糖","其中糖","糖類","うち糖類",
            "당류","그중 당류"
        ]

        // Fibre
        let fibreKeys: [String] = [
            "fibre","fiber","fibra","faser",
            "fibres alimentaires","fibres",
            "балластные вещества","клетчатка","харчові волокна",
            "ألياف","الياف",
            "סיבים תזונתיים","סיבים",
            "रेशा","फाइबर","আঁশ","ফাইবার",
            "ใยอาหาร",
            "chất xơ",
            "serat",
            "膳食纤维","膳食纖維","食物繊維",
            "식이섬유"
        ]

        // Starch
        let starchKeys: [String] = [
            "starch","almidón","amido","stärke","amidon",
            "féculents","féculent",
            "skrobia","škrob","škroby","škroboviny",
            "نشا","النشا",
            "עמिलन",
            "स्टार्च","মांडा","স্টार্চ",
            "แป้ง",
            "tinh bột",
            "pati","kanji",
            "淀粉","澱粉",
            "でんぷん",
            "전분"
        ]

        // Saturated fat
        let satKeys: [String] = [
            "saturated","sat fat","saturates","of which saturates",
            "acides gras saturés","dont acides gras saturés",
            "gesättigte","davon gesättigte fettsäuren","gesättigte fettsäuren",
            "ácidos grasos saturados","de los cuales saturados",
            "grassi saturi","di cui acidi grassi saturi",
            "ácidos graxos saturados",
            "mættede fedtsyrer","mättat fett","mettede fettsyrer",
            "kwasy tłuszczowe nasycone","z toho nasýtené mastné kyseliny",
            "grăsimi saturate",
            "doymuş yağ asitleri","doymuş yağ",
            "насыщенные жирные кислоты","в т.ч. насыщенные",
            "دهون مشبعة",
            "שומן רווי",
            "संतृप्त वसा","স্যাচুরेटেড ফ্যাট",
            "ไขมันอิ่มตัว",
            "chất béo bão hòa",
            "lemak jenuh",
            "饱和脂肪","飽和脂肪","飽和脂肪酸",
            "포화지방"
        ]

        // Trans fat
        let transKeys: [String] = [
            "trans","trans fat","acides gras trans","grassi trans",
            "ácidos grasos trans","ácidos graxos trans",
            "transfett","trans-fettsäuren",
            "kwasy tłuszczowe trans",
            "grasimi trans",
            "트랜스지방","trans yağ",
            "трансжиры","транс-жиры",
            "دهون متحولة",
            "שומן טרנס",
            "ट्रांस वसा","ট্রান্স ফ্যাট",
            "ไขมันทราน্স",
            "chất béo chuyển hóa",
            "lemak trans",
            "反式脂肪","反式脂肪酸","反式",
            "トランス脂肪酸"
        ]

        // Mono
        let monoKeys: [String] = [
            "monounsaturated","mono",
            "acides gras monoinsaturés","monoinsaturés",
            "einfach ungesättigt","einfach ungesättigte fettsäuren",
            "monoinsaturi","acidi grassi monoinsaturi",
            "ácidos grasos monoinsaturados",
            "ácidos graxos monoinsaturados",
            "mättade enkelomättade","enkelomättat fett",
            "jednonienasycone kwasy tłuszczowe",
            "grăsimi mononesaturate",
            "tekli doymamış yağlar",
            "мононенасыщенные жирные кислоты",
            "دهون أحادية غير مشبعة",
            "שומן חד-בלתי רווי",
            "एकल असंतृप्त वसा",
            "ไขมันไม่อิ่มตัวเชิงเดี่ยว",
            "chất béo đơn नहीं bão hòa",
            "lemak tak jenuh tunggal",
            "单不饱和脂肪","單不飽和脂肪",
            "一価不飽和脂肪酸",
            "단일불포화지방"
        ]

        // Poly
        let polyKeys: [String] = [
            "polyunsaturated","poly",
            "acides gras polyinsaturés","polyinsaturés",
            "mehrfach ungesättigt","mehrfach ungesättigte fettsäuren",
            "polinsaturi","acidi grassi polinsaturi",
            "ácidos grasos poliinsaturados",
            "ácidos graxos poliinsaturados",
            "fleromättat fett",
            "wielonienasycone kwasy tłuszczowe",
            "grăsimi polinesaturate",
            "çoklu doymamış yağlar",
            "полиненасыщенные жирные кислоты",
            "دهون متعددة غير مشبعة",
            "שומן רב-בלתי רווי",
            "बहु असंतृप्त वसा",
            "ไขมันไม่อิ่มตัวเชิงซ้อน",
            "chất béo đa नहीं bão hòa",
            "lemak tak jenuh ganda",
            "多不饱和脂肪","多不飽和脂肪",
            "多価不飽和脂肪酸",
            "다중불포화지방"
        ]

        // Vitamins/minerals keywords
        let vitAKeys = ["vitamin a","vit a","retinol","retinyl","витамин a","retinolo","retinal","维生素a","維生素a","ビタミンa","비타민a","فيتامين a","ויטמין a","विटामिन a","ভিটামিন a"]
        let vitBKeys = ["vitamin b","vit b","b-complex","b complex","b group","b-group","витамин b","complexo b","grupo b","维生素b","維生素b","ビタミンb","비타민b","فيتامين b","ויטמין b","विटामिन b","ভিটामিন b"]
        let vitCKeys = ["vitamin c","vit c","ascorbic","ascorbate","ácido ascórbico","витамин c","维生素c","維生素c","ビタミンc","비타민c","فيتامين c","ויטמין c","विटामिन c","ভিটামিন c"]
        let vitDKeys = ["vitamin d","vit d","cholecalciferol","витамин d","维生素d","維生素d","ビタミンd","비타민d","فيتامين d","ויטמין d","विटामिन d","ভিটामিন d"]
        let vitEKeys = ["vitamin e","vit e","tocopherol","витамин e","维生素e","維生素e","ビタミンe","비타민e","فيتامين e","ויטמין e","विटामिन e","ভিটামিন e"]
        let vitKKeys = ["vitamin k","vit k","phylloquinone","menaquinone","витамин k","维生素k","維生素k","ビタミンk","비타민k","فيتامين k","ויטמין k","विटामिन k","ভিটামিন k"]

        // Individual B vitamins (multilingual synonyms; mg/µg -> mg)
        let vitB1Keys = [
            "vitamin b1","vit b1","b1","b-1","b 1","thiamine","thiamin",
            "tiamina","thiamine","tiamine",
            "维生素b1","維生素b1","硫胺素",
            "ビタミンb1","ティアミン","티아민","비타민 b1",
            "الثيامين","תיאמין",
            "थायमिन","থায়ামিন"
        ]
        let vitB2Keys = [
            "vitamin b2","vit b2","b2","b-2","b 2","riboflavin","riboflavine","riboflavina",
            "维生素b2","維生素b2","核黄素",
            "ビタミンb2","リボフラビン","리보플라빈","비타민 b2",
            "الريبوفلافين","ריבופלאבין"
        ]
        let vitB3Keys = [
            "vitamin b3","vit b3","b3","b-3","b 3","niacin","nicotinamide","niacinamide",
            "ácido nicotínico","acide nicotinique","niacina","niacine",
            "维生素b3","維生素b3","烟酸","菸鹼酸",
            "ビタミンb3","ナイアシン","나이아신","비타민 b3",
            "النياسين","ניאצין"
        ]
        let vitB5Keys = [
            "vitamin b5","vit b5","b5","b-5","b 5","pantothenic acid","pantothenate",
            "acide pantothénique","ácido pantoténico","acido pantotenico","ácido pantotênico","pantotheenzuur",
            "维生素b5","維生素b5","泛酸",
            "ビタミンb5","パントテン酸","판토텐산","비타민 b5",
            "حمض البانتوثينيك","חומצה פנטותנית"
        ]
        let vitB6Keys = [
            "vitamin b6","vit b6","b6","b-6","b 6","pyridoxine","piridoxina","pyridoxina",
            "维生素b6","維生素b6","吡哆醇",
            "ビタミンb6","ピリドキシン","피리독신","비타민 b6",
            "البيرידوكسين","פירידוקסין"
        ]
        let vitB7Keys = [
            "vitamin b7","vit b7","b7","b-7","b 7","biotin","biotine","biotina",
            "维生素b7","維生素b7","生物素",
            "ビタミンb7","ビオチン","비오틴","비타민 b7",
            "البيوتين","ביוטין"
        ]
        let vitB9Keys = [
            "vitamin b9","vit b9","b9","b-9","b 9","folate","folic acid","folates",
            "acide folique","ácido fólico","acido folico","folato","foliumzuur",
            "维生素b9","維生素b9","叶酸","葉酸",
            "ビタミンb9","葉酸","엽산","비타민 b9",
            "حمض الفوليك","חומצה פולית"
        ]
        let vitB12Keys = [
            "vitamin b12","vit b12","b12","b-12","b 12","cobalamin","cyanocobalamin","methylcobalamin","hydroxocobalamin","kobalamin",
            "维生素b12","維生素b12","钴胺素","鈷胺素","氰钴胺",
            "ビタミンb12","コバラミン","シアノコバラミン","메틸코발라민","코발라민","비타민 b12",
            "كوبالامين","سيانوكوبالامين","קובלמין","ציאנוקובלמין"
        ]

        let calciumKeys = ["calcium","ca","кальций","кальций (ca)","钙","鈣","カルシウム","칼슘","كالسيوم","סידן","कैल्शियम","ক্যালসিয়াম"]
        let ironKeys = ["iron","fe","железо","залізо","铁","鐵","鉄","철","حديد","ברזל","लोहा","আয়রন"]
        let potassiumKeys = ["potassium","kalium","k","калий","калій","钾","鉀","カリウム","칼륨","بوتاسيوم","אשלגן","पोटैशियम","पटाशियम","পটাশিয়াম"]
        let zincKeys = ["zinc","zn","цинк","цинк (zn)","锌","鋅","亜鉛","아연","زنك","אבץ","जिंक","দস্তা"]
        let magnesiumKeys = ["magnesium","mg","магний","магній","镁","鎂","マグネシウム","マグネシウム","मगनيسيوم","מגנזיום","मैग्नीशियम","ম্যাগনেসিয়াম"]
        // New: Iodine (mg/µg -> mg)
        let iodineKeys = [
            "iodine","iodide","iode","yodo","iodio","iodo",
            "jodium","jod","jód","iod",
            "iyot","йод","йодид",
            "碘","ヨウ素","요오드",
            "اليود","יוד",
            "आयोडीन","আয়োডিন",
            "ไอโอดีน",
            "i-ốt","iốt","yodium"
        ]
        // New: Phosphorus (mg/µg -> mg)
        let phosphorusKeys = [
            "phosphorus","phosphate","phosphor",
            "phosphore","phosphate",
            "fósforo","fosforo","fósforo","fosfor","fosforu","fosforă",
            "фосфор","фосфат",
            "磷","リン","リン酸","인","인산",
            "فوسفور","فسفات",
            "זרחן",
            "फॉस्फोरस","फॉस्फेट",
            "ফসফরাস",
            "ฟอสฟอรัส",
            "phốt pho","phospho",
            "fosforus"
        ]

        // Sodium and salt
        let sodiumKeys = ["sodium","na","sodio","natrium","ナトリウム","나트륨","钠","鈉","натрий","натрій","صوديوم","נתרן","सोडियम","সোডিয়াম","natrium (na)"]
        let saltKeys = ["salt","sel","salz","sale","sal","salzgehalt","盐","鹽","塩分","소금","соль","сіль","ملح","מלח","नमक","লবণ"]

        // Stimulants/supplements keywords
        let alcoholKeys: [String] = [
            "alcohol","ethanol","alc.","alcool","alcoholic",
            "酒精","酒精含量","含酒精",
            "アルコール",
            "알코올",
            "алкоголь",
            "alcol"
        ]
        let nicotineKeys: [String] = [
            "nicotine","nicotina",
            "尼古丁",
            "ニコチン",
            "니코틴",
            "никотин"
        ]
        let theobromineKeys: [String] = [
            "theobromine","teobromina",
            "可可碱","可可鹼",
            "テオブロミン",
            "테오브로민",
            "теобромин"
        ]
        let caffeineKeys: [String] = [
            "caffeine","cafeine","caféine","cafeína","koffein","coffein",
            "咖啡因",
            "カフェイン",
            "카페인",
            "кофеин"
        ]
        let taurineKeys: [String] = [
            "taurine","taurina",
            "牛磺酸",
            "タウリン",
            "타우린",
            "таурин"
        ]
        let creatineKeys: [String] = [
            "creatine","creatina",
            "肌酸",
            "クレアチン",
            "크레아틴",
            "креатин"
        ]

        // A2 beta-casein (grams) — include common variants; avoid matching plain “casein” alone
        let a2BetaCaseinKeys: [String] = [
            "a2 beta casein","a2 beta-casein","a2 β-casein","a2 β casein",
            "a2 casein","beta casein a2","β-casein a2","beta-casein a2",
            "a2 βcasein","a2 betacasein","a2 β casein"
        ]

        // A1 beta-casein (grams) — include common variants; avoid matching plain “casein” alone
        let a1BetaCaseinKeys: [String] = [
            "a1 beta casein","a1 beta-casein","a1 β-casein","a1 β casein",
            "a1 casein","beta casein a1","β-casein a1","beta-casein a1",
            "a1 βcasein","a1 betacasein","a1 β casein"
        ]

        // Energy label aliases
        let energyKeysKcal = alternation([
            "energy","calorie","calories","kcal",
            "énergie","énergie kcal",
            "energie","energie kcal",
            "energía","calorías","kcal",
            "energia","calorie","chilocalorie","kcal",
            "energia","calorias","quilocalorias","kcal",
            "energia","kalorien","kilokalorien","kcal",
            "energia","kcal","kalorii",
            "energia","kcal","калории","ккал",
            "طاقة","كيلوكالوري","सعرات","سعرات حرارية","كيلو كالोरी","كيلو-कालोरी","kcal",
            "אנרגיה","קक\"ל","קक״ל","kcal",
            "ऊर्जा","किलो कैलोरी","किलो-कैलोरी","kcal",
            "শক্তি","কিলোক্যালোরি","kcal",
            "พลังงาน","กิโলแคลอรี","กกcal","kcal",
            "năng lượng","kcal",
            "tenaga","kalori","kcal",
            "能量","千卡","大卡","kcal",
            "エネルギー","キロカロリー","kcal",
            "에너지","킬로칼로리","kcal"
        ])

        let energyKeysKJ = alternation([
            "energy","kJ","kilojoule","kilojoules",
            "énergie","kJ",
            "energie","kJ",
            "energía","kJ",
            "energia","kJ",
            "energia","kJ",
            "energia","kJ","кДж","килоджоуль","килоджоули",
            "طاقة","كيلوجول","kJ",
            "אנרגיה","ק\"ג'","קג׳","kJ",
            "ऊर्जा","किलो जूल","kJ",
            "শক্তি","কিলোজুল","kJ",
            "พลังงาน","กิโลจูล","kJ",
            "năng lượng","kJ",
            "tenaga","kilojoule","kJ",
            "能量","千焦","kJ",
            "エネルギー","キロジュール","kJ",
            "에너지","킬로줄","kJ"
        ])

        // Unit/keyword presence summary for diagnostics
        let joinedAll = lines.joined(separator: " ")
        let hasG = (firstMatch("(?:\\s|^)(?:\(grams))(?:\\s|$)", in: joinedAll) != nil)
        let hasMG = (firstMatch("(?:\\s|^)(?:\(milligrams))(?:\\s|$)", in: joinedAll) != nil)
        let hasUG = (firstMatch("(?:\\s|^)(?:\(micrograms))(?:\\s|$)", in: joinedAll) != nil)
        let hasKcal = (firstMatch("(?:\\s|^)(?:\(kcalUnits))(?:\\s|$)", in: joinedAll) != nil)
        let hasKJ = (firstMatch("(?:\\s|^)(?:\(kJUnits))(?:\\s|$)", in: joinedAll) != nil)
        diags?.append("Units present: g=\(hasG) mg=\(hasMG) ug=\(hasUG) kcal=\(hasKcal) kj=\(hasKJ)")

        // 1) Pass 1: simple per-line extraction (existing logic)
        // Track per-field misses to explain “keyword seen but value/unit missing”
        var seenTokens: Set<String> = []

        func lineContainsAny(_ line: String, keys: [String]) -> Bool {
            for k in keys {
                if line.contains(k) { return true }
            }
            return false
        }

        // Track individual B vitamins for summing (mg Double)
        var b1Mg: Double? = nil
        var b2Mg: Double? = nil
        var b3Mg: Double? = nil
        var b5Mg: Double? = nil
        var b6Mg: Double? = nil
        var b7Mg: Double? = nil
        var b9Mg: Double? = nil
        var b12Mg: Double? = nil

        for raw in lines {
            let line = raw

            if result.calories == nil {
                if let kcal = parseEnergy(line) {
                    result.calories = kcal
                } else if lineContainsAny(line, keys: ["energy","kcal","kj","kilojoule","calorie","calories"]) {
                    seenTokens.insert("energy")
                }
            }

            if result.carbohydrates == nil {
                if let v = parseGramValue(line, keywords: carbsKeys) {
                    result.carbohydrates = v
                } else if lineContainsAny(line, keys: carbsKeys) {
                    seenTokens.insert("carbohydrates")
                }
            }
            if result.protein == nil {
                if let v = parseGramValue(line, keywords: proteinKeys) {
                    result.protein = v
                } else if lineContainsAny(line, keys: proteinKeys) {
                    seenTokens.insert("protein")
                }
            }
            if result.fat == nil {
                if let v = parseGramValue(line, keywords: fatKeys) {
                    result.fat = v
                } else if lineContainsAny(line, keys: fatKeys) {
                    seenTokens.insert("fat")
                }
            }

            if result.sodiumMg == nil {
                if let mg = parseSodiumOrSalt(line) {
                    result.sodiumMg = mg
                } else if lineContainsAny(line, keys: sodiumKeys + saltKeys) {
                    seenTokens.insert("sodium/salt")
                }
            }

            if result.sugars == nil {
                if let v = parseGramValue(line, keywords: sugarKeys) {
                    result.sugars = v
                } else if lineContainsAny(line, keys: sugarKeys) {
                    seenTokens.insert("sugars")
                }
            }
            if result.fibre == nil {
                if let v = parseGramValue(line, keywords: fibreKeys) {
                    result.fibre = v
                } else if lineContainsAny(line, keys: fibreKeys) {
                    seenTokens.insert("fibre")
                }
            }
            if result.starch == nil {
                if let v = parseGramValue(line, keywords: starchKeys) {
                    result.starch = v
                } else if lineContainsAny(line, keys: starchKeys) {
                    seenTokens.insert("starch")
                }
            }

            if result.saturatedFat == nil {
                if let v = parseGramValue(line, keywords: satKeys) {
                    result.saturatedFat = v
                } else if lineContainsAny(line, keys: satKeys) {
                    seenTokens.insert("saturatedFat")
                }
            }
            if result.transFat == nil {
                if let v = parseGramValue(line, keywords: transKeys) {
                    result.transFat = v
                } else if lineContainsAny(line, keys: transKeys) {
                    seenTokens.insert("transFat")
                }
            }
            if result.monounsaturatedFat == nil {
                if let v = parseGramValue(line, keywords: monoKeys) {
                    result.monounsaturatedFat = v
                } else if lineContainsAny(line, keys: monoKeys) {
                    seenTokens.insert("monounsaturatedFat")
                }
            }
            if result.polyunsaturatedFat == nil {
                if let v = parseGramValue(line, keywords: polyKeys) {
                    result.polyunsaturatedFat = v
                } else if lineContainsAny(line, keys: polyKeys) {
                    seenTokens.insert("polyunsaturatedFat")
                }
            }

            // Vitamins (mg or µg → mg) as Double
            if result.vitaminA == nil {
                if let mg = parseMilligramValueDouble(line, keywords: vitAKeys) {
                    result.vitaminA = mg
                } else if let mgFromMicro = parseMicrogramValueDouble(line, keywords: vitAKeys) {
                    result.vitaminA = mgFromMicro
                } else if lineContainsAny(line, keys: vitAKeys) {
                    seenTokens.insert("vitaminA")
                }
            }
            // Generic Vitamin B fallback (will be overridden if individuals found)
            if result.vitaminB == nil {
                if let mg = parseMilligramValueDouble(line, keywords: vitBKeys) {
                    result.vitaminB = mg
                } else if let mgFromMicro = parseMicrogramValueDouble(line, keywords: vitBKeys) {
                    result.vitaminB = mgFromMicro
                } else if lineContainsAny(line, keys: vitBKeys) {
                    seenTokens.insert("vitaminB")
                }
            }
            if result.vitaminC == nil {
                if let mg = parseMilligramValueDouble(line, keywords: vitCKeys) {
                    result.vitaminC = mg
                } else if let mgFromMicro = parseMicrogramValueDouble(line, keywords: vitCKeys) {
                    result.vitaminC = mgFromMicro
                } else if lineContainsAny(line, keys: vitCKeys) {
                    seenTokens.insert("vitaminC")
                }
            }
            if result.vitaminD == nil {
                if let mg = parseMilligramValueDouble(line, keywords: vitDKeys) {
                    result.vitaminD = mg
                } else if let mgFromMicro = parseMicrogramValueDouble(line, keywords: vitDKeys) {
                    result.vitaminD = mgFromMicro
                } else if lineContainsAny(line, keys: vitDKeys) {
                    seenTokens.insert("vitaminD")
                }
            }
            if result.vitaminE == nil {
                if let mg = parseMilligramValueDouble(line, keywords: vitEKeys) {
                    result.vitaminE = mg
                } else if let mgFromMicro = parseMicrogramValueDouble(line, keywords: vitEKeys) {
                    result.vitaminE = mgFromMicro
                } else if lineContainsAny(line, keys: vitEKeys) {
                    seenTokens.insert("vitaminE")
                }
            }
            if result.vitaminK == nil {
                if let mg = parseMilligramValueDouble(line, keywords: vitKKeys) {
                    result.vitaminK = mg
                } else if let mgFromMicro = parseMicrogramValueDouble(line, keywords: vitKKeys) {
                    result.vitaminK = mgFromMicro
                } else if lineContainsAny(line, keys: vitKKeys) {
                    seenTokens.insert("vitaminK")
                }
            }

            // Individual B vitamins (mg or µg → mg), stored locally for summing
            if b1Mg == nil {
                if let mg = parseMilligramValueDouble(line, keywords: vitB1Keys) {
                    b1Mg = mg
                } else if let mgFromMicro = parseMicrogramValueDouble(line, keywords: vitB1Keys) {
                    b1Mg = mgFromMicro
                } else if lineContainsAny(line, keys: vitB1Keys) {
                    seenTokens.insert("vitaminB1")
                }
            }
            if b2Mg == nil {
                if let mg = parseMilligramValueDouble(line, keywords: vitB2Keys) {
                    b2Mg = mg
                } else if let mgFromMicro = parseMicrogramValueDouble(line, keywords: vitB2Keys) {
                    b2Mg = mgFromMicro
                } else if lineContainsAny(line, keys: vitB2Keys) {
                    seenTokens.insert("vitaminB2")
                }
            }
            if b3Mg == nil {
                if let mg = parseMilligramValueDouble(line, keywords: vitB3Keys) {
                    b3Mg = mg
                } else if let mgFromMicro = parseMicrogramValueDouble(line, keywords: vitB3Keys) {
                    b3Mg = mgFromMicro
                } else if lineContainsAny(line, keys: vitB3Keys) {
                    seenTokens.insert("vitaminB3")
                }
            }
            if b5Mg == nil {
                if let mg = parseMilligramValueDouble(line, keywords: vitB5Keys) {
                    b5Mg = mg
                } else if let mgFromMicro = parseMicrogramValueDouble(line, keywords: vitB5Keys) {
                    b5Mg = mgFromMicro
                } else if lineContainsAny(line, keys: vitB5Keys) {
                    seenTokens.insert("vitaminB5")
                }
            }
            if b6Mg == nil {
                if let mg = parseMilligramValueDouble(line, keywords: vitB6Keys) {
                    b6Mg = mg
                } else if let mgFromMicro = parseMicrogramValueDouble(line, keywords: vitB6Keys) {
                    b6Mg = mgFromMicro
                } else if lineContainsAny(line, keys: vitB6Keys) {
                    seenTokens.insert("vitaminB6")
                }
            }
            if b7Mg == nil {
                if let mg = parseMilligramValueDouble(line, keywords: vitB7Keys) {
                    b7Mg = mg
                } else if let mgFromMicro = parseMicrogramValueDouble(line, keywords: vitB7Keys) {
                    b7Mg = mgFromMicro
                } else if lineContainsAny(line, keys: vitB7Keys) {
                    seenTokens.insert("vitaminB7")
                }
            }
            if b9Mg == nil {
                if let mg = parseMilligramValueDouble(line, keywords: vitB9Keys) {
                    b9Mg = mg
                } else if let mgFromMicro = parseMicrogramValueDouble(line, keywords: vitB9Keys) {
                    b9Mg = mgFromMicro
                } else if lineContainsAny(line, keys: vitB9Keys) {
                    seenTokens.insert("vitaminB9")
                }
            }
            if b12Mg == nil {
                if let mg = parseMilligramValueDouble(line, keywords: vitB12Keys) {
                    b12Mg = mg
                } else if let mgFromMicro = parseMicrogramValueDouble(line, keywords: vitB12Keys) {
                    b12Mg = mgFromMicro
                } else if lineContainsAny(line, keys: vitB12Keys) {
                    seenTokens.insert("vitaminB12")
                }
            }

            // Minerals (mg or µg → mg)
            if result.calcium == nil {
                if let mg = parseMilligramValueInt(line, keywords: calciumKeys) {
                    result.calcium = mg
                } else if let mgFromMicro = parseMicrogramValueInt(line, keywords: calciumKeys) {
                    result.calcium = mgFromMicro
                } else if lineContainsAny(line, keys: calciumKeys) {
                    seenTokens.insert("calcium")
                }
            }
            if result.iron == nil {
                if let mg = parseMilligramValueInt(line, keywords: ironKeys) {
                    result.iron = mg
                } else if let mgFromMicro = parseMicrogramValueInt(line, keywords: ironKeys) {
                    result.iron = mgFromMicro
                } else if lineContainsAny(line, keys: ironKeys) {
                    seenTokens.insert("iron")
                }
            }
            if result.potassium == nil {
                if let mg = parseMilligramValueDouble(line, keywords: potassiumKeys) {
                    result.potassium = mg
                } else if let mgFromMicro = parseMicrogramValueDouble(line, keywords: potassiumKeys) {
                    result.potassium = mgFromMicro
                } else if lineContainsAny(line, keys: potassiumKeys) {
                    seenTokens.insert("potassium")
                }
            }
            if result.zinc == nil {
                if let mg = parseMilligramValueInt(line, keywords: zincKeys) {
                    result.zinc = mg
                } else if let mgFromMicro = parseMicrogramValueInt(line, keywords: zincKeys) {
                    result.zinc = mgFromMicro
                } else if lineContainsAny(line, keys: zincKeys) {
                    seenTokens.insert("zinc")
                }
            }
            if result.magnesium == nil {
                if let mg = parseMilligramValueInt(line, keywords: magnesiumKeys) {
                    result.magnesium = mg
                } else if let mgFromMicro = parseMicrogramValueInt(line, keywords: magnesiumKeys) {
                    result.magnesium = mgFromMicro
                } else if lineContainsAny(line, keys: magnesiumKeys) {
                    seenTokens.insert("magnesium")
                }
            }
            // New: Iodine (mg or µg → mg) as Double
            if result.iodine == nil {
                if let mg = parseMilligramValueDouble(line, keywords: iodineKeys) {
                    result.iodine = mg
                } else if let mgFromMicro = parseMicrogramValueDouble(line, keywords: iodineKeys) {
                    result.iodine = mgFromMicro
                } else if lineContainsAny(line, keys: iodineKeys) {
                    seenTokens.insert("iodine")
                }
            }
            // New: Phosphorus (mg or µg → mg) as Double
            if result.phosphorus == nil {
                if let mg = parseMilligramValueDouble(line, keywords: phosphorusKeys) {
                    result.phosphorus = mg
                } else if let mgFromMicro = parseMicrogramValueDouble(line, keywords: phosphorusKeys) {
                    result.phosphorus = mgFromMicro
                } else if lineContainsAny(line, keys: phosphorusKeys) {
                    seenTokens.insert("phosphorus")
                }
            }

            // Stimulants/supplements (Pass 1)
            if result.alcohol == nil {
                if let g = parseGramValue(line, keywords: alcoholKeys) {
                    result.alcohol = g
                } else if lineContainsAny(line, keys: alcoholKeys) {
                    seenTokens.insert("alcohol")
                }
            }
            if result.nicotineMg == nil {
                if let mg = parseMilligramValueInt(line, keywords: nicotineKeys) {
                    result.nicotineMg = mg
                } else if lineContainsAny(line, keys: nicotineKeys) {
                    seenTokens.insert("nicotine")
                }
            }
            if result.theobromineMg == nil {
                if let mg = parseMilligramValueInt(line, keywords: theobromineKeys) {
                    result.theobromineMg = mg
                } else if lineContainsAny(line, keys: theobromineKeys) {
                    seenTokens.insert("theobromine")
                }
            }
            if result.caffeineMg == nil {
                if let mg = parseMilligramValueInt(line, keywords: caffeineKeys) {
                    result.caffeineMg = mg
                } else if lineContainsAny(line, keys: caffeineKeys) {
                    seenTokens.insert("caffeine")
                }
            }
            if result.taurineMg == nil {
                if let mg = parseMilligramValueInt(line, keywords: taurineKeys) {
                    result.taurineMg = mg
                } else if lineContainsAny(line, keys: taurineKeys) {
                    seenTokens.insert("taurine")
                }
            }
            if result.creatineMg == nil {
                if let mg = parseMilligramValueInt(line, keywords: creatineKeys) {
                    result.creatineMg = mg
                } else if lineContainsAny(line, keys: creatineKeys) {
                    seenTokens.insert("creatine")
                }
            }

            // A2 beta-casein (grams)
            if result.a2BetaCasein == nil {
                if let g = parseGramValue(line, keywords: a2BetaCaseinKeys) {
                    result.a2BetaCasein = g
                } else if lineContainsAny(line, keys: a2BetaCaseinKeys) {
                    seenTokens.insert("a2BetaCasein")
                }
            }

            // A1 beta-casein (grams)
            if result.a1BetaCasein == nil {
                if let g = parseGramValue(line, keywords: a1BetaCaseinKeys) {
                    result.a1BetaCasein = g
                } else if lineContainsAny(line, keys: a1BetaCaseinKeys) {
                    seenTokens.insert("a1BetaCasein")
                }
            }
        }

        // 2) Pass 2: AU/NZ table-aware parsing (e.g., "Protein 2.1 g 3.5 g")
        // Robust header detection for “Avg. Qty per serving / per 100g”
        let headerJoined = lines.joined(separator: " ")

        // Regex fragments for AU headers
        let avgQty = "(?:avg\\.?\\s*qty|average\\s*qty|average\\s*quantity)"
        let per = "\\s*per\\s*"
        let serving = "(?:serving|serve)"
        let hundred = "(?:100\\s*(?:g|gram|ml))"

        func containsRegex(_ pattern: String, in text: String) -> Bool {
            return firstMatch(pattern, in: text) != nil
        }

        // Detect presence of per-serving and per-100g columns, tolerant to spacing/punctuation
        let hasPerServing = containsRegex("(?:" + avgQty + ")?"+per+serving, in: headerJoined)
        let hasPer100g = containsRegex(per + hundred, in: headerJoined) || containsRegex("(?:" + avgQty + ")"+per+hundred, in: headerJoined)

        func maybeApplyGrams(_ name: [String], into field: inout Double?, label: String) {
            guard field == nil else { return }
            var matched = false
            for line in lines {
                if let parsed = parseTwoColumnRow(line: line, nameKeys: name, preferFirst: hasPerServing || !hasPer100g, unitPattern: grams) {
                    field = parsed
                    matched = true
                    break
                }
            }
            if !matched, lines.contains(where: { lineContainsAny($0, keys: name) }) {
                seenTokens.insert(label)
            }
        }

        func maybeApplyMilligramsInt(_ name: [String], into field: inout Int?, label: String) {
            guard field == nil else { return }
            var matched = false
            for line in lines {
                if let parsedD = parseTwoColumnRow(line: line, nameKeys: name, preferFirst: hasPerServing || !hasPer100g, unitPattern: milligrams) {
                    field = Int(round(parsedD))
                    matched = true
                    break
                } else if let parsedG = parseTwoColumnRow(line: line, nameKeys: name, preferFirst: hasPerServing || !hasPer100g, unitPattern: grams) {
                    field = Int(round(parsedG * 1000.0))
                    matched = true
                    break
                }
            }
            if !matched, lines.contains(where: { lineContainsAny($0, keys: name) }) {
                seenTokens.insert(label)
            }
        }

        func maybeApplyMilligramsDouble(_ name: [String], into field: inout Double?, label: String) {
            guard field == nil else { return }
            var matched = false
            for line in lines {
                if let parsedD = parseTwoColumnRow(line: line, nameKeys: name, preferFirst: hasPerServing || !hasPer100g, unitPattern: milligrams) {
                    field = parsedD
                    matched = true
                    break
                } else if let parsedUG = parseTwoColumnRow(line: line, nameKeys: name, preferFirst: hasPerServing || !hasPer100g, unitPattern: micrograms) {
                    field = parsedUG / 1000.0
                    matched = true
                    break
                }
            }
            if !matched, lines.contains(where: { lineContainsAny($0, keys: name) }) {
                seenTokens.insert(label)
            }
        }

        // Parse helper for two-column rows:
        func parseTwoColumnRow(line: String, nameKeys: [String], preferFirst: Bool, unitPattern: String) -> Double? {
            let nameAlt = alternation(nameKeys)
            // Optional AU header noise between values
            let headerNoise = "(?:\\s*(?:avg\\.?\\s*qty|average\\s*qty|average\\s*quantity)?\\s*(?:per)?\\s*(?:serving|serve|100\\s*(?:g|gram|ml))\\s*)*"

            // number + optional unit
            let num = "([0-9]+[\\.,]?[0-9]*)"
            let unitOpt = "(?:\\s*(?:\(unitPattern)))?"

            // Full pattern: name ... first num+unitOpt ... headerNoise ... optional second num+unitOpt
            let pattern = "\(BSTART)(?:\(nameAlt))\(BEND).*?\(num)\(unitOpt)(?:[^0-9]+\(headerNoise))?(?:[^0-9]+\(num)\(unitOpt))?"

            guard let m = firstMatch(pattern, in: line) else { return nil }

            let firstStr = extractNumber(from: line, group: 1, in: m)
            var secondStr: String? = nil
            if m.numberOfRanges > 2, m.range(at: 2).location != NSNotFound {
                secondStr = extractNumber(from: line, group: 2, in: m)
            }

            if preferFirst || secondStr == nil {
                return toDouble(firstStr)
            } else {
                return toDouble(secondStr)
            }
        }

        // Apply table-aware extraction for typical nutrients if not already found
        maybeApplyGrams(carbsKeys, into: &result.carbohydrates, label: "carbohydrates")
        maybeApplyGrams(proteinKeys, into: &result.protein, label: "protein")
        maybeApplyGrams(fatKeys, into: &result.fat, label: "fat")
        maybeApplyGrams(sugarKeys, into: &result.sugars, label: "sugars")
        maybeApplyGrams(fibreKeys, into: &result.fibre, label: "fibre")
        maybeApplyGrams(satKeys, into: &result.saturatedFat, label: "saturatedFat")
        maybeApplyGrams(transKeys, into: &result.transFat, label: "transFat")
        maybeApplyGrams(monoKeys, into: &result.monounsaturatedFat, label: "monounsaturatedFat")
        maybeApplyGrams(polyKeys, into: &result.polyunsaturatedFat, label: "polyunsaturatedFat")
        maybeApplyMilligramsInt(sodiumKeys, into: &result.sodiumMg, label: "sodium/salt")

        // Stimulants/supplements (Pass 2)
        maybeApplyGrams(alcoholKeys, into: &result.alcohol, label: "alcohol")
        maybeApplyMilligramsInt(nicotineKeys, into: &result.nicotineMg, label: "nicotine")
        maybeApplyMilligramsInt(theobromineKeys, into: &result.theobromineMg, label: "theobromine")
        maybeApplyMilligramsInt(caffeineKeys, into: &result.caffeineMg, label: "caffeine")
        maybeApplyMilligramsInt(taurineKeys, into: &result.taurineMg, label: "taurine")
        maybeApplyMilligramsInt(creatineKeys, into: &result.creatineMg, label: "creatine")

        // A2 beta-casein (table-aware)
        maybeApplyGrams(a2BetaCaseinKeys, into: &result.a2BetaCasein, label: "a2BetaCasein")
        // A1 beta-casein (table-aware)
        maybeApplyGrams(a1BetaCaseinKeys, into: &result.a1BetaCasein, label: "a1BetaCasein")

        // New: Iodine (table-aware)
        maybeApplyMilligramsDouble(iodineKeys, into: &result.iodine, label: "iodine")
        // New: Phosphorus (table-aware)
        maybeApplyMilligramsDouble(phosphorusKeys, into: &result.phosphorus, label: "phosphorus")

        // Individual B vitamins (table-aware; prefer per-serving when available)
        maybeApplyMilligramsDouble(vitB1Keys, into: &b1Mg, label: "vitaminB1")
        maybeApplyMilligramsDouble(vitB2Keys, into: &b2Mg, label: "vitaminB2")
        maybeApplyMilligramsDouble(vitB3Keys, into: &b3Mg, label: "vitaminB3")
        maybeApplyMilligramsDouble(vitB5Keys, into: &b5Mg, label: "vitaminB5")
        maybeApplyMilligramsDouble(vitB6Keys, into: &b6Mg, label: "vitaminB6")
        maybeApplyMilligramsDouble(vitB7Keys, into: &b7Mg, label: "vitaminB7")
        maybeApplyMilligramsDouble(vitB9Keys, into: &b9Mg, label: "vitaminB9")
        maybeApplyMilligramsDouble(vitB12Keys, into: &b12Mg, label: "vitaminB12")

        // Energy row often appears as "Energy 1190 kJ 1980 kJ"
        if result.calories == nil {
            var matchedEnergy = false
            for line in lines {
                // Try kJ two-column row (second unit optional)
                let kjNum = "([0-9]+[\\.,]?[0-9]*)"
                let kjOpt = "(?:\\s*(?:\(kJUnits)))?"
                let kjPattern = "\(BSTART)(?:\(energyKeysKJ))\(BEND).*?\(kjNum)\(kjOpt)(?:[^0-9]+\(kjNum)\(kjOpt))?"
                if let m = firstMatch(kjPattern, in: line) {
                    let firstKJ = toInt(extractNumber(from: line, group: 1, in: m)) ?? 0
                    let secondKJ: Int? = {
                        if m.numberOfRanges > 2, m.range(at: 2).location != NSNotFound {
                            return toInt(extractNumber(from: line, group: 2, in: m))
                        }
                        return nil
                    }()
                    let kj = ((hasPerServing || !hasPer100g) ? firstKJ : (secondKJ ?? firstKJ))
                    result.calories = Int(round(Double(kj) / 4.184))
                    matchedEnergy = true
                    break
                }
                // Try kcal two-column row (second unit optional)
                let kcalNum = "([0-9]+[\\.,]?[0-9]*)"
                let kcalOpt = "(?:\\s*(?:\(kcalUnits)))?"
                let kcalPattern = "\(BSTART)(?:\(energyKeysKcal))\(BEND).*?\(kcalNum)\(kcalOpt)(?:[^0-9]+\(kcalNum)\(kcalOpt))?"
                if let m = firstMatch(kcalPattern, in: line) {
                    let first = toInt(extractNumber(from: line, group: 1, in: m)) ?? 0
                    let second: Int? = {
                        if m.numberOfRanges > 2, m.range(at: 2).location != NSNotFound {
                            return toInt(extractNumber(from: line, group: 2, in: m))
                        }
                        return nil
                    }()
                    result.calories = (hasPerServing || !hasPer100g) ? first : (second ?? first)
                    matchedEnergy = true
                    break
                }
            }
            if !matchedEnergy && (hasKcal || hasKJ || seenTokens.contains("energy")) {
                diags?.append("Energy token present but no number+unit match on same line.")
            }
        }

        // MARK: - Decimal point recovery (domain-aware)
        func insertDecimalBeforeLastDigit(_ value: Double) -> Double {
            let iv = Int(round(value))
            if value == Double(iv), iv >= 10, iv <= 99 {
                return Double(iv) / 10.0
            }
            return value
        }

        if let sat = result.saturatedFat, let totalFat = result.fat, sat > totalFat + 0.05 {
            let candidate = insertDecimalBeforeLastDigit(sat)
            if candidate <= totalFat + 0.05 {
                #if DEBUG
                diags?.append("Decimal recovery: saturatedFat \(sat) -> \(candidate) (≤ total fat \(totalFat)).")
                #endif
                result.saturatedFat = candidate
            } else if sat >= 10.0 && candidate < sat {
                if candidate <= (totalFat * 1.2) {
                    #if DEBUG
                    diags?.append("Decimal recovery (tolerant): saturatedFat \(sat) -> \(candidate) (approx 10× issue).")
                    #endif
                    result.saturatedFat = candidate
                }
            }
        }

        if let sug = result.sugars, let carbs = result.carbohydrates, sug > carbs + 0.05 {
            let candidate = insertDecimalBeforeLastDigit(sug)
            if candidate <= carbs + 0.05 {
                #if DEBUG
                diags?.append("Decimal recovery: sugars \(sug) -> \(candidate) (≤ carbohydrates \(carbs)).")
                #endif
                result.sugars = candidate
            }
        }

        // Compute Vitamin B as the sum of individual B vitamins when available
        let bIndividuals = [b1Mg, b2Mg, b3Mg, b5Mg, b6Mg, b7Mg, b9Mg, b12Mg].compactMap { $0 }
        if !bIndividuals.isEmpty {
            let sumB = bIndividuals.reduce(0.0, +)
            #if DEBUG
            let pieces: [String] = [
                b1Mg != nil ? "B1=\(b1Mg!)" : nil,
                b2Mg != nil ? "B2=\(b2Mg!)" : nil,
                b3Mg != nil ? "B3=\(b3Mg!)" : nil,
                b5Mg != nil ? "B5=\(b5Mg!)" : nil,
                b6Mg != nil ? "B6=\(b6Mg!)" : nil,
                b7Mg != nil ? "B7=\(b7Mg!)" : nil,
                b9Mg != nil ? "B9=\(b9Mg!)" : nil,
                b12Mg != nil ? "B12=\(b12Mg!)" : nil
            ].compactMap { $0 }
            if let generic = result.vitaminB {
                diags?.append("Vitamin B: overriding generic \(generic) mg with sum of individuals (\(pieces.joined(separator: ", "))) = \(sumB) mg.")
            } else {
                diags?.append("Vitamin B: sum of individuals (\(pieces.joined(separator: ", "))) = \(sumB) mg.")
            }
            #endif
            result.vitaminB = sumB
        }

        if !seenTokens.isEmpty {
            let sorted = Array(seenTokens).sorted()
            diags?.append("Saw nutrient keywords but could not match value+unit nearby for: \(sorted.joined(separator: ", ")).")
            diags?.append("Common causes: unit missing near number (e.g., '10' without 'g'), OCR split across lines, or label uses unsupported synonym.")
        }

        if !result.hasAnyValue {
            let sample = lines.prefix(5).joined(separator: " | ")
            diags?.append("Sample normalized lines: \(sample)")
        }

        return result
    }
}

// Convenience to check if anything was parsed
extension PhotoNutritionGuesser.GuessResult {
    var hasAnyValue: Bool {
        return calories != nil
        || carbohydrates != nil
        || protein != nil
        || fat != nil
        || sodiumMg != nil
        || sugars != nil
        || starch != nil
        || fibre != nil
        || monounsaturatedFat != nil
        || polyunsaturatedFat != nil
        || saturatedFat != nil
        || transFat != nil
        || animalProtein != nil
        || plantProtein != nil
        || proteinSupplements != nil
        || a2BetaCasein != nil
        || a1BetaCasein != nil
        || vitaminA != nil
        || vitaminB != nil
        || vitaminC != nil
        || vitaminD != nil
        || vitaminE != nil
        || vitaminK != nil
        || calcium != nil
        || iron != nil
        || potassium != nil
        || zinc != nil
        || magnesium != nil
        || iodine != nil
        || phosphorus != nil
        || alcohol != nil
        || nicotineMg != nil
        || theobromineMg != nil
        || caffeineMg != nil
        || taurineMg != nil
        || creatineMg != nil
    }

    var parsedFieldCount: Int {
        var c = 0
        if calories != nil { c += 1 }
        if carbohydrates != nil { c += 1 }
        if protein != nil { c += 1 }
        if fat != nil { c += 1 }
        if sodiumMg != nil { c += 1 }
        if sugars != nil { c += 1 }
        if starch != nil { c += 1 }
        if fibre != nil { c += 1 }
        if monounsaturatedFat != nil { c += 1 }
        if polyunsaturatedFat != nil { c += 1 }
        if saturatedFat != nil { c += 1 }
        if transFat != nil { c += 1 }
        if animalProtein != nil { c += 1 }
        if plantProtein != nil { c += 1 }
        if proteinSupplements != nil { c += 1 }
        if a2BetaCasein != nil { c += 1 }
        if a1BetaCasein != nil { c += 1 }
        if vitaminA != nil { c += 1 }
        if vitaminB != nil { c += 1 }
        if vitaminC != nil { c += 1 }
        if vitaminD != nil { c += 1 }
        if vitaminE != nil { c += 1 }
        if vitaminK != nil { c += 1 }
        if calcium != nil { c += 1 }
        if iron != nil { c += 1 }
        if potassium != nil { c += 1 }
        if zinc != nil { c += 1 }
        if magnesium != nil { c += 1 }
        if iodine != nil { c += 1 }
        if phosphorus != nil { c += 1 }
        if alcohol != nil { c += 1 }
        if nicotineMg != nil { c += 1 }
        if theobromineMg != nil { c += 1 }
        if caffeineMg != nil { c += 1 }
        if taurineMg != nil { c += 1 }
        if creatineMg != nil { c += 1 }
        return c
    }
}

// MARK: - Text Normalization and Localized Units
// (unchanged from previous message except for BSTART/BEND commas already added)

private enum TextNormalizer {
    static func normalize(_ s: String) -> String {
        var t = s.precomposedStringWithCompatibilityMapping
        t = t.replacingOccurrences(of: "：", with: ":")
        t = t.replacingOccurrences(of: "・", with: "·")
        t = t.replacingOccurrences(of: "．", with: ".")
        t = t.replacingOccurrences(of: "，", with: ",")
        t = t.replacingOccurrences(of: "／", with: "/")
        t = t.replacingOccurrences(of: "－", with: "-")
        t = t.replacingOccurrences(of: "–", with: "-")
        t = t.replacingOccurrences(of: "—", with: "-")
        t = t.replacingOccurrences(of: "•", with: "•")
        t = t.replacingOccurrences(of: "·", with: "·")
        t = t.replacingOccurrences(of: "µ", with: "u")
        t = t.replacingOccurrences(of: "μ", with: "u")
        t = t.replacingOccurrences(of: "㎎", with: "mg")
        t = t.replacingOccurrences(of: "㎏", with: "kg")
        t = t.replacingOccurrences(of: "㏄", with: "cc")
        t = t.replacingOccurrences(of: "㎉", with: "kcal")
        t = t.replacingOccurrences(of: "㎈", with: "kcal")
        t = t.replacingOccurrences(of: "㎖", with: "ml")
        t = t.replacingOccurrences(of: "㎍", with: "ug")
        t = t.replacingOccurrences(of: "㎜", with: "mm")
        t = t.replacingOccurrences(of: "０", with: "0")
        t = t.replacingOccurrences(of: "１", with: "1")
        t = t.replacingOccurrences(of: "２", with: "2")
        t = t.replacingOccurrences(of: "３", with: "3")
        t = t.replacingOccurrences(of: "４", with: "4")
        t = t.replacingOccurrences(of: "５", with: "5")
        t = t.replacingOccurrences(of: "６", with: "6")
        t = t.replacingOccurrences(of: "７", with: "7")
        t = t.replacingOccurrences(of: "８", with: "8")
        t = t.replacingOccurrences(of: "９", with: "9")
        t = t.lowercased()
        t = domainFixups(t)
        if t.range(of: #"^[\p{Latin}\p{Greek}\p{Cyrillic}\s\p{Number}\p{Punctuation}]+$"#, options: .regularExpression) != nil {
            t = t.folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: .current)
        }
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return t
    }

    private static func domainFixups(_ s: String) -> String {
        var t = s
        t = t.replacingOccurrences(of: #"(?i)\b([0-9]+[.,]?[0-9]*)\s*(kj)\b"#, with: "$1 $2", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(?i)\b([0-9]+[.,]?[0-9]*)\s*(kcal)\b"#, with: "$1 $2", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(?i)\b([0-9]+[.,]?[0-9]*)\s*(g)\b"#, with: "$1 $2", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(?i)\b([0-9]+[.,]?[0-9]*)\s*(mg|ug|mcg)\b"#, with: "$1 $2", options: .regularExpression)
        t = t.replacingOccurrences(of: #"[•·\.]{2,}"#, with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: #"[,\.;:]{2,}"#, with: ", ", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\b1\.\(\s*([0-9]{3}[a-z]?)"#, with: ", ($1", options: .regularExpression)
        t = t.replacingOccurrences(of: #"([0-9])[ ]*\("#, with: "$1, (", options: .regularExpression)
        t = t.replacingOccurrences(of: "c ilk", with: "milk")
        t = t.replacingOccurrences(of: "staream", with: "cream")
        t = t.replacingOccurrences(of: "mod|ca", with: "modifica")
        t = t.replacingOccurrences(of: "gcurmet", with: "gourmet")
        t = t.replacingOccurrences(of: "tapiobilisers", with: "stabilisers")
        t = t.replacingOccurrences(of: "unified starch", with: "modified starch")
        t = t.replacingOccurrences(of: "tougar", with: "sugar")
        t = t.replacingOccurrences(of: "props", with: "props")
        t = t.replacingOccurrences(of: "vegetable c ilk", with: "vegetable milk")
        t = t.replacingOccurrences(of: #"\)(?=[a-z0-9])"#, with: ") ", options: .regularExpression)
        return t
    }
}

private enum LocalizedUnits {
    static let gramsPattern: String = {
        alternation([
            "g","gram","grams","gramme","grammes","grammi",
            "гр","г","грамм","грамма",
            "克","公克",
            "グラム",
            "그램",
            "กรัม",
            "גרם",
            "ग्राम",
            "গ্রাম",
            "غ","غرام","جرام"
        ])
    }()

    static let milligramsPattern: String = {
        alternation([
            "mg","milligram","milligrams","milligramme","milligrammes","milligrammi",
            "מג","מ\"ג","מיליגרם",
            "мг","миллиграмм","миллиграмма",
            "毫克",
            "ミリグラム",
            "밀리그램",
            "มก\\.","มิลลิกรัม",
            "मि\\.ग्रा","मिलीग्राम",
            "মিগ্রা","মিলিগ্রাম",
            "ملغم","ميليغرام","مليغرام"
        ])
    }()

    static let microgramsPattern: String = {
        alternation([
            "ug","mcg","µg","microgram","micrograms","microgramme","microgrammes","microgrammi",
            "מקג","מק\"ג","מיקרוגרם",
            "мкг","микрограмм","микрограмма",
            "微克",
            "マイクログラム",
            "마이크로그램",
            "ไมโครกรัม",
            "माइक्रोग्राम",
            "মাইক্রোগ্রাম",
            "ميكروغرام"
        ])
    }()

    static let kcalPattern: String = {
        alternation([
            "kcal","ккал","千卡","大卡","キロカロリー","킬로칼로리","กิโลแคลอรี","كيلوكالوري","קक\"ל","קक״ל"
        ])
    }()

    static let kjPattern: String = {
        alternation([
            "kj","кдж","千焦","キロジュール","킬로줄","กิโลจูล","كيلوجول","ק\"ג'","קג׳"
        ])
    }()

    private static func alternation(_ words: [String]) -> String {
        words.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
    }
}
