//
//  RadicalMeta.swift
//  DaiJishow
//
//  Created by Nigel on 2026-11-17.
//


import Foundation

struct RadicalMeta: Identifiable, Hashable {
    let id: UInt8
    let glyph: String
    let strokes: Int
    let name: String
    let variants: String
}

enum RadicalCatalog {
    static let all: [RadicalMeta] = [
        // 1 Stroke (1–6)
        RadicalMeta(id: 1, glyph: "一", strokes: 1, name: "one", variants: ""),
        RadicalMeta(id: 2, glyph: "丨", strokes: 1, name: "line", variants: ""),
        RadicalMeta(id: 3, glyph: "丶", strokes: 1, name: "dot", variants: ""),
        RadicalMeta(id: 4, glyph: "丿", strokes: 1, name: "slash", variants: ""),
        RadicalMeta(id: 5, glyph: "乙", strokes: 1, name: "second", variants: "乚⺄"),
        RadicalMeta(id: 6, glyph: "亅", strokes: 1, name: "hook", variants: ""),

        // 2 Strokes (7–29)
        RadicalMeta(id: 7, glyph: "二", strokes: 2, name: "two", variants: ""),
        RadicalMeta(id: 8, glyph: "亠", strokes: 2, name: "lid", variants: ""),
        RadicalMeta(id: 9, glyph: "人", strokes: 2, name: "person", variants: "亻𠆢"),
        RadicalMeta(id: 10, glyph: "儿", strokes: 2, name: "legs", variants: ""),
        RadicalMeta(id: 11, glyph: "入", strokes: 2, name: "enter", variants: ""),
        RadicalMeta(id: 12, glyph: "八", strokes: 2, name: "eight", variants: "丷"),
        RadicalMeta(id: 13, glyph: "冂", strokes: 2, name: "down box", variants: ""),
        RadicalMeta(id: 14, glyph: "冖", strokes: 2, name: "cover", variants: ""),
        RadicalMeta(id: 15, glyph: "冫", strokes: 2, name: "ice", variants: ""),
        RadicalMeta(id: 16, glyph: "几", strokes: 2, name: "table", variants: ""),
        RadicalMeta(id: 17, glyph: "凵", strokes: 2, name: "open box", variants: ""),
        RadicalMeta(id: 18, glyph: "刀", strokes: 2, name: "knife", variants: "刂⺈"),
        RadicalMeta(id: 19, glyph: "力", strokes: 2, name: "power", variants: ""),
        RadicalMeta(id: 20, glyph: "勹", strokes: 2, name: "wrap", variants: ""),
        RadicalMeta(id: 21, glyph: "匕", strokes: 2, name: "spoon", variants: ""),
        RadicalMeta(id: 22, glyph: "匚", strokes: 2, name: "right box", variants: ""),
        RadicalMeta(id: 23, glyph: "匸", strokes: 2, name: "hiding", variants: ""),
        RadicalMeta(id: 24, glyph: "十", strokes: 2, name: "ten", variants: ""),
        RadicalMeta(id: 25, glyph: "卜", strokes: 2, name: "divination", variants: ""),
        RadicalMeta(id: 26, glyph: "卩", strokes: 2, name: "seal", variants: "㔾"),
        RadicalMeta(id: 27, glyph: "厂", strokes: 2, name: "cliff", variants: ""),
        RadicalMeta(id: 28, glyph: "厶", strokes: 2, name: "private", variants: ""),
        RadicalMeta(id: 29, glyph: "又", strokes: 2, name: "again", variants: ""),

        // 3 Strokes (30–60)
        RadicalMeta(id: 30, glyph: "口", strokes: 3, name: "mouth", variants: ""),
        RadicalMeta(id: 31, glyph: "囗", strokes: 3, name: "enclosure", variants: ""),
        RadicalMeta(id: 32, glyph: "土", strokes: 3, name: "earth", variants: ""),
        RadicalMeta(id: 33, glyph: "士", strokes: 3, name: "scholar", variants: ""),
        RadicalMeta(id: 34, glyph: "夂", strokes: 3, name: "go", variants: ""),
        RadicalMeta(id: 35, glyph: "夊", strokes: 3, name: "go slowly", variants: ""),
        RadicalMeta(id: 36, glyph: "夕", strokes: 3, name: "evening", variants: ""),
        RadicalMeta(id: 37, glyph: "大", strokes: 3, name: "big", variants: ""),
        RadicalMeta(id: 38, glyph: "女", strokes: 3, name: "woman", variants: ""),
        RadicalMeta(id: 39, glyph: "子", strokes: 3, name: "child", variants: ""),
        RadicalMeta(id: 40, glyph: "宀", strokes: 3, name: "roof", variants: ""),
        RadicalMeta(id: 41, glyph: "寸", strokes: 3, name: "inch", variants: ""),
        RadicalMeta(id: 42, glyph: "小", strokes: 3, name: "small", variants: "⺌⺍"),
        RadicalMeta(id: 43, glyph: "尢", strokes: 3, name: "lame", variants: "尣"),
        RadicalMeta(id: 44, glyph: "尸", strokes: 3, name: "corpse", variants: ""),
        RadicalMeta(id: 45, glyph: "屮", strokes: 3, name: "sprout", variants: ""),
        RadicalMeta(id: 46, glyph: "山", strokes: 3, name: "mountain", variants: ""),
        RadicalMeta(id: 47, glyph: "巛", strokes: 3, name: "river", variants: "川"),
        RadicalMeta(id: 48, glyph: "工", strokes: 3, name: "work", variants: ""),
        RadicalMeta(id: 49, glyph: "己", strokes: 3, name: "oneself", variants: "已巳"),
        RadicalMeta(id: 50, glyph: "巾", strokes: 3, name: "turban", variants: ""),
        RadicalMeta(id: 51, glyph: "干", strokes: 3, name: "dry", variants: ""),
        RadicalMeta(id: 52, glyph: "幺", strokes: 3, name: "short thread", variants: ""),
        RadicalMeta(id: 53, glyph: "广", strokes: 3, name: "dotted cliff", variants: ""),
        RadicalMeta(id: 54, glyph: "廴", strokes: 3, name: "long stride", variants: ""),
        RadicalMeta(id: 55, glyph: "廾", strokes: 3, name: "two hands", variants: ""),
        RadicalMeta(id: 56, glyph: "弋", strokes: 3, name: "shoot", variants: ""),
        RadicalMeta(id: 57, glyph: "弓", strokes: 3, name: "bow", variants: ""),
        RadicalMeta(id: 58, glyph: "彐", strokes: 3, name: "snout", variants: "彑"),
        RadicalMeta(id: 59, glyph: "彡", strokes: 3, name: "bristle", variants: ""),
        RadicalMeta(id: 60, glyph: "彳", strokes: 3, name: "step", variants: ""),

        // 4 Strokes (61–94)
        RadicalMeta(id: 61, glyph: "心", strokes: 4, name: "heart", variants: "忄⺗"),
        RadicalMeta(id: 62, glyph: "戈", strokes: 4, name: "halberd", variants: ""),
        RadicalMeta(id: 63, glyph: "戶", strokes: 4, name: "door", variants: "戸户"),
        RadicalMeta(id: 64, glyph: "手", strokes: 4, name: "hand", variants: "扌龵"),
        RadicalMeta(id: 65, glyph: "支", strokes: 4, name: "branch", variants: ""),
        RadicalMeta(id: 66, glyph: "攴", strokes: 4, name: "rap", variants: "攵"),
        RadicalMeta(id: 67, glyph: "文", strokes: 4, name: "script", variants: ""),
        RadicalMeta(id: 68, glyph: "斗", strokes: 4, name: "dipper", variants: ""),
        RadicalMeta(id: 69, glyph: "斤", strokes: 4, name: "axe", variants: ""),
        RadicalMeta(id: 70, glyph: "方", strokes: 4, name: "square", variants: ""),
        RadicalMeta(id: 71, glyph: "无", strokes: 4, name: "not", variants: "旡"),
        RadicalMeta(id: 72, glyph: "日", strokes: 4, name: "sun", variants: ""),
        RadicalMeta(id: 73, glyph: "曰", strokes: 4, name: "say", variants: ""),
        RadicalMeta(id: 74, glyph: "月", strokes: 4, name: "moon", variants: ""),
        RadicalMeta(id: 75, glyph: "木", strokes: 4, name: "tree", variants: ""),
        RadicalMeta(id: 76, glyph: "欠", strokes: 4, name: "lack", variants: ""),
        RadicalMeta(id: 77, glyph: "止", strokes: 4, name: "stop", variants: ""),
        RadicalMeta(id: 78, glyph: "歹", strokes: 4, name: "death", variants: "歺"),
        RadicalMeta(id: 79, glyph: "殳", strokes: 4, name: "weapon", variants: ""),
        RadicalMeta(id: 80, glyph: "毋", strokes: 4, name: "do not", variants: "母"),
        RadicalMeta(id: 81, glyph: "比", strokes: 4, name: "compare", variants: ""),
        RadicalMeta(id: 82, glyph: "毛", strokes: 4, name: "fur", variants: ""),
        RadicalMeta(id: 83, glyph: "氏", strokes: 4, name: "clan", variants: ""),
        RadicalMeta(id: 84, glyph: "气", strokes: 4, name: "steam", variants: ""),
        RadicalMeta(id: 85, glyph: "水", strokes: 4, name: "water", variants: "氵氺"),
        RadicalMeta(id: 86, glyph: "火", strokes: 4, name: "fire", variants: "灬"),
        RadicalMeta(id: 87, glyph: "爪", strokes: 4, name: "claw", variants: "爫"),
        RadicalMeta(id: 88, glyph: "父", strokes: 4, name: "father", variants: ""),
        RadicalMeta(id: 89, glyph: "爻", strokes: 4, name: "double x", variants: ""),
        RadicalMeta(id: 90, glyph: "爿", strokes: 4, name: "split wood", variants: "丬"),
        RadicalMeta(id: 91, glyph: "片", strokes: 4, name: "slice", variants: ""),
        RadicalMeta(id: 92, glyph: "牙", strokes: 4, name: "fang", variants: ""),
        RadicalMeta(id: 93, glyph: "牛", strokes: 4, name: "cow", variants: "牜⺧"),
        RadicalMeta(id: 94, glyph: "犬", strokes: 4, name: "dog", variants: "犭"),

        // 5 Strokes (95–117)
        RadicalMeta(id: 95, glyph: "玄", strokes: 5, name: "profound", variants: ""),
        RadicalMeta(id: 96, glyph: "玉", strokes: 5, name: "jade", variants: "王⺩"),
        RadicalMeta(id: 97, glyph: "瓜", strokes: 5, name: "melon", variants: ""),
        RadicalMeta(id: 98, glyph: "瓦", strokes: 5, name: "tile", variants: ""),
        RadicalMeta(id: 99, glyph: "甘", strokes: 5, name: "sweet", variants: ""),
        RadicalMeta(id: 100, glyph: "生", strokes: 5, name: "life", variants: ""),
        RadicalMeta(id: 101, glyph: "用", strokes: 5, name: "use", variants: ""),
        RadicalMeta(id: 102, glyph: "田", strokes: 5, name: "field", variants: ""),
        RadicalMeta(id: 103, glyph: "疋", strokes: 5, name: "cloth", variants: "⺪"),
        RadicalMeta(id: 104, glyph: "疒", strokes: 5, name: "sickness", variants: ""),
        RadicalMeta(id: 105, glyph: "癶", strokes: 5, name: "footsteps", variants: ""),
        RadicalMeta(id: 106, glyph: "白", strokes: 5, name: "white", variants: ""),
        RadicalMeta(id: 107, glyph: "皮", strokes: 5, name: "skin", variants: ""),
        RadicalMeta(id: 108, glyph: "皿", strokes: 5, name: "dish", variants: ""),
        RadicalMeta(id: 109, glyph: "目", strokes: 5, name: "eye", variants: "罒"),
        RadicalMeta(id: 110, glyph: "矛", strokes: 5, name: "spear", variants: ""),
        RadicalMeta(id: 111, glyph: "矢", strokes: 5, name: "arrow", variants: ""),
        RadicalMeta(id: 112, glyph: "石", strokes: 5, name: "stone", variants: ""),
        RadicalMeta(id: 113, glyph: "示", strokes: 5, name: "spirit", variants: "礻"),
        RadicalMeta(id: 114, glyph: "禸", strokes: 5, name: "track", variants: ""),
        RadicalMeta(id: 115, glyph: "禾", strokes: 5, name: "grain", variants: ""),
        RadicalMeta(id: 116, glyph: "穴", strokes: 5, name: "cave", variants: ""),
        RadicalMeta(id: 117, glyph: "立", strokes: 5, name: "stand", variants: ""),

        // 6 Strokes (118–146)
        RadicalMeta(id: 118, glyph: "竹", strokes: 6, name: "bamboo", variants: "⺮"),
        RadicalMeta(id: 119, glyph: "米", strokes: 6, name: "rice", variants: ""),
        RadicalMeta(id: 120, glyph: "糸", strokes: 6, name: "silk", variants: "糹纟"),
        RadicalMeta(id: 121, glyph: "缶", strokes: 6, name: "jar", variants: ""),
        RadicalMeta(id: 122, glyph: "网", strokes: 6, name: "net", variants: "罒⺲罓⺳"),
        RadicalMeta(id: 123, glyph: "羊", strokes: 6, name: "sheep", variants: "⺶⺷"),
        RadicalMeta(id: 124, glyph: "羽", strokes: 6, name: "feather", variants: ""),
        RadicalMeta(id: 125, glyph: "老", strokes: 6, name: "old", variants: "耂"),
        RadicalMeta(id: 126, glyph: "而", strokes: 6, name: "and", variants: ""),
        RadicalMeta(id: 127, glyph: "耒", strokes: 6, name: "plow", variants: ""),
        RadicalMeta(id: 128, glyph: "耳", strokes: 6, name: "ear", variants: ""),
        RadicalMeta(id: 129, glyph: "聿", strokes: 6, name: "brush", variants: "⺻"),
        RadicalMeta(id: 130, glyph: "肉", strokes: 6, name: "meat", variants: "月"),
        RadicalMeta(id: 131, glyph: "臣", strokes: 6, name: "minister", variants: ""),
        RadicalMeta(id: 132, glyph: "自", strokes: 6, name: "self", variants: ""),
        RadicalMeta(id: 133, glyph: "至", strokes: 6, name: "arrive", variants: ""),
        RadicalMeta(id: 134, glyph: "臼", strokes: 6, name: "mortar", variants: ""),
        RadicalMeta(id: 135, glyph: "舌", strokes: 6, name: "tongue", variants: ""),
        RadicalMeta(id: 136, glyph: "舛", strokes: 6, name: "oppose", variants: ""),
        RadicalMeta(id: 137, glyph: "舟", strokes: 6, name: "boat", variants: ""),
        RadicalMeta(id: 138, glyph: "艮", strokes: 6, name: "stopping", variants: ""),
        RadicalMeta(id: 139, glyph: "色", strokes: 6, name: "color", variants: ""),
        RadicalMeta(id: 140, glyph: "艸", strokes: 6, name: "grass", variants: "艹"),
        RadicalMeta(id: 141, glyph: "虍", strokes: 6, name: "tiger", variants: ""),
        RadicalMeta(id: 142, glyph: "虫", strokes: 6, name: "insect", variants: ""),
        RadicalMeta(id: 143, glyph: "血", strokes: 6, name: "blood", variants: ""),
        RadicalMeta(id: 144, glyph: "行", strokes: 6, name: "walk", variants: ""),
        RadicalMeta(id: 145, glyph: "衣", strokes: 6, name: "clothes", variants: "衤"),
        RadicalMeta(id: 146, glyph: "襾", strokes: 6, name: "west", variants: "西覀"),

        // 7 Strokes (147–166)
        RadicalMeta(id: 147, glyph: "見", strokes: 7, name: "see", variants: "见"),
        RadicalMeta(id: 148, glyph: "角", strokes: 7, name: "horn", variants: ""),
        RadicalMeta(id: 149, glyph: "言", strokes: 7, name: "speech", variants: "訁讠"),
        RadicalMeta(id: 150, glyph: "谷", strokes: 7, name: "valley", variants: ""),
        RadicalMeta(id: 151, glyph: "豆", strokes: 7, name: "bean", variants: ""),
        RadicalMeta(id: 152, glyph: "豕", strokes: 7, name: "pig", variants: ""),
        RadicalMeta(id: 153, glyph: "豸", strokes: 7, name: "badger", variants: ""),
        RadicalMeta(id: 154, glyph: "貝", strokes: 7, name: "shell", variants: "贝"),
        RadicalMeta(id: 155, glyph: "赤", strokes: 7, name: "red", variants: ""),
        RadicalMeta(id: 156, glyph: "走", strokes: 7, name: "run", variants: ""),
        RadicalMeta(id: 157, glyph: "足", strokes: 7, name: "foot", variants: "⻊"),
        RadicalMeta(id: 158, glyph: "身", strokes: 7, name: "body", variants: ""),
        RadicalMeta(id: 159, glyph: "車", strokes: 7, name: "cart", variants: "车"),
        RadicalMeta(id: 160, glyph: "辛", strokes: 7, name: "bitter", variants: ""),
        RadicalMeta(id: 161, glyph: "辰", strokes: 7, name: "morning", variants: ""),
        RadicalMeta(id: 162, glyph: "辵", strokes: 7, name: "walk", variants: "辶⻌⻍"),
        RadicalMeta(id: 163, glyph: "邑", strokes: 7, name: "city", variants: "阝"),
        RadicalMeta(id: 164, glyph: "酉", strokes: 7, name: "wine", variants: ""),
        RadicalMeta(id: 165, glyph: "釆", strokes: 7, name: "distinguish", variants: ""),
        RadicalMeta(id: 166, glyph: "里", strokes: 7, name: "village", variants: ""),

        // 8 Strokes (167–175)
        RadicalMeta(id: 167, glyph: "金", strokes: 8, name: "gold", variants: "釒钅"),
        RadicalMeta(id: 168, glyph: "長", strokes: 8, name: "long", variants: "镸长"),
        RadicalMeta(id: 169, glyph: "門", strokes: 8, name: "gate", variants: "门"),
        RadicalMeta(id: 170, glyph: "阜", strokes: 8, name: "mound", variants: "阝"),
        RadicalMeta(id: 171, glyph: "隶", strokes: 8, name: "slave", variants: ""),
        RadicalMeta(id: 172, glyph: "隹", strokes: 8, name: "short bird", variants: ""),
        RadicalMeta(id: 173, glyph: "雨", strokes: 8, name: "rain", variants: "⻗"),
        RadicalMeta(id: 174, glyph: "靑", strokes: 8, name: "blue", variants: "青"),
        RadicalMeta(id: 175, glyph: "非", strokes: 8, name: "wrong", variants: ""),

        // 9 Strokes (176–186)
        RadicalMeta(id: 176, glyph: "面", strokes: 9, name: "face", variants: "靣"),
        RadicalMeta(id: 177, glyph: "革", strokes: 9, name: "leather", variants: ""),
        RadicalMeta(id: 178, glyph: "韋", strokes: 9, name: "tanned leather", variants: "韦"),
        RadicalMeta(id: 179, glyph: "韭", strokes: 9, name: "leek", variants: ""),
        RadicalMeta(id: 180, glyph: "音", strokes: 9, name: "sound", variants: ""),
        RadicalMeta(id: 181, glyph: "頁", strokes: 9, name: "leaf", variants: "页"),
        RadicalMeta(id: 182, glyph: "風", strokes: 9, name: "wind", variants: "风"),
        RadicalMeta(id: 183, glyph: "飛", strokes: 9, name: "fly", variants: "飞"),
        RadicalMeta(id: 184, glyph: "食", strokes: 9, name: "eat", variants: "飠饣"),
        RadicalMeta(id: 185, glyph: "首", strokes: 9, name: "head", variants: ""),
        RadicalMeta(id: 186, glyph: "香", strokes: 9, name: "fragrant", variants: ""),

        // 10 Strokes (187–194)
        RadicalMeta(id: 187, glyph: "馬", strokes: 10, name: "horse", variants: "马"),
        RadicalMeta(id: 188, glyph: "骨", strokes: 10, name: "bone", variants: ""),
        RadicalMeta(id: 189, glyph: "高", strokes: 10, name: "tall", variants: "髙"),
        RadicalMeta(id: 190, glyph: "髟", strokes: 10, name: "hair", variants: ""),
        RadicalMeta(id: 191, glyph: "鬥", strokes: 10, name: "fight", variants: ""),
        RadicalMeta(id: 192, glyph: "鬯", strokes: 10, name: "sacrificial wine", variants: ""),
        RadicalMeta(id: 193, glyph: "鬲", strokes: 10, name: "cauldron", variants: ""),
        RadicalMeta(id: 194, glyph: "鬼", strokes: 10, name: "ghost", variants: ""),

        // 11 Strokes (195–200)
        RadicalMeta(id: 195, glyph: "魚", strokes: 11, name: "fish", variants: "鱼"),
        RadicalMeta(id: 196, glyph: "鳥", strokes: 11, name: "bird", variants: "鸟"),
        RadicalMeta(id: 197, glyph: "鹵", strokes: 11, name: "salt", variants: "卤"),
        RadicalMeta(id: 198, glyph: "鹿", strokes: 11, name: "deer", variants: ""),
        RadicalMeta(id: 199, glyph: "麥", strokes: 11, name: "wheat", variants: "麦"),
        RadicalMeta(id: 200, glyph: "麻", strokes: 11, name: "hemp", variants: ""),

        // 12 Strokes (201–204)
        RadicalMeta(id: 201, glyph: "黃", strokes: 12, name: "yellow", variants: "黄"),
        RadicalMeta(id: 202, glyph: "黍", strokes: 12, name: "millet", variants: ""),
        RadicalMeta(id: 203, glyph: "黑", strokes: 12, name: "black", variants: "黒"),
        RadicalMeta(id: 204, glyph: "黹", strokes: 12, name: "embroidery", variants: ""),

        // 13 Strokes (205–208)
        RadicalMeta(id: 205, glyph: "黽", strokes: 13, name: "frog", variants: "黾"),
        RadicalMeta(id: 206, glyph: "鼎", strokes: 13, name: "tripod", variants: ""),
        RadicalMeta(id: 207, glyph: "鼓", strokes: 13, name: "drum", variants: ""),
        RadicalMeta(id: 208, glyph: "鼠", strokes: 13, name: "rat", variants: ""),

        // 14 Strokes (209–210)
        RadicalMeta(id: 209, glyph: "鼻", strokes: 14, name: "nose", variants: ""),
        RadicalMeta(id: 210, glyph: "齊", strokes: 14, name: "even", variants: "斉齐"),

        // 15 Strokes (211)
        RadicalMeta(id: 211, glyph: "齒", strokes: 15, name: "tooth", variants: "歯齿"),

        // 16 Strokes (212–213)
        RadicalMeta(id: 212, glyph: "龍", strokes: 16, name: "dragon", variants: "竜龙"),
        RadicalMeta(id: 213, glyph: "龜", strokes: 16, name: "turtle", variants: "亀龟"),

        // 17 Strokes (214)
        RadicalMeta(id: 214, glyph: "龠", strokes: 17, name: "flute", variants: "")
    ]

    private static let byId: [UInt8: RadicalMeta] = {
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }()

    private static let idByChar: [Character: UInt8] = {
        var map: [Character: UInt8] = [:]
        for item in all {
            if let ch = item.glyph.first {
                map[ch] = item.id
            }
            for v in item.variants where map[v] == nil {
                map[v] = item.id
            }
        }
        return map
    }()

    static func meta(for id: UInt8) -> RadicalMeta {
        byId[id] ?? RadicalMeta(id: id, glyph: "?", strokes: 0, name: "#\(id)", variants: "")
    }

    static func glyph(for id: UInt8) -> String {
        byId[id]?.glyph ?? "?"
    }

    static func parseComponentRadicalIds(_ raw: String) -> [UInt8] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var result: [UInt8] = []
        let tokens = trimmed.split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "、" || $0.isWhitespace })

        for tok in tokens {
            let s = String(tok).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            if let num = UInt8(s), (1...214).contains(num) {
                if !result.contains(num) { result.append(num) }
                continue
            }
            for ch in s {
                if let rid = idByChar[ch], !result.contains(rid) {
                    result.append(rid)
                }
            }
        }
        return result
    }
}