import SwiftUI
import DaiJishowCore

struct LiquidGlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let content: Content

    init(cornerRadius: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(red: 0.10, green: 0.13, blue: 0.19).opacity(0.88))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.32)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.38), .white.opacity(0.10), .cyan.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            )
            .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 12)
    }
}

// MARK: - Complete 214 Kangxi Radical Catalog, Japanese Readings & Positional Variant Mapper

struct RadicalInfo: Identifiable, Hashable {
    let id: UInt8
    let strokes: Int
    let glyph: String
    let name: String
    let jaNames: [String]
    let aliases: [String]
}

enum RadicalCatalog {
    static let commonIds: Set<UInt8> = [
        9, 30, 32, 38, 40, 42, 46, 61, 64, 72, 74, 75,
        85, 86, 94, 96, 102, 109, 112, 113, 115, 118, 120, 130,
        140, 142, 149, 154, 157, 159, 162, 167, 169, 170, 173, 184
    ]

    static let allRadicals: [RadicalInfo] = [
        // 1 Stroke (1–6)
        RadicalInfo(id: 1, strokes: 1, glyph: "一", name: "One", jaNames: ["いち"], aliases: ["一"]),
        RadicalInfo(id: 2, strokes: 1, glyph: "丨", name: "Line", jaNames: ["たてぼう", "ぼう"], aliases: ["丨"]),
        RadicalInfo(id: 3, strokes: 1, glyph: "丶", name: "Dot", jaNames: ["てん"], aliases: ["丶"]),
        RadicalInfo(id: 4, strokes: 1, glyph: "丿", name: "Slash", jaNames: ["の", "はらいぼう"], aliases: ["丿"]),
        RadicalInfo(id: 5, strokes: 1, glyph: "乙", name: "Second", jaNames: ["おつ", "つりばり"], aliases: ["乙", "乚", "乛"]),
        RadicalInfo(id: 6, strokes: 1, glyph: "亅", name: "Hook", jaNames: ["はねぼう", "かぎ"], aliases: ["亅"]),

        // 2 Strokes (7–29)
        RadicalInfo(id: 7, strokes: 2, glyph: "二", name: "Two", jaNames: ["に"], aliases: ["二"]),
        RadicalInfo(id: 8, strokes: 2, glyph: "亠", name: "Lid", jaNames: ["なべぶた", "けいさんかんむり"], aliases: ["亠"]),
        RadicalInfo(id: 9, strokes: 2, glyph: "亻", name: "Person", jaNames: ["にんべん", "ひと", "ひとがしら"], aliases: ["人", "亻", "𠆢"]),
        RadicalInfo(id: 10, strokes: 2, glyph: "儿", name: "Legs", jaNames: ["ひとあし", "にんにょう"], aliases: ["儿"]),
        RadicalInfo(id: 11, strokes: 2, glyph: "入", name: "Enter", jaNames: ["いる", "いりがしら"], aliases: ["入"]),
        RadicalInfo(id: 12, strokes: 2, glyph: "八", name: "Eight", jaNames: ["はち", "はちがしら"], aliases: ["八", "丷"]),
        RadicalInfo(id: 13, strokes: 2, glyph: "冂", name: "Down box", jaNames: ["まきがまえ", "どうがまえ"], aliases: ["冂"]),
        RadicalInfo(id: 14, strokes: 2, glyph: "冖", name: "Cover", jaNames: ["わかんむり"], aliases: ["冖"]),
        RadicalInfo(id: 15, strokes: 2, glyph: "冫", name: "Ice", jaNames: ["にすい"], aliases: ["冫"]),
        RadicalInfo(id: 16, strokes: 2, glyph: "几", name: "Table", jaNames: ["つくえ", "きにょう"], aliases: ["几"]),
        RadicalInfo(id: 17, strokes: 2, glyph: "凵", name: "Open box", jaNames: ["うけばこ", "かんにょう"], aliases: ["凵"]),
        RadicalInfo(id: 18, strokes: 2, glyph: "刂", name: "Knife", jaNames: ["りっとう", "かたな"], aliases: ["刀", "刂", "⺈"]),
        RadicalInfo(id: 19, strokes: 2, glyph: "力", name: "Power", jaNames: ["ちから"], aliases: ["力"]),
        RadicalInfo(id: 20, strokes: 2, glyph: "勹", name: "Wrap", jaNames: ["つつみがまえ"], aliases: ["勹"]),
        RadicalInfo(id: 21, strokes: 2, glyph: "匕", name: "Spoon", jaNames: ["さじ", "ひ"], aliases: ["匕"]),
        RadicalInfo(id: 22, strokes: 2, glyph: "匚", name: "Right box", jaNames: ["はこがまえ"], aliases: ["匚"]),
        RadicalInfo(id: 23, strokes: 2, glyph: "匸", name: "Hiding box", jaNames: ["かくしがまえ"], aliases: ["匸"]),
        RadicalInfo(id: 24, strokes: 2, glyph: "十", name: "Ten", jaNames: ["じゅう"], aliases: ["十"]),
        RadicalInfo(id: 25, strokes: 2, glyph: "卜", name: "Divination", jaNames: ["ぼく", "うらない"], aliases: ["卜"]),
        RadicalInfo(id: 26, strokes: 2, glyph: "卩", name: "Seal", jaNames: ["ふしづくり"], aliases: ["卩", "㔾"]),
        RadicalInfo(id: 27, strokes: 2, glyph: "厂", name: "Cliff", jaNames: ["がんだれ"], aliases: ["厂"]),
        RadicalInfo(id: 28, strokes: 2, glyph: "厶", name: "Private", jaNames: ["む"], aliases: ["厶"]),
        RadicalInfo(id: 29, strokes: 2, glyph: "又", name: "Again", jaNames: ["また"], aliases: ["又"]),

        // 3 Strokes (30–60)
        RadicalInfo(id: 30, strokes: 3, glyph: "口", name: "Mouth", jaNames: ["くち", "くちへん"], aliases: ["口"]),
        RadicalInfo(id: 31, strokes: 3, glyph: "囗", name: "Enclosure", jaNames: ["くにがまえ"], aliases: ["囗"]),
        RadicalInfo(id: 32, strokes: 3, glyph: "土", name: "Earth", jaNames: ["つち", "つちへん"], aliases: ["土"]),
        RadicalInfo(id: 33, strokes: 3, glyph: "士", name: "Scholar", jaNames: ["さむらい"], aliases: ["士"]),
        RadicalInfo(id: 34, strokes: 3, glyph: "夂", name: "Go", jaNames: ["ふゆがしら"], aliases: ["夂"]),
        RadicalInfo(id: 35, strokes: 3, glyph: "夊", name: "Go slowly", jaNames: ["すいにょう"], aliases: ["夊"]),
        RadicalInfo(id: 36, strokes: 3, glyph: "夕", name: "Evening", jaNames: ["ゆうべ", "た"], aliases: ["夕"]),
        RadicalInfo(id: 37, strokes: 3, glyph: "大", name: "Big", jaNames: ["だい"], aliases: ["大"]),
        RadicalInfo(id: 38, strokes: 3, glyph: "女", name: "Woman", jaNames: ["おんな", "おんなへん"], aliases: ["女"]),
        RadicalInfo(id: 39, strokes: 3, glyph: "子", name: "Child", jaNames: ["こ", "こへん"], aliases: ["子"]),
        RadicalInfo(id: 40, strokes: 3, glyph: "宀", name: "Roof", jaNames: ["うかんむり"], aliases: ["宀"]),
        RadicalInfo(id: 41, strokes: 3, glyph: "寸", name: "Inch", jaNames: ["すん"], aliases: ["寸"]),
        RadicalInfo(id: 42, strokes: 3, glyph: "小", name: "Small", jaNames: ["しょう", "ちいさい"], aliases: ["小", "⺌", "⺍"]),
        RadicalInfo(id: 43, strokes: 3, glyph: "尢", name: "Lame", jaNames: ["まげあし", "だいのまげあし"], aliases: ["尢", "尤"]),
        RadicalInfo(id: 44, strokes: 3, glyph: "尸", name: "Corpse", jaNames: ["しかばね", "しかばねだれ"], aliases: ["尸"]),
        RadicalInfo(id: 45, strokes: 3, glyph: "屮", name: "Sprout", jaNames: ["てつ", "めばえ"], aliases: ["屮"]),
        RadicalInfo(id: 46, strokes: 3, glyph: "山", name: "Mountain", jaNames: ["やま", "やまへん"], aliases: ["山"]),
        RadicalInfo(id: 47, strokes: 3, glyph: "巛", name: "River", jaNames: ["かわ", "まがりかわ"], aliases: ["巛", "川"]),
        RadicalInfo(id: 48, strokes: 3, glyph: "工", name: "Work", jaNames: ["たくみ", "こう"], aliases: ["工"]),
        RadicalInfo(id: 49, strokes: 3, glyph: "己", name: "Oneself", jaNames: ["おのれ"], aliases: ["己", "已", "巳"]),
        RadicalInfo(id: 50, strokes: 3, glyph: "巾", name: "Turban", jaNames: ["はば", "はばへん"], aliases: ["巾"]),
        RadicalInfo(id: 51, strokes: 3, glyph: "干", name: "Dry", jaNames: ["かん", "ほす"], aliases: ["干"]),
        RadicalInfo(id: 52, strokes: 3, glyph: "幺", name: "Short thread", jaNames: ["いとがしら"], aliases: ["幺"]),
        RadicalInfo(id: 53, strokes: 3, glyph: "广", name: "Dotted cliff", jaNames: ["まだれ"], aliases: ["广"]),
        RadicalInfo(id: 54, strokes: 3, glyph: "廴", name: "Long stride", jaNames: ["えんにょう"], aliases: ["廴"]),
        RadicalInfo(id: 55, strokes: 3, glyph: "廾", name: "Two hands", jaNames: ["にじゅうあし"], aliases: ["廾"]),
        RadicalInfo(id: 56, strokes: 3, glyph: "弋", name: "Shoot", jaNames: ["しきがまえ"], aliases: ["弋"]),
        RadicalInfo(id: 57, strokes: 3, glyph: "弓", name: "Bow", jaNames: ["ゆみ", "ゆみへん"], aliases: ["弓"]),
        RadicalInfo(id: 58, strokes: 3, glyph: "彐", name: "Snout", jaNames: ["けいがしら"], aliases: ["彐", "彑"]),
        RadicalInfo(id: 59, strokes: 3, glyph: "彡", name: "Bristle", jaNames: ["さんづくり"], aliases: ["彡"]),
        RadicalInfo(id: 60, strokes: 3, glyph: "彳", name: "Step", jaNames: ["ぎょうにんべん"], aliases: ["彳"]),

        // 4 Strokes (61–94)
        RadicalInfo(id: 61, strokes: 4, glyph: "忄", name: "Heart", jaNames: ["りっしんべん", "こころ", "したごころ"], aliases: ["心", "忄", "⺗"]),
        RadicalInfo(id: 62, strokes: 4, glyph: "戈", name: "Halberd", jaNames: ["ほこ", "ほこづくり"], aliases: ["戈"]),
        RadicalInfo(id: 63, strokes: 4, glyph: "戸", name: "Door", jaNames: ["と", "とだれ"], aliases: ["戶", "戸"]),
        RadicalInfo(id: 64, strokes: 4, glyph: "扌", name: "Hand", jaNames: ["てへん", "て"], aliases: ["手", "扌"]),
        RadicalInfo(id: 65, strokes: 4, glyph: "支", name: "Branch", jaNames: ["しにょう", "えだ"], aliases: ["支"]),
        RadicalInfo(id: 66, strokes: 4, glyph: "攵", name: "Rap", jaNames: ["のぶん", "ぼくづくり"], aliases: ["攴", "攵"]),
        RadicalInfo(id: 67, strokes: 4, glyph: "文", name: "Script", jaNames: ["ぶん"], aliases: ["文"]),
        RadicalInfo(id: 68, strokes: 4, glyph: "斗", name: "Dipper", jaNames: ["とます"], aliases: ["斗"]),
        RadicalInfo(id: 69, strokes: 4, glyph: "斤", name: "Axe", jaNames: ["おのづくり", "きん"], aliases: ["斤"]),
        RadicalInfo(id: 70, strokes: 4, glyph: "方", name: "Square", jaNames: ["ほう", "ほうへん"], aliases: ["方"]),
        RadicalInfo(id: 71, strokes: 4, glyph: "无", name: "Not", jaNames: ["むにょう"], aliases: ["无", "旡"]),
        RadicalInfo(id: 72, strokes: 4, glyph: "日", name: "Sun", jaNames: ["ひ", "にち", "ひへん"], aliases: ["日"]),
        RadicalInfo(id: 73, strokes: 4, glyph: "曰", name: "Say", jaNames: ["ひらび", "いわく"], aliases: ["曰"]),
        RadicalInfo(id: 74, strokes: 4, glyph: "月", name: "Moon", jaNames: ["つき", "つきへん"], aliases: ["月"]),
        RadicalInfo(id: 75, strokes: 4, glyph: "木", name: "Tree", jaNames: ["き", "きへん"], aliases: ["木"]),
        RadicalInfo(id: 76, strokes: 4, glyph: "欠", name: "Lack", jaNames: ["あくび", "けんづくり"], aliases: ["欠"]),
        RadicalInfo(id: 77, strokes: 4, glyph: "止", name: "Stop", jaNames: ["とめる", "とめへん"], aliases: ["止"]),
        RadicalInfo(id: 78, strokes: 4, glyph: "歹", name: "Death", jaNames: ["がつへん", "いちたへん"], aliases: ["歹", "歺"]),
        RadicalInfo(id: 79, strokes: 4, glyph: "殳", name: "Weapon", jaNames: ["るまた", "ほこづくり"], aliases: ["殳"]),
        RadicalInfo(id: 80, strokes: 4, glyph: "毋", name: "Do not", jaNames: ["なかれ", "はは"], aliases: ["毋", "母"]),
        RadicalInfo(id: 81, strokes: 4, glyph: "比", name: "Compare", jaNames: ["くらべる"], aliases: ["比"]),
        RadicalInfo(id: 82, strokes: 4, glyph: "毛", name: "Fur", jaNames: ["け"], aliases: ["毛"]),
        RadicalInfo(id: 83, strokes: 4, glyph: "氏", name: "Clan", jaNames: ["うじ"], aliases: ["氏"]),
        RadicalInfo(id: 84, strokes: 4, glyph: "气", name: "Steam", jaNames: ["きがまえ"], aliases: ["气"]),
        RadicalInfo(id: 85, strokes: 4, glyph: "氵", name: "Water", jaNames: ["さんずい", "みず", "したみず"], aliases: ["水", "氵", "氺"]),
        RadicalInfo(id: 86, strokes: 4, glyph: "灬", name: "Fire", jaNames: ["れっか", "れんが", "ひ", "ひへん"], aliases: ["火", "灬"]),
        RadicalInfo(id: 87, strokes: 4, glyph: "爪", name: "Claw", jaNames: ["つめ", "つめかんむり"], aliases: ["爪", "爫"]),
        RadicalInfo(id: 88, strokes: 4, glyph: "父", name: "Father", jaNames: ["ちち"], aliases: ["父"]),
        RadicalInfo(id: 89, strokes: 4, glyph: "爻", name: "Double X", jaNames: ["こう"], aliases: ["爻"]),
        RadicalInfo(id: 90, strokes: 4, glyph: "爿", name: "Half trunk", jaNames: ["しょうへん"], aliases: ["爿", "丬"]),
        RadicalInfo(id: 91, strokes: 4, glyph: "片", name: "Slice", jaNames: ["かた", "かたへん"], aliases: ["片"]),
        RadicalInfo(id: 92, strokes: 4, glyph: "牙", name: "Fang", jaNames: ["きば"], aliases: ["牙"]),
        RadicalInfo(id: 93, strokes: 4, glyph: "牛", name: "Cow", jaNames: ["うし", "うしへん"], aliases: ["牛", "牜"]),
        RadicalInfo(id: 94, strokes: 4, glyph: "犭", name: "Dog", jaNames: ["けものへん", "いぬ"], aliases: ["犬", "犭"]),

        // 5 Strokes (95–117)
        RadicalInfo(id: 95, strokes: 5, glyph: "玄", name: "Profound", jaNames: ["げん"], aliases: ["玄"]),
        RadicalInfo(id: 96, strokes: 5, glyph: "王", name: "Jade", jaNames: ["たま", "おうへん", "たまへん"], aliases: ["玉", "王"]),
        RadicalInfo(id: 97, strokes: 5, glyph: "瓜", name: "Melon", jaNames: ["うり"], aliases: ["瓜"]),
        RadicalInfo(id: 98, strokes: 5, glyph: "瓦", name: "Tile", jaNames: ["かわら"], aliases: ["瓦"]),
        RadicalInfo(id: 99, strokes: 5, glyph: "甘", name: "Sweet", jaNames: ["あまい"], aliases: ["甘"]),
        RadicalInfo(id: 100, strokes: 5, glyph: "生", name: "Life", jaNames: ["うまれる", "いきる"], aliases: ["生"]),
        RadicalInfo(id: 101, strokes: 5, glyph: "用", name: "Use", jaNames: ["もちいる"], aliases: ["用"]),
        RadicalInfo(id: 102, strokes: 5, glyph: "田", name: "Field", jaNames: ["た", "たへん"], aliases: ["田"]),
        RadicalInfo(id: 103, strokes: 5, glyph: "疋", name: "Cloth", jaNames: ["ひき", "ひきへん"], aliases: ["疋", "匹"]),
        RadicalInfo(id: 104, strokes: 5, glyph: "疒", name: "Sickness", jaNames: ["やまいだれ"], aliases: ["疒"]),
        RadicalInfo(id: 105, strokes: 5, glyph: "癶", name: "Footsteps", jaNames: ["はつがしら"], aliases: ["癶"]),
        RadicalInfo(id: 106, strokes: 5, glyph: "白", name: "White", jaNames: ["しろ", "しろへん"], aliases: ["白"]),
        RadicalInfo(id: 107, strokes: 5, glyph: "皮", name: "Skin", jaNames: ["けがわ", "ひのかわ"], aliases: ["皮"]),
        RadicalInfo(id: 108, strokes: 5, glyph: "皿", name: "Dish", jaNames: ["さら"], aliases: ["皿"]),
        RadicalInfo(id: 109, strokes: 5, glyph: "目", name: "Eye", jaNames: ["め", "めへん"], aliases: ["目"]),
        RadicalInfo(id: 110, strokes: 5, glyph: "矛", name: "Spear", jaNames: ["ほこ", "ほこへん"], aliases: ["矛"]),
        RadicalInfo(id: 111, strokes: 5, glyph: "矢", name: "Arrow", jaNames: ["や", "やへん"], aliases: ["矢"]),
        RadicalInfo(id: 112, strokes: 5, glyph: "石", name: "Stone", jaNames: ["いし", "いしへん"], aliases: ["石"]),
        RadicalInfo(id: 113, strokes: 5, glyph: "礻", name: "Spirit", jaNames: ["しめすへん", "しめす"], aliases: ["示", "礻"]),
        RadicalInfo(id: 114, strokes: 5, glyph: "禸", name: "Track", jaNames: ["ぐうのあし"], aliases: ["禸"]),
        RadicalInfo(id: 115, strokes: 5, glyph: "禾", name: "Grain", jaNames: ["のぎへん", "いね"], aliases: ["禾"]),
        RadicalInfo(id: 116, strokes: 5, glyph: "穴", name: "Cave", jaNames: ["あな", "あなかんむり"], aliases: ["穴"]),
        RadicalInfo(id: 117, strokes: 5, glyph: "立", name: "Stand", jaNames: ["たつ", "たつへん"], aliases: ["立"]),

        // 6 Strokes (118–146)
        RadicalInfo(id: 118, strokes: 6, glyph: "⺮", name: "Bamboo", jaNames: ["たけかんむり", "たけ"], aliases: ["竹", "⺮"]),
        RadicalInfo(id: 119, strokes: 6, glyph: "米", name: "Rice", jaNames: ["こめ", "こめへん"], aliases: ["米"]),
        RadicalInfo(id: 120, strokes: 6, glyph: "糸", name: "Silk", jaNames: ["いと", "いとへん"], aliases: ["糸", "糹"]),
        RadicalInfo(id: 121, strokes: 6, glyph: "缶", name: "Jar", jaNames: ["ほとぎ", "かん"], aliases: ["缶"]),
        RadicalInfo(id: 122, strokes: 6, glyph: "罒", name: "Net", jaNames: ["あみがしら", "よこめ"], aliases: ["网", "罒", "⺲", "罓"]),
        RadicalInfo(id: 123, strokes: 6, glyph: "羊", name: "Sheep", jaNames: ["ひつじ", "ひつじへん"], aliases: ["羊", "⺶"]),
        RadicalInfo(id: 124, strokes: 6, glyph: "羽", name: "Feather", jaNames: ["はね"], aliases: ["羽"]),
        RadicalInfo(id: 125, strokes: 6, glyph: "耂", name: "Old", jaNames: ["おいかんむり", "おい"], aliases: ["老", "耂"]),
        RadicalInfo(id: 126, strokes: 6, glyph: "而", name: "And", jaNames: ["しかして"], aliases: ["而"]),
        RadicalInfo(id: 127, strokes: 6, glyph: "耒", name: "Plow", jaNames: ["らいすき", "すきへん"], aliases: ["耒"]),
        RadicalInfo(id: 128, strokes: 6, glyph: "耳", name: "Ear", jaNames: ["みみ", "みみへん"], aliases: ["耳"]),
        RadicalInfo(id: 129, strokes: 6, glyph: "聿", name: "Brush", jaNames: ["ふでづくり"], aliases: ["聿", "⺻"]),
        RadicalInfo(id: 130, strokes: 6, glyph: "⺼", name: "Meat", jaNames: ["にくづき", "にく"], aliases: ["肉", "⺼"]),
        RadicalInfo(id: 131, strokes: 6, glyph: "臣", name: "Minister", jaNames: ["しん"], aliases: ["臣"]),
        RadicalInfo(id: 132, strokes: 6, glyph: "自", name: "Self", jaNames: ["みずから"], aliases: ["自"]),
        RadicalInfo(id: 133, strokes: 6, glyph: "至", name: "Arrive", jaNames: ["いたる"], aliases: ["至"]),
        RadicalInfo(id: 134, strokes: 6, glyph: "臼", name: "Mortar", jaNames: ["うす"], aliases: ["臼"]),
        RadicalInfo(id: 135, strokes: 6, glyph: "舌", name: "Tongue", jaNames: ["した", "したへん"], aliases: ["舌"]),
        RadicalInfo(id: 136, strokes: 6, glyph: "舛", name: "Oppose", jaNames: ["まいあし"], aliases: ["舛"]),
        RadicalInfo(id: 137, strokes: 6, glyph: "舟", name: "Boat", jaNames: ["ふね", "ふねへん"], aliases: ["舟"]),
        RadicalInfo(id: 138, strokes: 6, glyph: "艮", name: "Stopping", jaNames: ["こん", "ねづくり"], aliases: ["艮"]),
        RadicalInfo(id: 139, strokes: 6, glyph: "色", name: "Color", jaNames: ["いろ"], aliases: ["色"]),
        RadicalInfo(id: 140, strokes: 6, glyph: "艹", name: "Grass", jaNames: ["くさかんむり", "くさ"], aliases: ["艸", "艹"]),
        RadicalInfo(id: 141, strokes: 6, glyph: "虍", name: "Tiger", jaNames: ["とらかんむり", "とらがしら"], aliases: ["虍"]),
        RadicalInfo(id: 142, strokes: 6, glyph: "虫", name: "Insect", jaNames: ["むし", "むしへん"], aliases: ["虫"]),
        RadicalInfo(id: 143, strokes: 6, glyph: "血", name: "Blood", jaNames: ["ち"], aliases: ["血"]),
        RadicalInfo(id: 144, strokes: 6, glyph: "行", name: "Walk", jaNames: ["ぎょうがまえ", "ゆき"], aliases: ["行"]),
        RadicalInfo(id: 145, strokes: 6, glyph: "衤", name: "Clothes", jaNames: ["ころもへん", "ころも"], aliases: ["衣", "衤"]),
        RadicalInfo(id: 146, strokes: 6, glyph: "西", name: "West", jaNames: ["にし", "かなめのかしら"], aliases: ["襾", "西", "覀"]),

        // 7 Strokes (147–166)
        RadicalInfo(id: 147, strokes: 7, glyph: "見", name: "See", jaNames: ["みる"], aliases: ["見"]),
        RadicalInfo(id: 148, strokes: 7, glyph: "角", name: "Horn", jaNames: ["つの", "つのへん"], aliases: ["角"]),
        RadicalInfo(id: 149, strokes: 7, glyph: "言", name: "Speech", jaNames: ["ごんべん", "ことば"], aliases: ["言"]),
        RadicalInfo(id: 150, strokes: 7, glyph: "谷", name: "Valley", jaNames: ["たに", "たにへん"], aliases: ["谷"]),
        RadicalInfo(id: 151, strokes: 7, glyph: "豆", name: "Bean", jaNames: ["まめ", "まめへん"], aliases: ["豆"]),
        RadicalInfo(id: 152, strokes: 7, glyph: "豕", name: "Pig", jaNames: ["いのこ"], aliases: ["豕"]),
        RadicalInfo(id: 153, strokes: 7, glyph: "豸", name: "Badger", jaNames: ["むじなへん"], aliases: ["豸"]),
        RadicalInfo(id: 154, strokes: 7, glyph: "貝", name: "Shell", jaNames: ["かい", "かいへん"], aliases: ["貝"]),
        RadicalInfo(id: 155, strokes: 7, glyph: "赤", name: "Red", jaNames: ["あか"], aliases: ["赤"]),
        RadicalInfo(id: 156, strokes: 7, glyph: "走", name: "Run", jaNames: ["そうにょう", "はしる"], aliases: ["走"]),
        RadicalInfo(id: 157, strokes: 7, glyph: "⻊", name: "Foot", jaNames: ["あしへん", "あし"], aliases: ["足", "⻊"]),
        RadicalInfo(id: 158, strokes: 7, glyph: "身", name: "Body", jaNames: ["み", "みへん"], aliases: ["身"]),
        RadicalInfo(id: 159, strokes: 7, glyph: "車", name: "Cart", jaNames: ["くるま", "くるまへん"], aliases: ["車"]),
        RadicalInfo(id: 160, strokes: 7, glyph: "辛", name: "Bitter", jaNames: ["からい"], aliases: ["辛"]),
        RadicalInfo(id: 161, strokes: 7, glyph: "辰", name: "Morning", jaNames: ["しんのたつ"], aliases: ["辰"]),
        RadicalInfo(id: 162, strokes: 7, glyph: "⻌", name: "Walk", jaNames: ["しんにょう", "しんにゅう"], aliases: ["辵", "⻌", "辶"]),
        RadicalInfo(id: 163, strokes: 7, glyph: "⻏", name: "City", jaNames: ["おおざと"], aliases: ["邑", "⻏"]),
        RadicalInfo(id: 164, strokes: 7, glyph: "酉", name: "Wine", jaNames: ["とりへん", "ひよみのとり"], aliases: ["酉"]),
        RadicalInfo(id: 165, strokes: 7, glyph: "釆", name: "Distinguish", jaNames: ["のごめ"], aliases: ["釆"]),
        RadicalInfo(id: 166, strokes: 7, glyph: "里", name: "Village", jaNames: ["さと", "さとへん"], aliases: ["里"]),

        // 8 Strokes (167–175)
        RadicalInfo(id: 167, strokes: 8, glyph: "金", name: "Gold", jaNames: ["かね", "かねへん"], aliases: ["金"]),
        RadicalInfo(id: 168, strokes: 8, glyph: "長", name: "Long", jaNames: ["ながい"], aliases: ["長", "镸"]),
        RadicalInfo(id: 169, strokes: 8, glyph: "門", name: "Gate", jaNames: ["もんがまえ", "かどがまえ"], aliases: ["門"]),
        RadicalInfo(id: 170, strokes: 8, glyph: "阝", name: "Mound", jaNames: ["こざとへん"], aliases: ["阜", "阝", "⻖"]),
        RadicalInfo(id: 171, strokes: 8, glyph: "隶", name: "Slave", jaNames: ["れいづくり"], aliases: ["隶"]),
        RadicalInfo(id: 172, strokes: 8, glyph: "隹", name: "Short bird", jaNames: ["ふるとり"], aliases: ["隹"]),
        RadicalInfo(id: 173, strokes: 8, glyph: "雨", name: "Rain", jaNames: ["あめ", "あめかんむり"], aliases: ["雨"]),
        RadicalInfo(id: 174, strokes: 8, glyph: "青", name: "Blue", jaNames: ["あお"], aliases: ["靑", "青"]),
        RadicalInfo(id: 175, strokes: 8, glyph: "非", name: "Wrong", jaNames: ["あらず"], aliases: ["非"]),

        // 9 Strokes (176–186)
        RadicalInfo(id: 176, strokes: 9, glyph: "面", name: "Face", jaNames: ["めん"], aliases: ["面"]),
        RadicalInfo(id: 177, strokes: 9, glyph: "革", name: "Leather", jaNames: ["かわへん", "つくりがわ"], aliases: ["革"]),
        RadicalInfo(id: 178, strokes: 9, glyph: "韋", name: "Tanned leather", jaNames: ["なめしがわ"], aliases: ["韋"]),
        RadicalInfo(id: 179, strokes: 9, glyph: "韭", name: "Leek", jaNames: ["にら"], aliases: ["韭"]),
        RadicalInfo(id: 180, strokes: 9, glyph: "音", name: "Sound", jaNames: ["おと", "おとへん"], aliases: ["音"]),
        RadicalInfo(id: 181, strokes: 9, glyph: "頁", name: "Leaf", jaNames: ["おおがい"], aliases: ["頁"]),
        RadicalInfo(id: 182, strokes: 9, glyph: "風", name: "Wind", jaNames: ["かぜ"], aliases: ["風"]),
        RadicalInfo(id: 183, strokes: 9, glyph: "飛", name: "Fly", jaNames: ["とぶ"], aliases: ["飛"]),
        RadicalInfo(id: 184, strokes: 9, glyph: "食", name: "Eat", jaNames: ["しょく", "しょくへん"], aliases: ["食", "飠"]),
        RadicalInfo(id: 185, strokes: 9, glyph: "首", name: "Head", jaNames: ["くび"], aliases: ["首"]),
        RadicalInfo(id: 186, strokes: 9, glyph: "香", name: "Fragrant", jaNames: ["かおり"], aliases: ["香"]),

        // 10 Strokes (187–194)
        RadicalInfo(id: 187, strokes: 10, glyph: "馬", name: "Horse", jaNames: ["うま", "うまへん"], aliases: ["馬"]),
        RadicalInfo(id: 188, strokes: 10, glyph: "骨", name: "Bone", jaNames: ["ほね", "ほねへん"], aliases: ["骨"]),
        RadicalInfo(id: 189, strokes: 10, glyph: "高", name: "Tall", jaNames: ["たかい"], aliases: ["高"]),
        RadicalInfo(id: 190, strokes: 10, glyph: "髟", name: "Hair", jaNames: ["かみがしら"], aliases: ["髟"]),
        RadicalInfo(id: 191, strokes: 10, glyph: "鬥", name: "Fight", jaNames: ["とうがまえ"], aliases: ["鬥"]),
        RadicalInfo(id: 192, strokes: 10, glyph: "鬯", name: "Sacrificial wine", jaNames: ["ちょう"], aliases: ["鬯"]),
        RadicalInfo(id: 193, strokes: 10, glyph: "鬲", name: "Cauldron", jaNames: ["れき"], aliases: ["鬲"]),
        RadicalInfo(id: 194, strokes: 10, glyph: "鬼", name: "Ghost", jaNames: ["おに", "きにょう"], aliases: ["鬼"]),

        // 11 Strokes (195–200)
        RadicalInfo(id: 195, strokes: 11, glyph: "魚", name: "Fish", jaNames: ["うお", "うおへん", "さかな"], aliases: ["魚"]),
        RadicalInfo(id: 196, strokes: 11, glyph: "鳥", name: "Bird", jaNames: ["とり", "とりへん"], aliases: ["鳥"]),
        RadicalInfo(id: 197, strokes: 11, glyph: "鹵", name: "Salt", jaNames: ["ろ", "しお"], aliases: ["鹵"]),
        RadicalInfo(id: 198, strokes: 11, glyph: "鹿", name: "Deer", jaNames: ["しか"], aliases: ["鹿"]),
        RadicalInfo(id: 199, strokes: 11, glyph: "麦", name: "Wheat", jaNames: ["むぎ"], aliases: ["麥", "麦"]),
        RadicalInfo(id: 200, strokes: 11, glyph: "麻", name: "Hemp", jaNames: ["あさ", "あさかんむり"], aliases: ["麻"]),

        // 12 Strokes (201–204)
        RadicalInfo(id: 201, strokes: 12, glyph: "黄", name: "Yellow", jaNames: ["きいろ"], aliases: ["黃", "黄"]),
        RadicalInfo(id: 202, strokes: 12, glyph: "黍", name: "Millet", jaNames: ["きび"], aliases: ["黍"]),
        RadicalInfo(id: 203, strokes: 12, glyph: "黒", name: "Black", jaNames: ["くろ"], aliases: ["黒", "黑"]),
        RadicalInfo(id: 204, strokes: 12, glyph: "黹", name: "Embroidery", jaNames: ["ふつ"], aliases: ["黹"]),

        // 13 Strokes (205–208)
        RadicalInfo(id: 205, strokes: 13, glyph: "黽", name: "Frog", jaNames: ["べん", "かえる"], aliases: ["黽"]),
        RadicalInfo(id: 206, strokes: 13, glyph: "鼎", name: "Tripod", jaNames: ["かなえ"], aliases: ["鼎"]),
        RadicalInfo(id: 207, strokes: 13, glyph: "鼓", name: "Drum", jaNames: ["つづみ"], aliases: ["鼓"]),
        RadicalInfo(id: 208, strokes: 13, glyph: "鼠", name: "Rat", jaNames: ["ねずみ"], aliases: ["鼠"]),

        // 14 Strokes (209–210)
        RadicalInfo(id: 209, strokes: 14, glyph: "鼻", name: "Nose", jaNames: ["はな"], aliases: ["鼻"]),
        RadicalInfo(id: 210, strokes: 14, glyph: "斉", name: "Even", jaNames: ["せい"], aliases: ["齊", "斉"]),

        // 15 Strokes (211)
        RadicalInfo(id: 211, strokes: 15, glyph: "歯", name: "Tooth", jaNames: ["は"], aliases: ["齒", "歯"]),

        // 16 Strokes (212–213)
        RadicalInfo(id: 212, strokes: 16, glyph: "竜", name: "Dragon", jaNames: ["りゅう"], aliases: ["龍", "竜"]),
        RadicalInfo(id: 213, strokes: 16, glyph: "亀", name: "Turtle", jaNames: ["かめ"], aliases: ["龜", "亀"]),

        // 17 Strokes (214)
        RadicalInfo(id: 214, strokes: 17, glyph: "龠", name: "Flute", jaNames: ["やく", "ふえ"], aliases: ["龠"])
    ]

    static let commonRadicals: [RadicalInfo] = allRadicals.filter { commonIds.contains($0.id) }

    private static let byId: [UInt8: RadicalInfo] = {
        Dictionary(uniqueKeysWithValues: allRadicals.map { ($0.id, $0) })
    }()

    private static let byAlias: [String: UInt8] = {
        var map: [String: UInt8] = [:]
        for r in allRadicals {
            map[r.glyph] = r.id
            for a in r.aliases where map[a] == nil {
                map[a] = r.id
            }
        }
        return map
    }()

    static func info(for id: UInt8) -> RadicalInfo? {
        byId[id]
    }

    static func glyph(for id: UInt8) -> String {
        byId[id]?.glyph ?? "#\(id)"
    }

    static func lookupId(forSymbol symbol: String) -> UInt8? {
        byAlias[symbol]
    }

    static func extractRadicals(from kanji: KanjiDetail) -> [RadicalInfo] {
        if kanji.isUncatalogued && kanji.componentRadicals.isEmpty {
            return []
        }

        var ids: [UInt8] = []
        func appendUnique(_ id: UInt8) {
            if id >= 1 && id <= 214 && !ids.contains(id) {
                ids.append(id)
            }
        }

        if kanji.radicalId >= 1 && kanji.radicalId <= 214 {
            appendUnique(UInt8(kanji.radicalId))
        }

        let raw = kanji.componentRadicals
        if !raw.isEmpty {
            for ch in raw {
                if let rid = lookupId(forSymbol: String(ch)) {
                    appendUnique(rid)
                }
            }
            let parts = raw.components(separatedBy: CharacterSet.decimalDigits.inverted)
            for p in parts where !p.isEmpty {
                if let num = Int(p), num >= 1 && num <= 214 {
                    appendUnique(UInt8(num))
                }
            }
        }

        return ids.compactMap { info(for: $0) }
    }
}

// MARK: - Per-Kanji Ruby Cell

struct RubyCellView: View {
    let cell: RubyCell
    @ObservedObject var engine: DaiJishowEngine

    var body: some View {
        VStack(spacing: 3) {
            if engine.recallMode != .hideKana && !cell.furigana.isEmpty {
                Text(cell.furigana)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.45, green: 0.88, blue: 1.0))
            } else {
                Text(" ")
                    .font(.system(size: 14))
            }

            if cell.kanjiCodepoint > 0 {
                Button {
                    engine.openFisheye(codepoint: cell.kanjiCodepoint, recordHistory: true)
                } label: {
                    Text(cell.surface)
                        .font(.system(size: 46, weight: .bold))
                        .foregroundStyle(.white)
                        .underline(color: .cyan.opacity(0.65))
                }
                .buttonStyle(.plain)
                .help("Explore 「\(cell.surface)」 in Dokusha Fisheye")
            } else {
                HStack(spacing: 0) {
                    ForEach(Array(cell.surface.unicodeScalars.enumerated()), id: \.offset) { _, scalar in
                        let ch = String(scalar)
                        if engine.isKanjiScalar(scalar.value) {
                            Button {
                                engine.openFisheye(codepoint: scalar.value, recordHistory: true)
                            } label: {
                                Text(ch)
                                    .font(.system(size: 46, weight: .bold))
                                    .foregroundStyle(.white)
                                    .underline(color: .cyan.opacity(0.65))
                            }
                            .buttonStyle(.plain)
                            .help("Explore 「\(ch)」 in Dokusha Fisheye")
                        } else {
                            Text(ch)
                                .font(.system(size: 46, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Wrapping Flow Layout for Interactive Sentence Tokens

struct WrappingTokenFlow: Layout {
    var horizontalSpacing: CGFloat = 2
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 800
        var curX: CGFloat = 0
        var curY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for sub in subviews {
            let sz = sub.sizeThatFits(.unspecified)
            if curX + sz.width > maxWidth && curX > 0 {
                curX = 0
                curY += lineHeight + verticalSpacing
                lineHeight = 0
            }
            curX += sz.width + horizontalSpacing
            lineHeight = max(lineHeight, sz.height)
        }
        return CGSize(width: maxWidth, height: curY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var curX = bounds.minX
        var curY = bounds.minY
        var lineHeight: CGFloat = 0

        for sub in subviews {
            let sz = sub.sizeThatFits(.unspecified)
            if curX + sz.width > bounds.maxX && curX > bounds.minX {
                curX = bounds.minX
                curY += lineHeight + verticalSpacing
                lineHeight = 0
            }
            sub.place(at: CGPoint(x: curX, y: curY), anchor: .topLeading, proposal: .unspecified)
            curX += sz.width + horizontalSpacing
            lineHeight = max(lineHeight, sz.height)
        }
    }
}

struct InteractiveSentenceView: View {
    let sentence: SentenceItem
    @ObservedObject var engine: DaiJishowEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WrappingTokenFlow(horizontalSpacing: 2, verticalSpacing: 6) {
                ForEach(sentence.segments) { seg in
                    if let eid = seg.entryId {
                        Button {
                            engine.openWordEntry(entryId: eid)
                        } label: {
                            VStack(spacing: 1) {
                                if engine.recallMode != .hideKana, let furi = seg.furigana {
                                    Text(furi)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color(red: 0.45, green: 0.88, blue: 1.0))
                                } else {
                                    Text(" ")
                                        .font(.system(size: 11))
                                }
                                Text(seg.text)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(.white)
                                    .underline(color: Color.cyan.opacity(0.55))
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .help("Open dictionary entry for 「\(seg.text)」")
                    } else {
                        VStack(spacing: 1) {
                            Text(" ")
                                .font(.system(size: 11))
                            Text(seg.text)
                                .font(.system(size: 20, weight: .regular))
                                .foregroundStyle(.white.opacity(0.88))
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if engine.recallMode != .hideGloss {
                Text(sentence.enText)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.76))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Word Entry Detail Card

struct WordDetailView: View {
    @ObservedObject var engine: DaiJishowEngine

    var body: some View {
        if let entry = engine.activeEntry {
            WordDetailContentView(entry: entry, engine: engine)
        }
    }
}

struct WordDetailContentView: View {
    let entry: EntryDetail
    @ObservedObject var engine: DaiJishowEngine

    var body: some View {
        let variants = entry.header.variantList

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .bottom, spacing: 20) {
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(entry.rubyCells) { cell in
                            RubyCellView(cell: cell, engine: engine)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        if engine.recallMode != .hideKana {
                            HStack(spacing: 10) {
                                Text(entry.header.kanaHead)
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(Color(red: 0.45, green: 0.88, blue: 1.0))
                                if entry.header.pitchAccent != 255 {
                                    Text(entry.header.pitchAccent == 0 ? "平板 [0]" : "Accent [\(entry.header.pitchAccent)]")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(Color.cyan.opacity(0.28), in: Capsule())
                                }
                            }
                        } else {
                            Text("••••••").font(.title2).foregroundStyle(.white.opacity(0.45))
                        }

                        if !variants.isEmpty {
                            HStack(spacing: 8) {
                                Text("Variants:")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.72))

                                ForEach(variants, id: \.self) { variant in
                                    Button {
                                        engine.openVariantForm(variant)
                                    } label: {
                                        Text(variant)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .strokeBorder(Color.cyan.opacity(0.45), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .help("Switch headword / open variant 「\(variant)」")
                                }
                            }
                        }
                    }
                    .padding(.bottom, 6)

                    Spacer()

                    if entry.header.pairEntryId > 0 && !entry.pairedKanji.isEmpty {
                        Button {
                            engine.openWordEntry(entryId: entry.header.pairEntryId)
                        } label: {
                            Label("Paired Verb: \(entry.pairedKanji) (\(entry.pairedKana))", systemImage: "arrow.left.arrow.right")
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Divider().overlay(Color.white.opacity(0.18))

                VStack(alignment: .leading, spacing: 10) {
                    Text("DEFINITIONS")
                        .font(.caption.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.62))

                    ForEach(entry.senses) { sense in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(sense.id + 1).")
                                .font(.body.bold())
                                .foregroundStyle(Color(red: 0.45, green: 0.88, blue: 1.0))
                            if engine.recallMode == .hideGloss {
                                Text("[Definition hidden — Active Recall mode]")
                                    .italic()
                                    .foregroundStyle(.white.opacity(0.55))
                            } else {
                                Text(sense.enGlosses)
                                    .font(.title3)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }

                if !entry.sentences.isEmpty {
                    Divider().overlay(Color.white.opacity(0.18))
                    VStack(alignment: .leading, spacing: 12) {
                        Text("EXAMPLE SENTENCES (\(entry.sentences.count)) — CLICK ANY WORD TO JUMP")
                            .font(.caption.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(.white.opacity(0.62))

                        ForEach(entry.sentences) { sent in
                            InteractiveSentenceView(sentence: sent, engine: engine)
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}

// MARK: - Dokusha Spatial Fisheye Kanji Explorer

private struct FisheyeLegendBar: View {
    @State private var hoveredLegendTier: String?

    private struct LegendTier: Identifiable {
        let id: String
        let color: Color
        let description: String
    }

    private let legendItems: [LegendTier] = [
        LegendTier(
            id: "Core",
            color: Color(red: 0.22, green: 0.74, blue: 0.97),
            description: "Everyday Core — High-frequency compounds in the top ~2,500 Japanese words."
        ),
        LegendTier(
            id: "Jōyō",
            color: Color(red: 0.20, green: 0.83, blue: 0.60),
            description: "Standard Jōyō — Official 2,136 Jōyō kanji & standard newspaper vocabulary."
        ),
        LegendTier(
            id: "Literary",
            color: Color(red: 0.98, green: 0.75, blue: 0.14),
            description: "Literary / Specialized — Formal, written, or domain-specific compounds."
        ),
        LegendTier(
            id: "Kyūjitai",
            color: Color(red: 0.65, green: 0.55, blue: 0.98),
            description: "Kyūjitai / Non-Jōyō — Traditional pre-1946 forms or Jinmeiyō / rare kanji."
        )
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(legendItems) { item in
                HStack(spacing: 4) {
                    Circle()
                        .fill(item.color.opacity(0.35))
                        .overlay(Circle().strokeBorder(item.color, lineWidth: 1.5))
                        .frame(width: 9, height: 9)
                    Text(item.id)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .fixedSize()
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    hoveredLegendTier == item.id ? item.color.opacity(0.22) : Color.clear,
                    in: Capsule()
                )
                .onHover { hovering in
                    hoveredLegendTier = hovering ? item.id : (hoveredLegendTier == item.id ? nil : hoveredLegendTier)
                }
                .popover(isPresented: Binding(
                    get: { hoveredLegendTier == item.id },
                    set: { if !$0 && hoveredLegendTier == item.id { hoveredLegendTier = nil } }
                ), arrowEdge: .bottom) {
                    Text(item.description)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(10)
                        .frame(width: 240)
                }
            }
        }
    }
}

private struct FisheyeBubbleView: View {
    let node: FisheyeNode
    let showPercentages: Bool
    let isSelected: Bool
    let isHovered: Bool
    let dimmed: Bool
    let onTap: () -> Void

    var body: some View {
        let active = !dimmed && (isSelected || isHovered)
        let baseDiam: CGFloat = showPercentages ? 52.0 : 45.0
        let diameter = baseDiam * node.scale

        Button(action: onTap) {
            VStack(spacing: 0) {
                Text(node.glyph)
                    .font(.system(size: (showPercentages ? 21.0 : 22.0) * node.scale, weight: active ? .bold : .semibold))
                    .foregroundStyle(.white)
                if showPercentages {
                    Text(node.shareText)
                        .font(.system(size: 8.5 * max(0.82, node.scale * 0.84), weight: .semibold, design: .monospaced))
                        .foregroundStyle(node.tierColor.opacity(0.95))
                }
            }
            .frame(width: diameter, height: diameter)
            .background(
                Circle()
                    .fill(
                        active
                            ? node.tierColor.opacity(0.45)
                            : Color(red: 0.11, green: 0.15, blue: 0.22).opacity(0.94)
                    )
                    .overlay(
                        Circle().fill(node.tierColor.opacity(active ? 0.25 : 0.16))
                    )
            )
            .overlay(
                Circle()
                    .strokeBorder(
                        active ? Color.white : node.tierColor.opacity(0.75),
                        lineWidth: active ? 2.2 : 1.4
                    )
            )
            .shadow(color: active ? node.tierColor.opacity(0.45) : .clear, radius: 10)
        }
        .buttonStyle(.plain)
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .opacity(dimmed ? 0.15 : node.opacity)
        .allowsHitTesting(!dimmed)
    }
}

private struct OverflowPlacedBubble: Identifiable {
    let node: FisheyeNode
    let pos: CGPoint
    var id: String { node.id }
}

private struct OverflowFanLayout {
    let placed: [OverflowPlacedBubble]
    let maxRadius: CGFloat
    let totalAvailable: Int
}

struct FisheyeExplorerView: View {
    @ObservedObject var engine: DaiJishowEngine
    @State private var lastAspect: Float = 1.85
    @State private var lastFocusNorm: CGPoint?

    @State private var expandedOverflowSide: UInt8?
    @State private var overflowStage: Int = 0
    @State private var overflowPointerPos: CGPoint?
    @State private var hoveredOverflowPos: CGPoint?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                if let k = engine.activeKanji {
                    HStack(spacing: 10) {
                        Text(k.glyph)
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(k.meanings.isEmpty ? k.unicodeBlockLabel : k.meanings)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("On: \(k.onReadings.isEmpty ? "—" : k.onReadings.joined(separator: "・"))   Kun: \(k.kunReadings.isEmpty ? "—" : k.kunReadings.joined(separator: "・"))")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.75))
                                .lineLimit(1)
                        }
                    }
                    Button("Kanji Details & Strokes") {
                        engine.openKanjiDetail(codepoint: k.codepoint)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                FisheyeLegendBar()

                Toggle("%", isOn: $engine.showFisheyePercentages)
                    .toggleStyle(.button)
                    .controlSize(.small)
                    .help("Show or hide compound frequency percentages beneath kanji")

                Picker("Max", selection: $engine.maxFisheyePerSide) {
                    Text("Top 8").tag(8)
                    Text("Top 12").tag(12)
                    Text("Top 16").tag(16)
                    Text("Top 24").tag(24)
                }
                .labelsHidden()
                .frame(width: 86)
                .onChange(of: engine.maxFisheyePerSide) { _, _ in
                    collapseOverflow()
                    refreshLayout(animated: true)
                }

                Picker("Orbit Mode", selection: $engine.fisheyeMode) {
                    Text("2-Kanji").tag(DJ_EDGE_COMPOUNDS)
                    Text("四字熟語").tag(DJ_EDGE_YOJIJUKUGO)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 165)
                .onChange(of: engine.fisheyeMode) { _, _ in
                    engine.selectedFisheyeNode = nil
                    engine.hoveredFisheyeNode = nil
                    collapseOverflow()
                    refreshLayout(animated: true)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)

            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let halfW = max(1.0, geo.size.width / 2)
                let halfH = max(1.0, geo.size.height / 2)
                let ar = Float(geo.size.width / max(1, geo.size.height))

                let leftAnchor = CGPoint(x: 54, y: geo.size.height - 50)
                let rightAnchor = CGPoint(x: geo.size.width - 54, y: geo.size.height - 50)
                let isFanOpen = (expandedOverflowSide != nil && overflowStage > 0)

                let activeFan: OverflowFanLayout? = {
                    guard let side = expandedOverflowSide, overflowStage > 0 else { return nil }
                    let anchor = (side == 0) ? leftAnchor : rightAnchor
                    return computeOverflowFan(side: side, stage: overflowStage, anchor: anchor)
                }()

                ZStack {
                    HStack {
                        Text("← PREFIX + CENTER")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.55))
                        Spacer()
                        Text("CENTER + SUFFIX →")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(.horizontal, 24)
                    .frame(maxHeight: .infinity, alignment: .top)

                    Path { p in
                        p.move(to: CGPoint(x: center.x, y: 24))
                        p.addLine(to: CGPoint(x: center.x, y: geo.size.height - 24))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                    .foregroundStyle(.white.opacity(0.10))

                    Canvas { ctx, _ in
                        for node in engine.fisheyeNodes {
                            let pt = CGPoint(x: center.x + node.normX * halfW, y: center.y + node.normY * halfH)
                            var path = Path()
                            path.move(to: center)
                            path.addLine(to: pt)
                            let isHighlighted = !isFanOpen && ((engine.selectedFisheyeNode?.id == node.id) || (engine.hoveredFisheyeNode?.id == node.id))
                            let baseAlpha = isFanOpen ? 0.06 : (0.24 * node.opacity)
                            ctx.stroke(
                                path,
                                with: .color(isHighlighted ? node.tierColor.opacity(0.95) : node.tierColor.opacity(baseAlpha)),
                                lineWidth: isHighlighted ? 2.4 : 1.1
                            )
                        }
                    }

                    ForEach(engine.fisheyeNodes) { node in
                        let isSelected = engine.selectedFisheyeNode?.id == node.id
                        let isHovered = engine.hoveredFisheyeNode?.id == node.id
                        let pos = CGPoint(x: center.x + node.normX * halfW, y: center.y + node.normY * halfH)

                        FisheyeBubbleView(
                            node: node,
                            showPercentages: engine.showFisheyePercentages,
                            isSelected: isSelected,
                            isHovered: isHovered,
                            dimmed: isFanOpen,
                            onTap: {
                                if isSelected {
                                    engine.openFisheye(codepoint: node.codepoint, recordHistory: true)
                                } else {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        engine.selectedFisheyeNode = node
                                    }
                                }
                            }
                        )
                        .position(pos)
                        .zIndex((!isFanOpen && (isSelected || isHovered)) ? 30.0 : Double(node.scale * 10.0))
                    }

                    if let fan = activeFan {
                        ForEach(fan.placed) { item in
                            let sub = item.node
                            let dockScale: CGFloat = {
                                guard let pt = overflowPointerPos else { return 0.94 }
                                let dist = hypot(item.pos.x - pt.x, item.pos.y - pt.y)
                                let radius: CGFloat = 76.0
                                if dist < radius {
                                    let t = cos((dist / radius) * (.pi / 2.0))
                                    return 1.0 + 0.46 * t * t
                                } else {
                                    return 0.90
                                }
                            }()

                            let baseSize: CGFloat = engine.showFisheyePercentages ? 36.0 : 31.0
                            let diam = baseSize * dockScale
                            let isSelected = engine.selectedFisheyeNode?.id == sub.id
                            let isHov = engine.hoveredFisheyeNode?.id == sub.id
                            let active = isSelected || isHov

                            Button {
                                if isSelected {
                                    engine.openFisheye(codepoint: sub.codepoint, recordHistory: true)
                                } else {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        engine.selectedFisheyeNode = sub
                                    }
                                }
                            } label: {
                                VStack(spacing: 0) {
                                    Text(sub.glyph)
                                        .font(.system(size: 14.5 * dockScale, weight: active ? .bold : .semibold))
                                        .foregroundStyle(.white)
                                    if engine.showFisheyePercentages {
                                        Text(sub.shareText)
                                            .font(.system(size: 7.0 * dockScale, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(sub.tierColor)
                                    }
                                }
                                .frame(width: diam, height: diam)
                                .background(
                                    Circle()
                                        .fill(Color(red: 0.12, green: 0.17, blue: 0.25).opacity(0.97))
                                        .overlay(Circle().fill(sub.tierColor.opacity(active ? 0.36 : 0.18)))
                                )
                                .overlay(
                                    Circle().strokeBorder(active ? Color.white : sub.tierColor, lineWidth: active ? 2.0 : 1.2)
                                )
                                .shadow(color: active ? sub.tierColor.opacity(0.55) : .black.opacity(0.45), radius: 7)
                            }
                            .buttonStyle(.plain)
                            .frame(width: diam, height: diam)
                            .contentShape(Circle())
                            .position(item.pos)
                            .zIndex(25.0 + Double(dockScale * 10.0))
                            .transition(.scale(scale: 0.35).combined(with: .opacity))
                        }
                    }

                    if engine.leftOverflowCount > 0 {
                        overflowTriggerButton(
                            side: 0,
                            totalOverflow: engine.leftOverflowCount,
                            shownCount: expandedOverflowSide == 0 ? (activeFan?.placed.count ?? 0) : 0,
                            anchor: leftAnchor
                        )
                    }
                    if engine.rightOverflowCount > 0 {
                        overflowTriggerButton(
                            side: 1,
                            totalOverflow: engine.rightOverflowCount,
                            shownCount: expandedOverflowSide == 1 ? (activeFan?.placed.count ?? 0) : 0,
                            anchor: rightAnchor
                        )
                    }

                    if let centerKanji = engine.activeKanji {
                        Text(centerKanji.glyph)
                            .font(.system(size: 54, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 92, height: 92)
                            .background(Color(red: 0.12, green: 0.17, blue: 0.25), in: Circle())
                            .overlay(Circle().strokeBorder(.cyan.opacity(0.85), lineWidth: 2.5))
                            .shadow(color: .cyan.opacity(0.3), radius: 18)
                            .position(center)
                            .zIndex(15)
                    }

                    if let hov = engine.hoveredFisheyeNode {
                        let nodeX: CGFloat = {
                            if hov.isOverflowPreview {
                                return hoveredOverflowPos?.x ?? (hov.side == 0 ? 170.0 : geo.size.width - 170.0)
                            }
                            return center.x + hov.normX * halfW
                        }()
                        let nodeY: CGFloat = {
                            if hov.isOverflowPreview {
                                return hoveredOverflowPos?.y ?? (geo.size.height - 180.0)
                            }
                            return center.y + hov.normY * halfH
                        }()
                        let popY = (nodeY < 115) ? (nodeY + 62) : (nodeY - 62)
                        let popX = min(max(nodeX, 150), geo.size.width - 150)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(hov.compoundWord)
                                    .font(.headline.bold())
                                    .foregroundStyle(.white)
                                Text("【\(hov.compoundKana)】")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(hov.tierColor)
                                Spacer(minLength: 4)
                                Text("\(hov.tierLabel) • \(hov.shareText)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(hov.tierColor.opacity(0.32), in: Capsule())
                            }
                            Text(hov.compoundGloss)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.88))
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(width: 280, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(red: 0.08, green: 0.11, blue: 0.17).opacity(0.96))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(hov.tierColor.opacity(0.85), lineWidth: 1.3)
                        )
                        .shadow(color: .black.opacity(0.55), radius: 14, x: 0, y: 6)
                        .position(x: popX, y: popY)
                        .allowsHitTesting(false)
                        .zIndex(50)
                    }
                }
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    guard let cp = engine.activeKanji?.codepoint else { return }
                    switch phase {
                    case .active(let loc):
                        let nearLeftTrigger = engine.leftOverflowCount > 0 && hypot(loc.x - leftAnchor.x, loc.y - leftAnchor.y) <= 34.0
                        let nearRightTrigger = engine.rightOverflowCount > 0 && hypot(loc.x - rightAnchor.x, loc.y - rightAnchor.y) <= 34.0

                        if nearLeftTrigger || nearRightTrigger {
                            let targetSide: UInt8 = nearLeftTrigger ? 0 : 1
                            if expandedOverflowSide != targetSide || overflowStage == 0 {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                    expandedOverflowSide = targetSide
                                    overflowStage = 1
                                }
                            }
                            overflowPointerPos = loc
                            hoveredOverflowPos = nil
                            if engine.hoveredFisheyeNode?.isOverflowPreview == true {
                                engine.hoveredFisheyeNode = nil
                            }
                            return
                        }

                        if let activeSide = expandedOverflowSide, overflowStage > 0 {
                            let anchor = (activeSide == 0) ? leftAnchor : rightAnchor
                            let fan = computeOverflowFan(side: activeSide, stage: overflowStage, anchor: anchor)
                            let distFromAnchor = hypot(loc.x - anchor.x, loc.y - anchor.y)
                            let withinHemisphere = (activeSide == 0) ? (loc.x <= center.x + 36.0) : (loc.x >= center.x - 36.0)

                            if withinHemisphere && distFromAnchor <= fan.maxRadius + 56.0 {
                                overflowPointerPos = loc
                                let baseSize: CGFloat = engine.showFisheyePercentages ? 36.0 : 31.0
                                var bestSub: FisheyeNode?
                                var bestPos: CGPoint?
                                var bestDist: CGFloat = .greatestFiniteMagnitude

                                for item in fan.placed {
                                    let d = hypot(item.pos.x - loc.x, item.pos.y - loc.y)
                                    let dockScale: CGFloat = d < 76.0 ? (1.0 + 0.46 * pow(cos((d / 76.0) * (.pi / 2.0)), 2)) : 0.90
                                    let hitR = (baseSize * dockScale) * 0.58
                                    if d <= hitR && d < bestDist {
                                        bestDist = d
                                        bestSub = item.node
                                        bestPos = item.pos
                                    }
                                }

                                hoveredOverflowPos = bestPos
                                if engine.hoveredFisheyeNode?.id != bestSub?.id {
                                    engine.hoveredFisheyeNode = bestSub
                                }
                                return
                            } else {
                                collapseOverflow()
                            }
                        }

                        let fx = Float((loc.x - center.x) / halfW)
                        let fy = Float((loc.y - center.y) / halfH)
                        let nearCenter = hypot(Double(fx * ar), Double(fy)) < 0.11

                        if nearCenter {
                            engine.hoveredFisheyeNode = nil
                            if lastFocusNorm != nil {
                                lastFocusNorm = nil
                                engine.solveFisheye(center: cp, hasFocus: false, focusX: 0, focusY: 0, aspectRatio: ar, animated: true)
                            }
                        } else {
                            let wasFocused = (lastFocusNorm != nil)
                            lastFocusNorm = CGPoint(x: CGFloat(fx), y: CGFloat(fy))
                            engine.solveFisheye(center: cp, hasFocus: true, focusX: fx, focusY: fy, aspectRatio: ar, animated: !wasFocused)

                            let baseDiam: CGFloat = engine.showFisheyePercentages ? 52.0 : 45.0
                            var bestNode: FisheyeNode?
                            var bestDist: CGFloat = .greatestFiniteMagnitude
                            for node in engine.fisheyeNodes {
                                let bx = center.x + node.normX * halfW
                                let by = center.y + node.normY * halfH
                                let d = hypot(loc.x - bx, loc.y - by)
                                let hitRadius = (baseDiam * node.scale) * 0.56
                                if d <= hitRadius && d < bestDist {
                                    bestDist = d
                                    bestNode = node
                                }
                            }
                            if engine.hoveredFisheyeNode?.id != bestNode?.id {
                                engine.hoveredFisheyeNode = bestNode
                            }
                        }

                    case .ended:
                        lastFocusNorm = nil
                        engine.hoveredFisheyeNode = nil
                        collapseOverflow()
                        engine.solveFisheye(center: cp, hasFocus: false, focusX: 0, focusY: 0, aspectRatio: ar, animated: true)
                    }
                }
                .onAppear {
                    lastAspect = ar
                    refreshLayout(animated: false)
                }
                .onChange(of: geo.size) { _, newSize in
                    lastAspect = Float(newSize.width / max(1, newSize.height))
                    refreshLayout(animated: false)
                }
                .onChange(of: engine.activeKanji?.codepoint) { _, _ in
                    lastFocusNorm = nil
                    collapseOverflow()
                    refreshLayout(animated: false)
                }
            }

            HStack(spacing: 16) {
                if let sel = engine.selectedFisheyeNode {
                    Text(sel.compoundWord)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("【\(sel.compoundKana)】")
                        .font(.headline)
                        .foregroundStyle(sel.tierColor)
                    Text(sel.compoundGloss)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)
                    Spacer()
                    Button("Open Word Entry") {
                        engine.openWordEntry(entryId: sel.topEntryId)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Center on 「\(sel.glyph)」") {
                        engine.openFisheye(codepoint: sel.codepoint, recordHistory: true)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Text("Move pointer across bubbles for 3D magnification & compound preview; click to pin or double-click to pivot.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                    Spacer()
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }

    @ViewBuilder
    private func overflowTriggerButton(side: UInt8, totalOverflow: Int, shownCount: Int, anchor: CGPoint) -> some View {
        let isExpanded = (expandedOverflowSide == side && overflowStage > 0)
        let remaining = max(0, totalOverflow - shownCount)

        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
                if expandedOverflowSide != side || overflowStage == 0 {
                    expandedOverflowSide = side
                    overflowStage = 1
                } else if overflowStage == 1 && remaining > 0 {
                    overflowStage = 2
                } else if overflowStage == 2 && remaining > 0 {
                    overflowStage = 3
                } else {
                    overflowStage = 1
                }
            }
        } label: {
            VStack(spacing: 1) {
                Text(!isExpanded ? "+\(totalOverflow)" : (remaining > 0 ? "+\(remaining)" : "All \(totalOverflow)"))
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Text(!isExpanded ? "more" : (remaining > 0 ? "expand" : "shown"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .frame(width: 50, height: 50)
            .background(Color.white.opacity(isExpanded ? 0.18 : 0.09), in: Circle())
            .overlay(
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.4, dash: isExpanded ? [] : [3, 3]))
                    .foregroundStyle(.cyan.opacity(0.85))
            )
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .help(!isExpanded ? "Hover to preview; click to expand more kanji" : (remaining > 0 ? "Click again to show even more kanji" : "Click to collapse back to inner rings"))
        .position(anchor)
        .zIndex(45)
    }

    private func computeOverflowFan(side: UInt8, stage: Int, anchor: CGPoint) -> OverflowFanLayout {
        let allItems = engine.overflowPreviewNodes.filter { $0.side == side }
        let maxRings: Int = {
            switch stage {
            case 1: return 2
            case 2: return 4
            default: return 99
            }
        }()

        let dir: CGFloat = (side == 0) ? 1.0 : -1.0
        let arcSpanDeg: CGFloat = 84.0
        let arcSpanRad: CGFloat = arcSpanDeg * .pi / 180.0
        let minArcSpacing: CGFloat = 40.0

        var rings: [[FisheyeNode]] = []
        var cursor = 0
        var ringIdx = 0
        while cursor < allItems.count && ringIdx < maxRings {
            let r = 68.0 + CGFloat(ringIdx) * 43.0
            let cap = max(3, Int(floor((r * arcSpanRad) / minArcSpacing)))
            let end = min(allItems.count, cursor + cap)
            rings.append(Array(allItems[cursor..<end]))
            cursor = end
            ringIdx += 1
        }

        var placed: [OverflowPlacedBubble] = []
        var outerRadius: CGFloat = 68.0

        for (rIdx, ringNodes) in rings.enumerated() {
            let r = 68.0 + CGFloat(rIdx) * 43.0
            outerRadius = r
            let count = ringNodes.count
            for (i, node) in ringNodes.enumerated() {
                let t = count <= 1 ? 0.5 : CGFloat(i) / CGFloat(count - 1)
                let angleDeg = -86.0 + t * arcSpanDeg
                let rad = angleDeg * .pi / 180.0
                let pos = CGPoint(
                    x: anchor.x + dir * cos(rad) * r,
                    y: anchor.y + sin(rad) * r
                )
                placed.append(OverflowPlacedBubble(node: node, pos: pos))
            }
        }

        return OverflowFanLayout(placed: placed, maxRadius: outerRadius, totalAvailable: allItems.count)
    }

    private func collapseOverflow() {
        if expandedOverflowSide != nil || overflowStage != 0 {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                expandedOverflowSide = nil
                overflowStage = 0
                overflowPointerPos = nil
                hoveredOverflowPos = nil
            }
        }
    }

    private func refreshLayout(animated: Bool) {
        guard let cp = engine.activeKanji?.codepoint else { return }
        if let pt = lastFocusNorm {
            engine.solveFisheye(center: cp, hasFocus: true, focusX: Float(pt.x), focusY: Float(pt.y), aspectRatio: lastAspect, animated: animated)
        } else {
            engine.solveFisheye(center: cp, hasFocus: false, focusX: 0, focusY: 0, aspectRatio: lastAspect, animated: animated)
        }
    }
}

// MARK: - Kanji Detail & Animated Quantized Stroke-Order Canvas

struct KanjiDetailView: View {
    @ObservedObject var engine: DaiJishowEngine

    var body: some View {
        if let k = engine.activeKanji {
            KanjiDetailContentView(kanji: k, engine: engine)
                .onChange(of: engine.includeNames) { _, _ in
                    engine.refreshActiveKanjiDetail()
                }
        }
    }
}

struct KanjiDetailContentView: View {
    let kanji: KanjiDetail
    @ObservedObject var engine: DaiJishowEngine
    @State private var visibleStrokes: Int = 999

    var body: some View {
        let resolvedRadicals = RadicalCatalog.extractRadicals(from: kanji)
        let hasStrokes = !kanji.strokePolylines.isEmpty

        HStack(alignment: .top, spacing: 24) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.35))
                    Path { p in
                        p.move(to: CGPoint(x: 110, y: 0)); p.addLine(to: CGPoint(x: 110, y: 220))
                        p.move(to: CGPoint(x: 0, y: 110)); p.addLine(to: CGPoint(x: 220, y: 110))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.white.opacity(0.22))

                    if hasStrokes {
                        Canvas { ctx, size in
                            let limit = min(visibleStrokes, kanji.strokePolylines.count)
                            for sIdx in 0..<limit {
                                let pts = kanji.strokePolylines[sIdx]
                                guard pts.count >= 2 else { continue }
                                var path = Path()
                                path.move(to: CGPoint(x: pts[0].x * size.width, y: pts[0].y * size.height))
                                for pt in pts.dropFirst() {
                                    path.addLine(to: CGPoint(x: pt.x * size.width, y: pt.y * size.height))
                                }
                                let isLatest = (sIdx == limit - 1 && visibleStrokes <= kanji.strokePolylines.count)
                                ctx.stroke(
                                    path,
                                    with: .color(isLatest ? .cyan : .white),
                                    style: StrokeStyle(lineWidth: 5.0, lineCap: .round, lineJoin: .round)
                                )
                            }
                        }
                        .padding(16)
                    } else {
                        VStack(spacing: 6) {
                            Text(kanji.unicodeHex)
                                .font(.caption.monospaced().bold())
                                .foregroundStyle(.cyan.opacity(0.85))
                            Text("No KanjiVG\nstroke vector")
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        .padding(12)
                    }
                }
                .frame(width: 220, height: 220)

                HStack {
                    Button("Animate Strokes") {
                        animateStrokes(total: kanji.strokePolylines.count)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasStrokes)

                    Button("Explorer") {
                        engine.openFisheye(codepoint: kanji.codepoint, recordHistory: true)
                    }
                    .buttonStyle(.bordered)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Unicode")
                            .foregroundStyle(.white.opacity(0.55))
                        Spacer()
                        Text(kanji.unicodeHex)
                            .font(.caption.monospaced().bold())
                            .foregroundStyle(.cyan)
                    }
                    HStack {
                        Text("Block")
                            .foregroundStyle(.white.opacity(0.55))
                        Spacer()
                        Text((0x3400...0x4DBF).contains(kanji.codepoint) ? "CJK Extension A" : "CJK Unified")
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    if kanji.freqRank < 999_999 {
                        HStack {
                            Text("News Freq.")
                                .foregroundStyle(.white.opacity(0.55))
                            Spacer()
                            Text("#\(kanji.freqRank)")
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                }
                .font(.caption)
                .padding(12)
                .frame(width: 220)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )

                Spacer()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text(kanji.glyph)
                            .font(.system(size: 54, weight: .bold))
                            .foregroundStyle(.white)
                        if !kanji.meanings.isEmpty {
                            Text(kanji.meanings)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                        } else {
                            Text("Variant / Extended Kanji")
                                .font(.title3.weight(.medium))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }

                    if let specialTitle = kanji.specialCaseTitle,
                       let specialBody = kanji.specialCaseExplanation {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color(red: 0.98, green: 0.75, blue: 0.14))
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(specialTitle)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                                Text(specialBody)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.82))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.98, green: 0.75, blue: 0.14).opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color(red: 0.98, green: 0.75, blue: 0.14).opacity(0.45), lineWidth: 1)
                        )
                    }

                    Divider().overlay(Color.white.opacity(0.18))

                    Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 11) {
                        GridRow {
                            Text("On'yomi:").foregroundStyle(.white.opacity(0.65))
                            Text(kanji.onReadings.isEmpty ? "—" : kanji.onReadings.joined(separator: "、"))
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        GridRow {
                            Text("Kun'yomi:").foregroundStyle(.white.opacity(0.65))
                            Text(kanji.kunReadings.isEmpty ? "—" : kanji.kunReadings.joined(separator: "、"))
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        GridRow {
                            Text("Component Radicals:").foregroundStyle(.white.opacity(0.65))
                            if !resolvedRadicals.isEmpty {
                                HStack(spacing: 8) {
                                    ForEach(resolvedRadicals) { rad in
                                        Button {
                                            engine.openRadicalBuilder(withRadicals: [rad.id])
                                        } label: {
                                            HStack(spacing: 4) {
                                                Text(rad.glyph)
                                                    .font(.title3.bold())
                                                    .foregroundStyle(.white)
                                                Text("#\(rad.id)")
                                                    .font(.caption2.monospacedDigit())
                                                    .foregroundStyle(Color(red: 0.45, green: 0.88, blue: 1.0))
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.cyan.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .strokeBorder(Color.cyan.opacity(0.55), lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .help("Search kanji with radical \(rad.glyph) (\(rad.name), #\(rad.id))")
                                    }

                                    if resolvedRadicals.count > 1 {
                                        Button {
                                            engine.openRadicalBuilder(withRadicals: resolvedRadicals.map(\.id))
                                        } label: {
                                            Label("Intersect All (\(resolvedRadicals.count))", systemImage: "square.grid.3x3")
                                                .font(.caption.bold())
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                        .help("Open Radical Builder with all \(resolvedRadicals.count) radicals populated in the intersection")
                                    }
                                }
                            } else {
                                Text(kanji.isUncatalogued ? "Not catalogued in KANJIDIC2" : (kanji.componentRadicals.isEmpty ? "Radical #\(kanji.radicalId)" : kanji.componentRadicals))
                                    .font(.subheadline)
                                    .foregroundStyle(kanji.isUncatalogued ? .white.opacity(0.55) : Color(red: 0.45, green: 0.88, blue: 1.0))
                            }
                        }
                        GridRow {
                            Text("Stats:").foregroundStyle(.white.opacity(0.65))
                            Text("\(kanji.strokes > 0 ? "\(kanji.strokes) strokes" : "Strokes uncatalogued")  •  JLPT N\(kanji.jlpt == 0 ? "-" : "\(kanji.jlpt)")  •  Grade \(kanji.grade)  •  Freq \(kanji.freqRank >= 999_999 ? "—" : "#\(kanji.freqRank)")")
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }

                    if !kanji.standaloneEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label(
                                    kanji.standaloneEntries.count == 1
                                        ? "STANDALONE WORD ENTRY"
                                        : "STANDALONE WORD ENTRIES (\(kanji.standaloneEntries.count))",
                                    systemImage: "book.closed.fill"
                                )
                                .font(.caption.weight(.bold))
                                .tracking(0.8)
                                .foregroundStyle(Color(red: 0.45, green: 0.88, blue: 1.0))

                                Spacer()

                                Text("This kanji is a standalone word")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.58))
                            }

                            ForEach(kanji.standaloneEntries, id: \.header.id) { entry in
                                Button {
                                    engine.openWordEntry(entryId: entry.header.id)
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 10) {
                                            Text(entry.header.displayHeadword)
                                                .font(.title2.bold())
                                                .foregroundStyle(.white)

                                            if engine.recallMode != .hideKana {
                                                Text("【\(entry.header.kanaHead)】")
                                                    .font(.headline.weight(.semibold))
                                                    .foregroundStyle(Color(red: 0.45, green: 0.88, blue: 1.0))
                                            }

                                            if entry.header.pitchAccent != 255 && engine.recallMode != .hideKana {
                                                Text(entry.header.pitchAccent == 0 ? "平板 [0]" : "[\(entry.header.pitchAccent)]")
                                                    .font(.caption2.bold())
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 7)
                                                    .padding(.vertical, 2)
                                                    .background(Color.cyan.opacity(0.28), in: Capsule())
                                            }

                                            if entry.header.isName {
                                                Text("NAME")
                                                    .font(.caption2.bold())
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.purple.opacity(0.55), in: Capsule())
                                            }

                                            Spacer()

                                            HStack(spacing: 4) {
                                                Text("Open Word Card")
                                                    .font(.caption.bold())
                                                Image(systemName: "arrow.up.right")
                                                    .font(.caption.bold())
                                            }
                                            .foregroundStyle(Color(red: 0.45, green: 0.88, blue: 1.0))
                                        }

                                        if engine.recallMode == .hideGloss {
                                            Text("[Definition hidden — Active Recall mode]")
                                                .font(.subheadline)
                                                .italic()
                                                .foregroundStyle(.white.opacity(0.55))
                                        } else {
                                            VStack(alignment: .leading, spacing: 4) {
                                                ForEach(entry.senses.prefix(4)) { sense in
                                                    HStack(alignment: .top, spacing: 6) {
                                                        Text("\(sense.id + 1).")
                                                            .font(.subheadline.bold())
                                                            .foregroundStyle(Color(red: 0.45, green: 0.88, blue: 1.0))
                                                        Text(sense.enGlosses)
                                                            .font(.subheadline)
                                                            .foregroundStyle(.white.opacity(0.92))
                                                            .multilineTextAlignment(.leading)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.cyan.opacity(0.11), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(Color.cyan.opacity(0.48), lineWidth: 1.2)
                                    )
                                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .help("Open full word entry for 「\(entry.header.displayHeadword)」")
                            }
                        }
                    }

                    if !kanji.relatedWords.isEmpty {
                        Divider().overlay(Color.white.opacity(0.18))

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("COMMON WORDS WITH 「\(kanji.glyph)」 (SORTED BY PREVALENCE)")
                                    .font(.caption.weight(.bold))
                                    .tracking(0.8)
                                    .foregroundStyle(.white.opacity(0.65))
                                Spacer()
                                Text("\(kanji.relatedWords.count) words")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.white.opacity(0.52))
                            }

                            VStack(spacing: 6) {
                                ForEach(kanji.relatedWords) { word in
                                    Button {
                                        engine.openWordEntry(entryId: word.id)
                                    } label: {
                                        HStack(spacing: 12) {
                                            prevalenceBadge(for: word)

                                            Text(word.displayHeadword)
                                                .font(.headline.bold())
                                                .foregroundStyle(.white)
                                                .frame(minWidth: 96, alignment: .leading)

                                            if engine.recallMode != .hideKana {
                                                Text(word.kanaHead)
                                                    .font(.subheadline.weight(.medium))
                                                    .foregroundStyle(Color(red: 0.45, green: 0.88, blue: 1.0))
                                                    .frame(minWidth: 105, alignment: .leading)
                                            }

                                            if engine.recallMode != .hideGloss {
                                                Text(word.primaryGloss)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.white.opacity(0.85))
                                                    .lineLimit(1)
                                            }

                                            Spacer(minLength: 8)

                                            Image(systemName: "chevron.right")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white.opacity(0.42))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 9)
                                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                                        )
                                        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Open word card for 「\(word.displayHeadword)」")
                                }
                            }
                        }
                    }
                }
                .padding(.trailing, 8)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .onAppear { visibleStrokes = kanji.strokePolylines.count }
        .onChange(of: kanji.codepoint) { _, _ in
            visibleStrokes = kanji.strokePolylines.count
        }
    }

    @ViewBuilder
    private func prevalenceBadge(for word: WordHit) -> some View {
        let info: (label: String, color: Color) = {
            if word.isName {
                return ("Name", Color.purple)
            } else if word.freqRank <= 2500 {
                return ("Core", Color(red: 0.22, green: 0.74, blue: 0.97))
            } else if word.freqRank <= 12000 {
                return ("Jōyō", Color(red: 0.20, green: 0.83, blue: 0.60))
            } else if word.freqRank < 150000 {
                return ("Common", Color(red: 0.98, green: 0.75, blue: 0.14))
            } else {
                return ("Standard", Color.white.opacity(0.45))
            }
        }()

        Text(info.label)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 56)
            .padding(.vertical, 3)
            .background(info.color.opacity(0.28), in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(info.color.opacity(0.65), lineWidth: 0.9)
            )
    }

    private func animateStrokes(total: Int) {
        visibleStrokes = 0
        for step in 1...max(1, total) {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.16) {
                withAnimation(.easeOut(duration: 0.14)) {
                    visibleStrokes = step
                }
            }
        }
    }
}

// MARK: - Dokusha 7-Slot Multi-Radical Intersection Builder

struct RadicalBuilderView: View {
    @ObservedObject var engine: DaiJishowEngine
    @State private var showAllRadicals: Bool = false
    @State private var radicalFilterText: String = ""

    private var filteredAllRadicals: [RadicalInfo] {
        let q = radicalFilterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty {
            return RadicalCatalog.allRadicals
        }

        // Exact radical # lookup (e.g., "#85")
        if q.hasPrefix("#"), let idNum = Int(q.dropFirst()), idNum >= 1 && idNum <= 214 {
            return RadicalCatalog.allRadicals.filter { Int($0.id) == idNum }
        }

        // Pure numeric query: match exact stroke count (e.g., "4" -> 4-stroke radicals)
        if let num = Int(q) {
            return RadicalCatalog.allRadicals.filter { $0.strokes == num }
        }

        let hiraQ = KanaNormalizer.cleanReadingToken(KanaNormalizer.romajiToHiragana(q))

        return RadicalCatalog.allRadicals.filter { rad in
            // Direct glyph or positional variant match
            if rad.glyph.contains(q) || rad.aliases.contains(where: { $0.contains(q) }) {
                return true
            }
            // Japanese radical name / reading match (kana or romaji)
            if !hiraQ.isEmpty && rad.jaNames.contains(where: { $0.hasPrefix(hiraQ) || $0.contains(hiraQ) }) {
                return true
            }
            // English radical name match (word-prefix or substring when >= 2 chars)
            let lowerName = rad.name.lowercased()
            let words = lowerName.split(separator: " ")
            if words.contains(where: { $0.hasPrefix(q) }) {
                return true
            }
            if q.count >= 2 && lowerName.contains(q) {
                return true
            }
            return false
        }
    }

    private var groupedByStroke: [(strokes: Int, radicals: [RadicalInfo])] {
        let dict = Dictionary(grouping: filteredAllRadicals, by: \.strokes)
        return dict.keys.sorted().map { st in
            (strokes: st, radicals: dict[st] ?? [])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("7-Slot Multi-Radical Intersection")
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Picker("Scope", selection: $showAllRadicals) {
                    Text("Common (36)").tag(false)
                    Text("All 214").tag(true)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 185)

                if showAllRadicals {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(.cyan.opacity(0.85))
                        TextField("Name, kana, or stroke #...", text: $radicalFilterText)
                            .textFieldStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.white)
                        if !radicalFilterText.isEmpty {
                            Button {
                                radicalFilterText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .frame(width: 195)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }

                Spacer()

                HStack(spacing: 6) {
                    Stepper(
                        "Strokes: \(engine.radicalTargetStrokes == 0 ? "Any" : "\(engine.radicalTargetStrokes)")",
                        value: $engine.radicalTargetStrokes,
                        in: 0...30
                    )
                    .foregroundStyle(.white)
                    .frame(width: 155)
                    .onChange(of: engine.radicalTargetStrokes) { _, _ in runQuery() }

                    if engine.radicalTargetStrokes > 0 {
                        Picker("Tol", selection: $engine.radicalStrokeTolerance) {
                            Text("Exact").tag(Int8(0))
                            Text("±1").tag(Int8(1))
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 96)
                        .onChange(of: engine.radicalStrokeTolerance) { _, _ in runQuery() }
                    }
                }

                Button("Clear") {
                    engine.radicalSelectedIds.removeAll()
                    engine.radicalTargetStrokes = 0
                    engine.radicalMatches = []
                }
                .buttonStyle(.bordered)
            }

            // 7-Slot Active Radical Intersection Tray
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { slot in
                    let radId = slot < engine.radicalSelectedIds.count ? engine.radicalSelectedIds[slot] : nil
                    let glyph = radId.map { RadicalCatalog.glyph(for: $0) } ?? "—"

                    Button {
                        if let idToRemove = radId {
                            engine.radicalSelectedIds.removeAll { $0 == idToRemove }
                            runQuery()
                        }
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Text(glyph)
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(radId != nil ? Color.cyan.opacity(0.32) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(radId != nil ? Color.cyan.opacity(0.75) : Color.clear, lineWidth: 1)
                                )
                            if radId != nil {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .padding(2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(radId == nil)
                    .help(radId != nil ? "Remove \(glyph) from intersection" : "Empty radical slot \(slot + 1)")
                }

                if !engine.radicalSelectedIds.isEmpty || engine.radicalTargetStrokes > 0 {
                    Text("\(engine.radicalMatches.count) matching kanji")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.45, green: 0.88, blue: 1.0))
                        .padding(.leading, 8)
                }
            }

            if !showAllRadicals {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 12), spacing: 6) {
                    ForEach(RadicalCatalog.commonRadicals) { rad in
                        radicalButton(rad)
                    }
                }
            } else {
                if filteredAllRadicals.isEmpty {
                    HStack(spacing: 10) {
                        Text("No radicals match “\(radicalFilterText)”")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.65))
                        Button("Reset Filter") {
                            radicalFilterText = ""
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 12)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(groupedByStroke, id: \.strokes) { group in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("\(group.strokes) \(group.strokes == 1 ? "STROKE" : "STROKES")")
                                        .font(.caption2.bold())
                                        .tracking(0.8)
                                        .foregroundStyle(.white.opacity(0.58))

                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 10), spacing: 6) {
                                        ForEach(group.radicals) { rad in
                                            radicalButton(rad)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.trailing, 4)
                    }
                    .frame(maxHeight: 225)
                }
            }

            Divider().overlay(Color.white.opacity(0.18))

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 10), spacing: 8) {
                    ForEach(engine.radicalMatches, id: \.self) { cp in
                        let glyph = String(UnicodeScalar(cp)!)
                        let meta = engine.kanjiIndexItem(for: cp)

                        Button {
                            engine.openFisheye(codepoint: cp, recordHistory: true)
                        } label: {
                            VStack(spacing: 2) {
                                Text(glyph)
                                    .font(.system(size: 27, weight: .medium))
                                    .foregroundStyle(.white)
                                if let m = meta, m.strokes > 0 {
                                    Text("\(m.strokes)画")
                                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.cyan.opacity(0.85))
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .help(meta.map { "\(glyph) (\($0.strokes) strokes) — \($0.meanings)" } ?? glyph)
                    }
                }
            }
        }
        .padding(20)
        .onAppear {
            if engine.radicalSelectedIds.contains(where: { !RadicalCatalog.commonIds.contains($0) }) {
                showAllRadicals = true
            }
        }
        .onChange(of: engine.radicalSelectedIds) { _, newIds in
            if newIds.contains(where: { !RadicalCatalog.commonIds.contains($0) }) {
                showAllRadicals = true
            }
        }
    }

    @ViewBuilder
    private func radicalButton(_ rad: RadicalInfo) -> some View {
        let active = engine.radicalSelectedIds.contains(rad.id)
        Button {
            if active {
                engine.radicalSelectedIds.removeAll { $0 == rad.id }
            } else if engine.radicalSelectedIds.count < 7 {
                engine.radicalSelectedIds.append(rad.id)
            }
            runQuery()
        } label: {
            VStack(spacing: 1) {
                Text(rad.glyph)
                    .font(.title3)
                    .foregroundStyle(.white)
                if showAllRadicals {
                    Text(rad.name)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(active ? Color.cyan : .white.opacity(0.62))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: showAllRadicals ? 44 : 36)
            .background(active ? Color.cyan.opacity(0.38) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(active ? Color.cyan.opacity(0.85) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help("\(rad.glyph) — \(rad.name) (\(rad.jaNames.joined(separator: "・")), Radical #\(rad.id), \(rad.strokes) strokes)")
    }

    private func runQuery() {
        engine.searchRadicals(
            selectedIds: engine.radicalSelectedIds,
            targetStrokes: Int16(engine.radicalTargetStrokes),
            tolerance: engine.radicalStrokeTolerance
        )
    }
}

// MARK: - Canon Wordtank-Style Multi-Mode Kanji Lookup Screen

struct KanjiLookupView: View {
    @ObservedObject var engine: DaiJishowEngine

    private let skipPatterns: [(id: Int, icon: String, title: String)] = [
        (1, "⿰", "Left–Right"),
        (2, "⿱", "Top–Bottom"),
        (3, "⿴", "Enclosure"),
        (4, "⿻", "Solid / Other")
    ]

    private let fourCornerLegend: [(digit: String, glyph: String, label: String)] = [
        ("0", "亠", "Lid"),
        ("1", "一", "Horiz"),
        ("2", "丨", "Vert"),
        ("3", "丶", "Dot"),
        ("4", "十", "Cross"),
        ("5", "キ", "Skewer"),
        ("6", "口", "Box"),
        ("7", "厂", "Angle"),
        ("8", "八", "Eight"),
        ("9", "小", "Small")
    ]

    private let gradeOptions: [(tag: Int, label: String)] = [
        (1, "Grade 1"), (2, "Grade 2"), (3, "Grade 3"),
        (4, "Grade 4"), (5, "Grade 5"), (6, "Grade 6"),
        (8, "Secondary Jōyō"),
        (-5, "JLPT N5"), (-4, "JLPT N4"), (-3, "JLPT N3"), (-2, "JLPT N2"), (-1, "JLPT N1")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header + Wordtank Lookup Mode Tabs + Sort Selector
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "character.book.closed.fill")
                        .font(.title3)
                        .foregroundStyle(.cyan)
                    Text("Kanji Index")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }

                Picker("Lookup Mode", selection: $engine.kanjiLookupMode) {
                    ForEach(KanjiLookupMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 530)
                .onChange(of: engine.kanjiLookupMode) { _, _ in
                    engine.runKanjiLookup()
                }

                Spacer()

                HStack(spacing: 6) {
                    Text("Sort:")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.65))
                    Picker("Sort", selection: $engine.kanjiLookupSort) {
                        ForEach(KanjiSortOrder.allCases) { sort in
                            Text(sort.rawValue).tag(sort)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 118)
                    .onChange(of: engine.kanjiLookupSort) { _, _ in
                        engine.runKanjiLookup()
                    }
                }
            }

            // Mode-Specific Control Panel
            modeControlsView
                .padding(14)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )

            // Results Header
            HStack {
                Text(resultsHeaderTitle)
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.68))
                Spacer()
                Text("\(engine.kanjiLookupResults.count)\(engine.kanjiLookupResults.count == 360 ? "+" : "") kanji")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(Color(red: 0.45, green: 0.88, blue: 1.0))
            }

            // Scrollable Kanji Result Cards
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                    ForEach(engine.kanjiLookupResults) { item in
                        kanjiResultTile(item)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .padding(20)
        .onAppear {
            if engine.kanjiLookupResults.isEmpty {
                engine.runKanjiLookup()
            }
        }
    }

    private var resultsHeaderTitle: String {
        switch engine.kanjiLookupMode {
        case .strokes:
            let tol = engine.kanjiLookupStrokeTolerance == 0 ? "EXACT" : "±1"
            return "\(engine.kanjiLookupStrokeCount)-STROKE KANJI (\(tol)) • SORTED BY \(engine.kanjiLookupSort.rawValue.uppercased())"
        case .reading:
            let q = engine.kanjiLookupReadingQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            return q.isEmpty
                ? "TOP CORE KANJI BY READING • TYPE KANA OR ROMAJI"
                : "KANJI READING “\(KanaNormalizer.romajiToHiragana(q))” • SORTED BY \(engine.kanjiLookupSort.rawValue.uppercased())"
        case .skip:
            return "SKIP PATTERN \(engine.kanjiLookupSkipPattern) • SORTED BY \(engine.kanjiLookupSort.rawValue.uppercased())"
        case .fourCorner:
            return "FOUR-CORNER INDEX • SORTED BY \(engine.kanjiLookupSort.rawValue.uppercased())"
        case .gradeJlpt:
            return "CURRICULUM & JLPT LEVEL • SORTED BY \(engine.kanjiLookupSort.rawValue.uppercased())"
        case .meaning:
            return "ENGLISH MEANING KEYWORD • SORTED BY \(engine.kanjiLookupSort.rawValue.uppercased())"
        }
    }

    @ViewBuilder
    private var modeControlsView: some View {
        switch engine.kanjiLookupMode {
        case .strokes:
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    Stepper(
                        "Total Strokes: \(engine.kanjiLookupStrokeCount)",
                        value: $engine.kanjiLookupStrokeCount,
                        in: 1...30
                    )
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 195)
                    .onChange(of: engine.kanjiLookupStrokeCount) { _, _ in
                        engine.runKanjiLookup()
                    }

                    Picker("Tolerance", selection: $engine.kanjiLookupStrokeTolerance) {
                        Text("Exact").tag(0)
                        Text("±1 Stroke").tag(1)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 165)
                    .onChange(of: engine.kanjiLookupStrokeTolerance) { _, _ in
                        engine.runKanjiLookup()
                    }

                    Picker("Level", selection: $engine.kanjiLookupLevelFilter) {
                        Text("All Kanji").tag(0)
                        Text("Jōyō").tag(1)
                        Text("Grade 1–6").tag(2)
                        Text("JLPT").tag(3)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 270)
                    .onChange(of: engine.kanjiLookupLevelFilter) { _, _ in
                        engine.runKanjiLookup()
                    }

                    Spacer()
                }

                // Quick-tap 1..24 Stroke Bar (Canon Wordtank style)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 15), spacing: 5) {
                    ForEach(1...30, id: \.self) { count in
                        let selected = engine.kanjiLookupStrokeCount == count
                        Button {
                            engine.kanjiLookupStrokeCount = count
                            engine.runKanjiLookup()
                        } label: {
                            Text("\(count)")
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 26)
                                .background(selected ? Color.cyan.opacity(0.42) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(selected ? Color.cyan : Color.clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

        case .reading:
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "character.ja")
                        .foregroundStyle(.cyan)
                    TextField("Type On/Kun reading in kana or romaji (e.g., den, takara, こう)...", text: $engine.kanjiLookupReadingQuery)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .onChange(of: engine.kanjiLookupReadingQuery) { _, _ in
                            engine.runKanjiLookup()
                        }
                    if !engine.kanjiLookupReadingQuery.isEmpty {
                        Text("→ \(KanaNormalizer.romajiToHiragana(engine.kanjiLookupReadingQuery))")
                            .font(.caption.bold())
                            .foregroundStyle(.cyan)
                        Button {
                            engine.kanjiLookupReadingQuery = ""
                            engine.runKanjiLookup()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

                Picker("Scope", selection: $engine.kanjiLookupReadingScope) {
                    Text("All Readings").tag(0)
                    Text("On'yomi (音)").tag(1)
                    Text("Kun'yomi (訓)").tag(2)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 265)
                .onChange(of: engine.kanjiLookupReadingScope) { _, _ in
                    engine.runKanjiLookup()
                }

                Toggle("Exact", isOn: $engine.kanjiLookupReadingExact)
                    .toggleStyle(.button)
                    .onChange(of: engine.kanjiLookupReadingExact) { _, _ in
                        engine.runKanjiLookup()
                    }
            }

        case .skip:
            HStack(spacing: 14) {
                HStack(spacing: 6) {
                    ForEach(skipPatterns, id: \.id) { pat in
                        let active = engine.kanjiLookupSkipPattern == pat.id
                        Button {
                            engine.kanjiLookupSkipPattern = pat.id
                            engine.runKanjiLookup()
                        } label: {
                            HStack(spacing: 5) {
                                Text(pat.icon)
                                    .font(.headline)
                                Text("\(pat.id): \(pat.title)")
                                    .font(.caption.bold())
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(active ? Color.cyan.opacity(0.38) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(active ? Color.cyan : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Stepper(
                    "Part 1: \(engine.kanjiLookupSkipPart1 == 0 ? "Any" : "\(engine.kanjiLookupSkipPart1)")",
                    value: $engine.kanjiLookupSkipPart1,
                    in: 0...25
                )
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 145)
                .onChange(of: engine.kanjiLookupSkipPart1) { _, _ in
                    engine.runKanjiLookup()
                }

                Stepper(
                    "Part 2: \(engine.kanjiLookupSkipPart2 == 0 ? "Any" : "\(engine.kanjiLookupSkipPart2)")",
                    value: $engine.kanjiLookupSkipPart2,
                    in: 0...25
                )
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 145)
                .onChange(of: engine.kanjiLookupSkipPart2) { _, _ in
                    engine.runKanjiLookup()
                }

                Spacer()
            }

        case .fourCorner:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.grid.2x2")
                            .foregroundStyle(.cyan)
                        TextField("Enter 1 to 4 corner digits (0–9)...", text: $engine.kanjiLookupFourCorner)
                            .textFieldStyle(.plain)
                            .font(.body.monospaced())
                            .foregroundStyle(.white)
                            .onChange(of: engine.kanjiLookupFourCorner) { _, _ in
                                engine.runKanjiLookup()
                            }
                        if !engine.kanjiLookupFourCorner.isEmpty {
                            Button {
                                engine.kanjiLookupFourCorner = ""
                                engine.runKanjiLookup()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(width: 280)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

                    ForEach(fourCornerLegend, id: \.digit) { item in
                        Button {
                            if engine.kanjiLookupFourCorner.filter(\.isNumber).count < 4 {
                                engine.kanjiLookupFourCorner.append(item.digit)
                                engine.runKanjiLookup()
                            }
                        } label: {
                            VStack(spacing: 1) {
                                Text("\(item.digit) \(item.glyph)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                Text(item.label)
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(.white.opacity(0.65))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

        case .gradeJlpt:
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                ForEach(gradeOptions, id: \.tag) { opt in
                    let active = engine.kanjiLookupGradeFilter == opt.tag
                    Button {
                        engine.kanjiLookupGradeFilter = opt.tag
                        engine.runKanjiLookup()
                    } label: {
                        Text(opt.label)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 30)
                            .background(active ? Color.cyan.opacity(0.38) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(active ? Color.cyan : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

        case .meaning:
            HStack(spacing: 8) {
                Image(systemName: "text.magnifyingglass")
                    .foregroundStyle(.cyan)
                TextField("Search English meaning (e.g., treasure, lightning, dragon, peace)...", text: $engine.kanjiLookupMeaningQuery)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .onChange(of: engine.kanjiLookupMeaningQuery) { _, _ in
                        engine.runKanjiLookup()
                    }
                if !engine.kanjiLookupMeaningQuery.isEmpty {
                    Button {
                        engine.kanjiLookupMeaningQuery = ""
                        engine.runKanjiLookup()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private func kanjiResultTile(_ item: KanjiIndexItem) -> some View {
        Button {
            engine.openKanjiDetail(codepoint: item.codepoint, recordHistory: true)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(item.glyph)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(item.strokes)画")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.18), in: Capsule())

                        if !item.gradeLabel.isEmpty || !item.jlptLabel.isEmpty {
                            Text([item.gradeLabel, item.jlptLabel].filter { !$0.isEmpty }.joined(separator: " • "))
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.75))
                        }

                        if item.freqRank < 999_999 {
                            Text("#\(item.freqRank)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.52))
                        }
                    }
                }

                if engine.recallMode != .hideKana && !item.primaryReading.isEmpty {
                    Text(item.primaryReading)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.45, green: 0.88, blue: 1.0))
                        .lineLimit(1)
                }

                if engine.recallMode != .hideGloss {
                    Text(item.meanings.isEmpty ? "—" : item.meanings)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.84))
                        .lineLimit(1)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.11), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open Kanji Details & Strokes") {
                engine.openKanjiDetail(codepoint: item.codepoint, recordHistory: true)
            }
            Button("Open in Dokusha Fisheye Explorer") {
                engine.openFisheye(codepoint: item.codepoint, recordHistory: true)
            }
        }
        .help("\(item.glyph) (\(item.strokes) strokes) — \(item.meanings)")
    }
}

// MARK: - Complete Screen Preview Renderer for 3D History Deck Cards

struct HistorySnapshotScreenView: View {
    let item: NavBreadcrumb
    let snapshot: HistorySnapshot?
    @ObservedObject var engine: DaiJishowEngine

    var body: some View {
        switch snapshot {
        case .wordEntry(let entry):
            WordDetailContentView(entry: entry, engine: engine)
        case .kanjiDetail(let kanji):
            KanjiDetailContentView(kanji: kanji, engine: engine)
        case .fisheye(let kanji, let nodes, let leftOverflow, let rightOverflow):
            FisheyePreviewCardView(
                kanji: kanji,
                nodes: nodes,
                leftOverflow: leftOverflow,
                rightOverflow: rightOverflow,
                showPercentages: engine.showFisheyePercentages
            )
        case .radicalBuilder(let selectedIds, let targetStrokes, let matches):
            RadicalBuilderPreviewView(selectedIds: selectedIds, targetStrokes: targetStrokes, matches: matches)
        case .kanjiLookup(let mode, let strokeCount, let sortOrder, let results):
            KanjiLookupPreviewView(mode: mode, strokeCount: strokeCount, sortOrder: sortOrder, results: results)
        case nil:
            VStack(spacing: 10) {
                Text(item.label)
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(.white)
                Text(item.subtitle)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct FisheyePreviewCardView: View {
    let kanji: KanjiDetail
    let nodes: [FisheyeNode]
    let leftOverflow: Int
    let rightOverflow: Int
    let showPercentages: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Text(kanji.glyph)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 3) {
                    Text(kanji.meanings.isEmpty ? kanji.unicodeBlockLabel : kanji.meanings)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("On: \(kanji.onReadings.isEmpty ? "—" : kanji.onReadings.joined(separator: "・"))   Kun: \(kanji.kunReadings.isEmpty ? "—" : kanji.kunReadings.joined(separator: "・"))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
                Spacer()
                FisheyeLegendBar()
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)

            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let halfW = max(1.0, geo.size.width / 2)
                let halfH = max(1.0, geo.size.height / 2)

                ZStack {
                    HStack {
                        Text("← PREFIX + CENTER")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.55))
                        Spacer()
                        Text("CENTER + SUFFIX →")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(.horizontal, 24)
                    .frame(maxHeight: .infinity, alignment: .top)

                    Path { p in
                        p.move(to: CGPoint(x: center.x, y: 24))
                        p.addLine(to: CGPoint(x: center.x, y: geo.size.height - 24))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                    .foregroundStyle(.white.opacity(0.10))

                    Canvas { ctx, _ in
                        for node in nodes {
                            let pt = CGPoint(x: center.x + node.normX * halfW, y: center.y + node.normY * halfH)
                            var path = Path()
                            path.move(to: center)
                            path.addLine(to: pt)
                            ctx.stroke(
                                path,
                                with: .color(node.tierColor.opacity(0.26 * node.opacity)),
                                lineWidth: 1.2
                            )
                        }
                    }

                    ForEach(nodes) { node in
                        let pos = CGPoint(x: center.x + node.normX * halfW, y: center.y + node.normY * halfH)
                        FisheyeBubbleView(
                            node: node,
                            showPercentages: showPercentages,
                            isSelected: false,
                            isHovered: false,
                            dimmed: false,
                            onTap: {}
                        )
                        .position(pos)
                    }

                    if leftOverflow > 0 {
                        VStack(spacing: 1) {
                            Text("+\(leftOverflow)").font(.caption.bold()).foregroundStyle(.white)
                            Text("more").font(.system(size: 9)).foregroundStyle(.white.opacity(0.75))
                        }
                        .frame(width: 48, height: 48)
                        .background(Color.white.opacity(0.09), in: Circle())
                        .overlay(Circle().strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [3, 3])).foregroundStyle(.cyan.opacity(0.8)))
                        .position(x: 54, y: geo.size.height - 46)
                    }

                    if rightOverflow > 0 {
                        VStack(spacing: 1) {
                            Text("+\(rightOverflow)").font(.caption.bold()).foregroundStyle(.white)
                            Text("more").font(.system(size: 9)).foregroundStyle(.white.opacity(0.75))
                        }
                        .frame(width: 48, height: 48)
                        .background(Color.white.opacity(0.09), in: Circle())
                        .overlay(Circle().strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [3, 3])).foregroundStyle(.cyan.opacity(0.8)))
                        .position(x: geo.size.width - 54, y: geo.size.height - 46)
                    }

                    Text(kanji.glyph)
                        .font(.system(size: 54, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 92, height: 92)
                        .background(Color(red: 0.12, green: 0.17, blue: 0.25), in: Circle())
                        .overlay(Circle().strokeBorder(.cyan.opacity(0.85), lineWidth: 2.5))
                        .shadow(color: .cyan.opacity(0.3), radius: 18)
                        .position(center)
                }
            }
            .padding(.bottom, 12)
        }
    }
}

private struct RadicalBuilderPreviewView: View {
    let selectedIds: [UInt8]
    let targetStrokes: Int
    let matches: [UInt32]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("7-Slot Multi-Radical Intersection")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text("Strokes: \(targetStrokes == 0 ? "Any" : "\(targetStrokes)")")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }

            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { slot in
                    let radId = slot < selectedIds.count ? selectedIds[slot] : nil
                    let glyph = radId.map { RadicalCatalog.glyph(for: $0) } ?? "—"
                    Text(glyph)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(radId != nil ? Color.cyan.opacity(0.32) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 12), spacing: 6) {
                ForEach(RadicalCatalog.commonRadicals) { rad in
                    let active = selectedIds.contains(rad.id)
                    Text(rad.glyph)
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(active ? Color.cyan.opacity(0.38) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
            }

            Divider().overlay(Color.white.opacity(0.18))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 10), spacing: 8) {
                ForEach(matches.prefix(30), id: \.self) { cp in
                    let glyph = String(UnicodeScalar(cp)!)
                    Text(glyph)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            Spacer()
        }
        .padding(20)
    }
}

private struct KanjiLookupPreviewView: View {
    let mode: KanjiLookupMode
    let strokeCount: Int
    let sortOrder: KanjiSortOrder
    let results: [KanjiIndexItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Kanji Index — \(mode.rawValue)")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text("Sorted by \(sortOrder.rawValue)")
                    .font(.subheadline)
                    .foregroundStyle(.cyan)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                ForEach(results.prefix(24)) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.glyph)
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(item.strokes)画")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.cyan)
                        }
                        Text(item.meanings)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            Spacer()
        }
        .padding(20)
    }
}
