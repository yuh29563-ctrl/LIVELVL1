import Foundation

enum CollectibleKind: String, Codable, Sendable {
    case ordinary
    case hidden
}

enum CompanionStage: Int, Codable, CaseIterable, Sendable {
    case juvenile
    case stageTwo
    case stageThree
    case mature
}

struct CollectibleDefinition: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let kind: CollectibleKind
    let ordinaryIndex: Int?
    let symbolName: String
    let silhouetteSymbolName: String
    let summary: String
    let details: String
    let hiddenRuleID: String?
    var series: String? = nil
}

enum CollectionCatalog {
    static let ordinary: [CollectibleDefinition] = [
        CollectibleDefinition(
            id: "growth.star-vortex", name: "循星之涡", kind: .ordinary, ordinaryIndex: 0,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "走出第一步，方向便开始生长。",
            details: "在群星尚未命名的边境，一缕小小的星涡总被乱流推向陌生的地方。它曾停在原地，等待一张不会出错的地图，直到一颗微弱的尘星轻轻撞进怀里。它决定先护送这颗星，哪怕每天只能前进一点。\n\n每走过一段黑暗，它便留下一道回旋的光迹。那些曾让它迷路的碎光，渐渐汇成了自己的星环。后来，星涡长成穿越夜海的航标，开始为别的旅人引路。它依然会遇见风暴，却已经知道：下一步，也能成为方向。",
            hiddenRuleID: nil
        ),
        CollectibleDefinition(
            id: "growth.light-tree", name: "织光灵树", kind: .ordinary, ordinaryIndex: 1,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "把微小的坚持，织成可以依靠的力量。",
            details: "遗忘之森的石缝里，长出了一株细弱的灵树。这里没有长久的白昼，它便每天伸出一点新根，收集落在泥土里的星屑。赶路的人看不见变化，只有地下的细根知道，今天又比昨天多握住了一寸土地。\n\n漫长的寒季来临时，灵树没有急着长高。它把积攒的光分给每一条根须，让它们穿过坚硬的岩层。春潮终于回来，枝头亮起相连的光冠，林中的小生命也有了栖身之处。它的繁盛，来自那些无人看见、仍认真生长的日子。",
            hiddenRuleID: nil
        ),
        CollectibleDefinition(
            id: "growth.dawn-staff", name: "破晓灵杖", kind: .ordinary, ordinaryIndex: 2,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "亲手点亮那道尚未打开的门。",
            details: "一位年轻旅人在废塔里拾到半截灵杖。杖心的星火几乎熄灭，古老的咒语也无人记得。他把灵杖带在身边，每完成一个小小的约定，就替它擦去一层尘灰；每经历一次失败，就在裂纹旁系上一缕新的星丝。\n\n终于有一天，前路被巨大的夜幕封住。旅人举起灵杖，里面响起的，是一路上所有微小行动的回声。星丝连成明亮的环，杖心升起第一束晨光。他向前走去，用亲手积攒的力量，为自己打开了通往明天的路。",
            hiddenRuleID: nil
        ),
        CollectibleDefinition(
            id: "growth.binary-eclipse", name: "双星蚀", kind: .ordinary, ordinaryIndex: 3,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "允许彼此不同，也能一起发光。",
            details: "两颗年轻的星初次相遇时，总把对方的影子当作黑夜。它们争着照亮同一片海，反而一次次偏离轨道。后来，一位守夜人教它们听见彼此的脉动：一颗稍稍放慢，另一颗便有了前行的空隙。\n\n漫长的环行之后，两颗星终于学会相伴。交叠的阴影边缘升起明亮的光环，曾经害怕夜色的旅人循着它找到了港口。它们仍各有自己的光，却能在相逢时，照亮更远的地方。",
            hiddenRuleID: nil, series: "异界天象"
        ),
        CollectibleDefinition(
            id: "growth.inverted-starfall", name: "倒悬星瀑", kind: .ordinary, ordinaryIndex: 4,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "逆流而上的每一步，都有自己的重量。",
            details: "天穹裂开以后，散落的星光一直向深渊坠去。一缕小小的星流不愿离开故乡，便沿着岩壁，一点一点向上攀。每升高一寸，都有光粒被风吹散，它就停下来，把剩下的微光重新聚拢。\n\n岁月将细流织成一道倒悬的瀑布。后来落入谷底的人抬起头，总能看见星光向天空奔去。它没有让深渊消失，却为困在其中的生命，留下了一条向上的路。",
            hiddenRuleID: nil, series: "异界天象"
        ),
        CollectibleDefinition(
            id: "growth.shattered-moon", name: "碎月", kind: .ordinary, ordinaryIndex: 5,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "裂开的地方，也能容纳新的光。",
            details: "月亮破碎的那一夜，一枚小小的残片落在荒原。它把锋利的一面藏进尘土，害怕再划伤谁。直到迷路的孩子在身旁睡着，它才发现，自己的缺口恰好能挡住夜风。\n\n此后，每遇见一枚漂泊的月片，它便邀请对方停留。残片们没有磨去各自的断痕，而是用星尘在缝隙间搭起细桥。新的月轮缓缓升空，光从一道道缝隙里洒下来，照见了荒原上最细小的归途。",
            hiddenRuleID: nil, series: "异界天象"
        ),
        CollectibleDefinition(
            id: "growth.silent-bell", name: "无声古钟", kind: .ordinary, ordinaryIndex: 6,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "认真做过的事，终会留下回响。",
            details: "废城中央有一口裂开的古钟，许多年没有发出声音。年轻的修钟人每天走上钟楼，清理一点锈迹，校准一颗松动的铆钉。路过的人问他何时才能听见钟声，他也不知道，只记得今天还有一处需要照料。\n\n一个冬夜，暴风将城门吹开。古钟第一次震动起来，声音沿着修补过的裂纹传向远方。修钟人这才看见，那些安静做完的小事，已经一件件连成了唤醒城市的力量。",
            hiddenRuleID: nil, series: "失落遗物"
        ),
        CollectibleDefinition(
            id: "growth.floating-crown", name: "悬浮王冠", kind: .ordinary, ordinaryIndex: 7,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "先学会承担，再走向属于你的位置。",
            details: "无主的王冠悬在旧宫殿里，谁越急着伸手，它便升得越高。一个替人送信的孩子误入殿中，没有追逐王冠，只把破损的窗关好，替躲雨的人点起炉火。王冠悄悄落低了一点。\n\n后来，孩子学着照顾花园、修整道路，也学会承认自己做不到的事，请伙伴一同完成。多年以后，王冠来到他肩旁，与他并肩悬浮。宫门从此向每一个需要歇脚的人敞开，那里有了比王座更长久的温度。",
            hiddenRuleID: nil, series: "失落遗物"
        ),
        CollectibleDefinition(
            id: "growth.unwritten-book", name: "无字之书", kind: .ordinary, ordinaryIndex: 8,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "让今天的行动，成为明天的一页。",
            details: "古图书馆最深处藏着一本无字之书。一个学徒翻遍空白，始终找不到能改变命运的咒语。他失望地带书离开，却在扶起一盏倒下的路灯后，看见纸上浮出了一行细小的光。\n\n从那以后，他把学会的事用在生活里，也把犯过的错认真改正。书页一张张亮起，渐渐铺成能容纳星河的长卷。他终于读懂了这本书：它一直在等他亲手写下，自己愿意成为怎样的人。",
            hiddenRuleID: nil, series: "失落遗物"
        ),
        CollectibleDefinition(
            id: "growth.endless-stairway", name: "无尽阶梯", kind: .ordinary, ordinaryIndex: 9,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "先站稳眼前的一级。",
            details: "云海中的阶梯没有尽头。初来的旅人仰望高处，常因看不见终点而停下。一个背着小灯的人却只照亮脚边一级：走稳了，再把灯向前挪一点。遇见摇晃的台阶，他就留下一枚石钉，提醒后来的人。\n\n许多年后，石钉连成了穿过云层的光线。旅人回望，发现自己早已越过最初害怕的高度。他仍不知道阶梯会通向哪里，却已经能带着安稳的步伐，迎接下一段风景。",
            hiddenRuleID: nil, series: "空间奇观"
        ),
        CollectibleDefinition(
            id: "growth.folded-maze", name: "折叠迷宫", kind: .ordinary, ordinaryIndex: 10,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "绕过的路，也会成为你的地图。",
            details: "这座迷宫会在每个黎明折叠墙壁，昨日的捷径，今日可能通向死角。一个小小的探路者起初不断责怪自己走错，后来开始在纸上记下风向、回声，以及哪扇门后有水。\n\n当迷宫再次翻转，他没有失去全部方向。曾经绕过的长路，教会他辨认墙缝里的微光。终于，他从一处不起眼的转角走出，又把地图送给下一位来客。纸上没有一条完美路线，却满是可以重新出发的线索。",
            hiddenRuleID: nil, series: "空间奇观"
        ),
        CollectibleDefinition(
            id: "growth.drifting-isle", name: "漂浮孤岛", kind: .ordinary, ordinaryIndex: 11,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "把根扎在心里，也能自在远行。",
            details: "一座小岛从大陆边缘升起，漂入无人标记的云海。它担心自己会永远失去归处，便拼命靠近每一片陆地，却总被气流带走。后来，岛上的园丁开始修好水渠，把种子种进每一寸能留住的泥土。\n\n小岛渐渐长出树林和清泉，漂泊的鸟也在这里筑巢。它仍然随着风远行，却能为到访的人提供一夜安稳。每当云层散开，岛上便亮起灯火，把走过的天空，变成一处处可以记住的故乡。",
            hiddenRuleID: nil, series: "空间奇观"
        ),
        CollectibleDefinition(
            id: "growth.dream-cocoon", name: "织梦之茧", kind: .ordinary, ordinaryIndex: 12,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "安静积攒，也是在向前生长。",
            details: "眠雾森林里，一只小茧每天只织出一根细丝。别的生命已经越过山谷，它还停在原来的枝头，慢慢把风声、雨滴和遥远的歌收进身体。它不知道何时才能醒来，只认真织好今天这一根。\n\n一个清晨，茧里传来轻轻的振动。积攒的细丝展开成透亮的纹路，将整片森林映进微光。它终于有力量离开枝头，也把一缕柔软的光留在原处，陪伴下一颗正在等待的梦。",
            hiddenRuleID: nil, series: "异界生命"
        ),
        CollectibleDefinition(
            id: "growth.sky-whale", name: "游空鲸影", kind: .ordinary, ordinaryIndex: 13,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "沿着自己的节奏，穿过辽阔。",
            details: "幼小的空鲸第一次离开云巢时，追不上迅疾的流星。它使劲摆动尾鳍，很快便耗尽气力，只好停在一片薄云上喘息。年长的风告诉它，天空有许多道路，也有适合缓缓游过的洋流。\n\n于是，它开始练习听风，按自己的节奏远行。日复一日，细小的鲸影长成承载星光的巨鲸。迁徙的鸟群在它身旁歇脚，它则带着从容的呼吸，游过从前以为永远无法抵达的天际。",
            hiddenRuleID: nil, series: "异界生命"
        ),
        CollectibleDefinition(
            id: "growth.crystal-butterflies", name: "晶簇蝶群", kind: .ordinary, ordinaryIndex: 14,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "一点勇气，会唤醒更多微光。",
            details: "晶洞里，第一只小蝶挣开石壳时，翅膀还带着沉重的碎晶。它只能飞起很短一段，却仍每天去洞口试一试。翅缘碰响岩壁的声音，慢慢唤醒了沉睡在深处的同伴。\n\n后来，小蝶们轮流领路，替疲惫的伙伴挡住冷风。它们将练习过无数次的短短飞行，接成穿过整座山的光带。漫长的黑暗里，从此有了一群会彼此等待的翅膀，也有了通向春天的出口。",
            hiddenRuleID: nil, series: "异界生命"
        ),
        CollectibleDefinition(
            id: "growth.reverse-clock", name: "逆行之钟", kind: .ordinary, ordinaryIndex: 15,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "回望来路，是为了更稳地向前。",
            details: "旧城的钟总向后走。修钟的学徒起初以为，只要追上倒转的指针，就能改掉所有遗憾。他沿着钟声回看过去，却只能重新看见自己曾经忽略的细节。\n\n于是，他把迟来的明白写进今天：认真道谢，及时道歉，答应的事慢慢做完。钟盘上的裂痕逐渐连成新的刻度。每当指针逆行一圈，他便更清楚，下一步想走向哪里。",
            hiddenRuleID: nil, series: "时间遗迹"
        ),
        CollectibleDefinition(
            id: "growth.yesterday-mirror", name: "昨日之镜", kind: .ordinary, ordinaryIndex: 16,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "看见过去的自己，也给今天留一点勇气。",
            details: "小镜子只映出昨日。年轻的旅人每天照见的，都是落后一步的自己。他嫌弃镜中的笨拙，直到一次大雪封路，镜子映出了他昨日留下的脚印，帮助他找到避风的山洞。\n\n此后，他开始留意那些不够完美、却确实向前的片刻。镜面渐渐展开，照见许多被遗忘的小小进步。他把镜子挂在门边，每次出发前，都向走到这里的自己轻轻点头。",
            hiddenRuleID: nil, series: "时间遗迹"
        ),
        CollectibleDefinition(
            id: "growth.unfinished-beacon", name: "未尽灯塔", kind: .ordinary, ordinaryIndex: 17,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "尚未完成，也可以先照亮一小段路。",
            details: "海角的灯塔只修到半高，守塔人总想等它完工再点灯。一个雾夜，小船在礁石间打转，他只好抱着手边的小灯，爬上尚无屋顶的平台。那点光，带回了第一位迷航的人。\n\n后来，他白天添一块石，夜里点一盏灯。塔身仍有待补的地方，海图上却已经有了它的位置。来往的船把修塔的材料捎到岸边，也把一次次平安归航，留作它继续生长的回声。",
            hiddenRuleID: nil, series: "时间遗迹"
        ),
        CollectibleDefinition(
            id: "growth.floating-crystal", name: "悬浮晶心", kind: .ordinary, ordinaryIndex: 18,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "找到心中的支点，再向高处生长。",
            details: "一枚幼小晶心被发现时，总随着旁人的愿望改变形状。有人希望它更亮，有人希望它更轻，它努力回应，裂纹却越来越多。矿师请它安静一夜，听一听自己最深处的震动。\n\n晶心终于记起，它想为幽暗的矿道照明。此后，每一束新生的晶棱都朝着同一个方向延伸。它缓缓升起，将稳定的光分给下方的人，也在喧杂的回声里，守住了自己的节律。",
            hiddenRuleID: nil, series: "异界矿藏"
        ),
        CollectibleDefinition(
            id: "growth.hollow-stone", name: "空洞原石", kind: .ordinary, ordinaryIndex: 19,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "为未知留一点空隙。",
            details: "矿洞里有块中空的石头，总被挑选宝石的人遗落。它羡慕那些沉甸甸的晶簇，便用碎屑填满自己。雨季来临时，一只湿透的小鸟找不到栖身处，它又慢慢挪开碎屑，让出腹中的空间。\n\n鸟带来了种子，雨水留下了清泉。原石的内壁渐渐长出细密的光晶，成为岩层里一座温暖的小小庭院。路过的矿工停下来，第一次认真望进它曾经想要藏起的空洞。",
            hiddenRuleID: nil, series: "异界矿藏"
        ),
        CollectibleDefinition(
            id: "growth.living-vein", name: "流动矿脉", kind: .ordinary, ordinaryIndex: 20,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "遇到坚硬之处，试着寻找新的通路。",
            details: "年轻的矿脉想笔直穿过整座山，却被一道厚重岩层挡住。它一次次冲撞，散失了许多光。直到地下水从身旁流过，它才开始沿着细小的裂缝，缓慢改变方向。\n\n那些弯曲的路径逐渐连起零散的晶石，织成山腹里明亮的河网。矿脉终于抵达另一面的泉口，也把沿途经过的暗处一并照亮。山没有变软，它却学会了带着耐心，继续流动。",
            hiddenRuleID: nil, series: "异界矿藏"
        ),
        CollectibleDefinition(
            id: "growth.doorless-tower", name: "无门之塔", kind: .ordinary, ordinaryIndex: 21,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "从能够触及的地方，开始搭建。",
            details: "梦里的高塔没有门，只有一圈圈悬在空中的檐台。一个想看日出的孩子守在塔下许久，终于把寻找入口的时间，拿来修好脚边残缺的第一层石阶。\n\n每天清晨，他再添一级，累了便坐在已经修好的地方歇息。后来，石阶绕着塔身盘旋而上，清晨的光落满了台面。他从最高处向下看，许多人正沿着那些平凡的小台阶，走来与他一同看日出。",
            hiddenRuleID: nil, series: "梦境建筑"
        ),
        CollectibleDefinition(
            id: "growth.returning-bridge", name: "回环长桥", kind: .ordinary, ordinaryIndex: 22,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "再次走过，也能走出不同的收获。",
            details: "长桥绕成一圈，走到尽头的人总会回到起点。年轻的桥匠为此沮丧，直到他发现，每次归来，桥上总有一处松动的木板，或一位需要帮助的行人。\n\n他开始在每一圈里修好一点，也记下沿途的风向。回环的桥渐渐稳固，终于托起一段通往远岸的新桥面。再次站在起点时，他带着已经学会的本领，走上了从前还不存在的道路。",
            hiddenRuleID: nil, series: "梦境建筑"
        ),
        CollectibleDefinition(
            id: "growth.inverted-sanctum", name: "倒悬神殿", kind: .ordinary, ordinaryIndex: 23,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "换一个角度，也许就能找到支撑。",
            details: "神殿悬在天空的背面，初来的修缮者总想把它拉回地上。绳索一次次断裂，他才停下来，沿着倒悬的长廊慢慢观察，发现每根石柱都朝着星光延伸。\n\n他顺着那股力量补好一处处裂隙，殿中的灯逐渐亮起。后来，人们来到这里，在倒映的大地上重新辨认自己的生活。修缮者也学会了，先看清事物站立的方式，再决定如何伸出双手。",
            hiddenRuleID: nil, series: "梦境建筑"
        ),
        CollectibleDefinition(
            id: "growth.thunder-spear", name: "凝雷之矛", kind: .ordinary, ordinaryIndex: 24,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "让四散的力量，汇向一个清晰的目标。",
            details: "雷原上的小矛收不住闪电，越是急着证明自己，光便散得越远。守原人让它对准山顶一块旧石，每天只练习一次稳定的投掷，不去追逐满天的轰鸣。\n\n风雨来过许多轮，细小的雷纹渐渐汇成明亮的矛心。后来雷暴困住了山路上的行人，它稳稳划开落石，给他们留出通道。那道准确抵达的光，来自无数次耐心收回、重新瞄准的练习。",
            hiddenRuleID: nil, series: "元素造物"
        ),
        CollectibleDefinition(
            id: "growth.tidal-bow", name: "潮汐之弓", kind: .ordinary, ordinaryIndex: 25,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "学会蓄力，也学会适时松开。",
            details: "潮汐之弓想让箭飞过最远的海，每天都绷紧弓弦，直到连浪声也听不清。一次退潮，老船匠替它卸下弦，让海风从弓身之间穿过。\n\n它开始观察涨落，在潮水回来的时候蓄力，也在平静时修整自己。后来，一支带着水光的箭越过暗礁，替困住的船送去了引路的绳。弓弦在放箭之后轻轻回弹，仍有力量，迎接下一次远行。",
            hiddenRuleID: nil, series: "元素造物"
        ),
        CollectibleDefinition(
            id: "growth.ember-shield", name: "余烬之盾", kind: .ordinary, ordinaryIndex: 26,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "守护别人时，也照看自己的火。",
            details: "小盾曾挡住一场大火，余下的火星却一直灼烧着裂口。它担心只要停下，身后的人就会受伤，于是独自守了很久。伙伴们终于发现它的疲惫，轮流来到火边，让它有机会修补边缘。\n\n慢慢地，余烬在盾心聚成温和的光。它学会在需要时迎上前，也会说出何时需要援手。寒夜里，大家围着它轮流守望，火光因此安稳地亮到了黎明。",
            hiddenRuleID: nil, series: "元素造物"
        ),
        CollectibleDefinition(
            id: "growth.broken-harp", name: "断弦竖琴", kind: .ordinary, ordinaryIndex: 27,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "从还能发声的一根弦开始。",
            details: "旧剧场的竖琴断了许多弦，常在演出前躲进幕布后。一个学琴的孩子把它搬到窗边，只练习剩下那根弦上的三个音，慢慢将它们连成一首短歌。\n\n路过的人带来新的琴弦，也带来各自熟悉的旋律。修补过的竖琴渐渐拥有了独特的音色。再次登台时，它唱出的曲子里，有那些简短练习留下的节奏，也有许多愿意认真倾听的人。",
            hiddenRuleID: nil, series: "异界乐器"
        ),
        CollectibleDefinition(
            id: "growth.echo-flute", name: "回声骨笛", kind: .ordinary, ordinaryIndex: 28,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "听见回应之前，先把自己的声音送出去。",
            details: "峡谷中的小笛总要等到回声，才相信自己吹对了音。可风一变，回应便迟迟不来。牧风人陪它坐在石边，让它先听清自己的呼吸，再稳稳吹完一段旋律。\n\n日子久了，音符能穿过更远的雾。一个夜里，迷路的伙伴循着笛声找回营地，山谷随后响起层层回音。小笛轻轻放缓节奏，让远处还在赶路的人，也有时间跟上。",
            hiddenRuleID: nil, series: "异界乐器"
        ),
        CollectibleDefinition(
            id: "growth.silent-chimes", name: "无声风铃", kind: .ordinary, ordinaryIndex: 29,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "安静的坚持，也会被风记住。",
            details: "一串小风铃挂在无风的庭院，久久没有响过。它却每天整理垂落的铃叶，修好彼此碰撞留下的小缺口。树上的鸟看见了，便把远方吹来的种子衔到它身旁。\n\n庭院长出草木，枝叶间终于有了可以穿行的风。铃叶轻轻相碰，响起清澈的声音。来到这里歇脚的人抬起头，听见一场准备了很久、却从未催促谁的欢迎。",
            hiddenRuleID: nil, series: "异界乐器"
        ),
        CollectibleDefinition(
            id: "growth.path-lantern", name: "寻路提灯", kind: .ordinary, ordinaryIndex: 30,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "看清脚边，也是一种出发的力量。",
            details: "初入迷雾的提灯只能照亮几步路，旅人总嫌它不够明亮。一次赶路摔伤后，他停下来，借着灯光辨认脚边的石缝，重新包好行囊，慢慢选择落脚的位置。\n\n他们一同经过许多夜晚，灯心也收进了沿途遇见的火种。后来，提灯能照出雾中的岔路，旅人却仍记得先看好脚下。他把空闲的一只手留给身旁的人，带着那盏光，走得更稳、更远。",
            hiddenRuleID: nil, series: "旅途信物"
        ),
        CollectibleDefinition(
            id: "growth.boundary-boat", name: "渡界小舟", kind: .ordinary, ordinaryIndex: 31,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "一桨一桨，靠近尚未抵达的岸。",
            details: "小舟停在两界之间的河上，远岸的灯火看起来总是很近，划起来却十分遥远。船上的学徒曾为此急躁，后来开始记下每天经过的石标，也认真修补每一处渗水的缝。\n\n几场潮汛之后，船身变得结实，学徒也学会借助水流。终于靠岸时，他没有忘记那些陪自己练习过的河湾。小舟再次启航，载上新的旅人，把熟悉的桨声送进陌生的水域。",
            hiddenRuleID: nil, series: "旅途信物"
        ),
        CollectibleDefinition(
            id: "growth.homeward-anchor", name: "归途之锚", kind: .ordinary, ordinaryIndex: 32,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "记住珍视的事，就有重新站稳的地方。",
            details: "年轻的锚随船漂了很远，却害怕一旦落下，就再也无法远行。风暴来临时，它第一次握住海底的岩层，帮助船上的人熬过漫长的夜。\n\n天亮以后，船员们合力将它收回。它这才发现，停留也能为下一段航程积蓄力量。此后，它把每一处安全的港湾记进纹路，陪着船远行，也在需要的时候，替大家守住可以安心休息的位置。",
            hiddenRuleID: nil, series: "旅途信物"
        ),
        CollectibleDefinition(
            id: "growth.suspended-sun", name: "悬日之轮", kind: .ordinary, ordinaryIndex: 33,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "把愿望放进每天能够完成的一小圈。",
            details: "空城上方的日轮停止转动，街巷因此失去了晨昏。一个看守轮轴的孩子推不动整座圆环，便每天清理一小段齿轨，让生锈的缝隙重新透气。\n\n后来，更多人带着工具来到高台。圆环终于缓缓移动，第一束晨光照进长久昏暗的窗。孩子站在人群里，看着那些曾经微不足道的小小清理，连成了城市重新醒来的清晨。",
            hiddenRuleID: nil, series: "天空遗迹"
        ),
        CollectibleDefinition(
            id: "growth.stardust-scales", name: "星屑天平", kind: .ordinary, ordinaryIndex: 34,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "给努力留位置，也给生活留余地。",
            details: "星屑天平总想把所有重要的事放在同一侧，结果托盘越压越低，连最轻的星尘也盛不住。守夜人替它取下一些暂时用不到的石块，留下今天真正需要照料的几颗星。\n\n天平慢慢恢复了平稳，也学会随着季节调整两端的重量。后来，人们来到它身旁，重新安排工作、休息与陪伴的时间。两只托盘在风里轻轻摆动，托住了各自合宜的光。",
            hiddenRuleID: nil, series: "天空遗迹"
        ),
        CollectibleDefinition(
            id: "growth.wind-chasing-sail", name: "逐风之帆", kind: .ordinary, ordinaryIndex: 35,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "认清风向，再把自己交给远方。",
            details: "小帆初上天空时，总追着最快的云奔跑。几次被乱流折回，它才开始向老航者学习，看云层的纹路，分辨哪些风值得等待，哪些风需要绕开。\n\n它把破损处一针针缝好，也把新的经验织进帆面。后来，远方的风终于吹来，小帆稳稳张开，带着船穿过辽阔的晴空。绷紧的每一道线，都记得那些认真辨认方向的日子。",
            hiddenRuleID: nil, series: "天空遗迹"
        ),
        CollectibleDefinition(
            id: "growth.sleeping-ember-egg", name: "眠火之卵", kind: .ordinary, ordinaryIndex: 36,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "给正在萌芽的力量一点时间。",
            details: "火山沉睡后，一枚小卵留在温热的石窝里。山上的花开过几轮，它仍没有裂开，只有深处偶尔亮起一点火。守巢人每天替它挡风，耐心观察火光需要怎样的温度。\n\n终于有一天，卵壳之间生出明亮的纹路，新的生命在微光里伸展开来。它把第一缕暖意送回石窝，也将守巢人留下的耐心，带向了刚刚苏醒的群山。",
            hiddenRuleID: nil, series: "秘境生命"
        ),
        CollectibleDefinition(
            id: "growth.star-bearing-beast", name: "负星灵兽", kind: .ordinary, ordinaryIndex: 37,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "一步步走稳，也允许自己得到帮助。",
            details: "幼小的灵兽背上落了一颗星，每走几步就要停下喘息。它不愿让伙伴担心，直到爬坡时险些滑倒，才试着说出自己需要一段缓慢的路。\n\n伙伴们陪它练习，替它挑选能站稳的石阶。它渐渐长出强健的四肢，背上的星也找到了安稳的位置。后来，灵兽带着新来的小生命翻越山岭，总会在坡前停一停，等大家一起出发。",
            hiddenRuleID: nil, series: "秘境生命"
        ),
        CollectibleDefinition(
            id: "growth.floating-root-lotus", name: "浮根之莲", kind: .ordinary, ordinaryIndex: 38,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "在变化之中，养出自己的生长方式。",
            details: "一粒莲种落入漂浮的泉水，根须总也触不到泥土。它随水流转了很久，直到学会从雾里收集水滴，把细根缠在每一颗能握住的小石上。\n\n根须渐渐织成柔软的网，托起了第一片花瓣。后来，莲花在空中盛开，根间也成了微小生命停留的地方。风吹来时，它仍会轻轻摇晃，却已经能带着自己珍视的一切，一同生长。",
            hiddenRuleID: nil, series: "秘境生命"
        ),
        CollectibleDefinition(
            id: "growth.drowned-crown", name: "沉潮之冠", kind: .ordinary, ordinaryIndex: 39,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "在低处站稳，也能长出自己的光。",
            details: "旧王冠沉入海底后，日日被潮水推过岩床。它曾盼着有人将自己捞回高处，直到小鱼钻进冠齿之间，躲过一场猛烈的暗流。它开始慢慢挪动碎石，为这些来客留出安全的缝隙。\n\n岁月将珊瑚织进冠沿，原本冰冷的金属长成温暖的海中庭院。经过这里的生命越来越多，王冠终于在深海找到一件愿意长久做下去的事：替每一个小小的归客，守住片刻安稳。",
            hiddenRuleID: nil, series: "深海秘藏"
        ),
        CollectibleDefinition(
            id: "growth.abyss-pearl", name: "渊底明珠", kind: .ordinary, ordinaryIndex: 40,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "微光被看见之前，也值得认真守护。",
            details: "渊底的幼珠只亮着针尖般的光，照不到遥远的海面。养珠人却每天清理它周围的泥沙，让细小的水流经过，也替它挡住锋利的落石。光没有忽然变大，只一层一层，慢慢变得温润。\n\n后来，明珠照见了深沟里一条隐秘的通道。迷失的鱼群循光穿行，终于回到熟悉的水域。养珠人留在沟口，看那点曾经微弱的光，安静照亮了许多生命的远行。",
            hiddenRuleID: nil, series: "深海秘藏"
        ),
        CollectibleDefinition(
            id: "growth.returning-reef", name: "回游之礁", kind: .ordinary, ordinaryIndex: 41,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "把每一次归来，都变成重新出发的补给。",
            details: "一小片礁石总望着游远的鱼，羡慕它们能见到不同的海。后来，一条受伤的鱼回到礁边休息，它便用身上的凹隙挡住急流，让疲惫的鳍慢慢恢复力量。\n\n回来歇脚的生命带来了种子，也留下了远方的消息。小礁渐渐长成丰盛的海底驿站。它依旧留在原处，却把一次次被照顾好的归来，送成了更有力量的出发。",
            hiddenRuleID: nil, series: "深海秘藏"
        ),
        CollectibleDefinition(
            id: "growth.frost-breaking-bud", name: "破霜之芽", kind: .ordinary, ordinaryIndex: 42,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "从能松动的一点，开始靠近春天。",
            details: "幼芽在冰层下醒来时，四周仍是一片寂静。它试过一口气顶开寒霜，却折弯了柔嫩的叶尖。于是，它开始收集午后短暂的暖意，让根须先在泥土里站稳。\n\n日光一天天多留片刻，芽尖也一点点找到了冰面的裂隙。终于探出头时，原野仍有寒风，它却已能舒展新的叶片。后来，许多种子沿着它松开的泥缝，迎来了各自的春天。",
            hiddenRuleID: nil, series: "季节轮转"
        ),
        CollectibleDefinition(
            id: "growth.summer-keeping-fruit", name: "藏夏之果", kind: .ordinary, ordinaryIndex: 43,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "把今天的丰盛，留一点给未来。",
            details: "夏末的小果想把所有阳光都留在身上，越是紧紧裹住自己，果皮便越发干涩。园丁替它疏开枝叶，让风和雨也来到身旁，帮助它慢慢长出结实的果肉。\n\n秋天到来，果实里藏起了饱满的种子。寒日里的旅人分食甜味，也把种子带向不同的山谷。等到新的夏天，树影从许多地方生长起来，把那份曾被悉心照料的丰盛，传得更远。",
            hiddenRuleID: nil, series: "季节轮转"
        ),
        CollectibleDefinition(
            id: "growth.winter-crossing-branch", name: "渡冬之枝", kind: .ordinary, ordinaryIndex: 44,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "留住生长的力气，慢慢穿过寒冷。",
            details: "初雪落下时，小枝还想托住每一片叶子。积雪越来越重，它才在老树的陪伴下，学着轻轻放下枯叶，把养分送回细小的芽点，专心守住这一季能够守住的生命。\n\n冬夜过去许多轮，枝头仍有安稳的呼吸。春风回来时，新芽依次醒来，鸟也重新停上枝梢。那些沉静度过的日子，已在树皮深处，留下了下一次舒展的力量。",
            hiddenRuleID: nil, series: "季节轮转"
        ),
        CollectibleDefinition(
            id: "growth.star-carrying-fish", name: "衔星飞鱼", kind: .ordinary, ordinaryIndex: 45,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "带着一件小小的使命，认真走向远方。",
            details: "幼小的飞鱼衔住一粒失落的星，想把它送回夜空。最初它只能跃起很低，便沿着浪尖练习，每一次落回水中，都把方才学到的风向记在鳍上。\n\n月升月落，飞鱼终于能在海风里滑翔。它将星粒送进一片暗淡的星群，又回身寻找下一位需要捎信的旅人。天与海之间，从此多了一道轻盈却可靠的往返。",
            hiddenRuleID: nil, series: "星空信使"
        ),
        CollectibleDefinition(
            id: "growth.nightwatch-moth", name: "巡夜灵蛾", kind: .ordinary, ordinaryIndex: 46,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "用自己的节律，陪黑夜走向清晨。",
            details: "小灵蛾总追着夜里最亮的灯，飞到疲惫，才发现自己已经离花园很远。守园人把一盏温和的小灯留在窗边，陪它重新辨认月亮、花香和回家的方向。\n\n后来，灵蛾沿着熟悉的路线慢慢巡行，翅上的纹路也越来越清晰。晚归的小虫循着它穿过黑暗，在叶背找到休息的地方。等天亮时，它也收起翅膀，安心睡在自己认识的花园。",
            hiddenRuleID: nil, series: "星空信使"
        ),
        CollectibleDefinition(
            id: "growth.comet-spirit", name: "曳尾彗灵", kind: .ordinary, ordinaryIndex: 47,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "让走过的路，留下可以照见的痕迹。",
            details: "小彗灵的尾光总是很短，它因此不敢飞进辽阔的星野。一次护送迷途的星尘时，它顾不上比较身后的光，只认真记下沿途的引力与暗礁，一段一段向前飞去。\n\n旅程慢慢将细碎的光编进它的长尾。后来，新来的彗灵沿着这些痕迹辨认方向，它便放缓速度，等它们一同经过最难的一段星路。漫长的尾光里，也有了彼此陪伴的温度。",
            hiddenRuleID: nil, series: "星空信使"
        ),
        CollectibleDefinition(
            id: "growth.light-gathering-windmill", name: "拾光风车", kind: .ordinary, ordinaryIndex: 48,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "把零散的片刻，转成一点可用的力量。",
            details: "旧谷地的小风车只在偶尔经过的微风里转上一圈。看守它的孩子便趁无风的时候修好叶轴，整理齿轮，还在地上记下每次风来的时刻。\n\n渐渐地，风车接住了更多短暂的风，把散落的光送进村里的储灯。夜晚到来，一盏盏小灯依次亮起。孩子站在风车下，听见那些曾经不起眼的片刻，正转成大家生活里安稳的一部分。",
            hiddenRuleID: nil, series: "奇异装置"
        ),
        CollectibleDefinition(
            id: "growth.dream-spinning-wheel", name: "引梦纺轮", kind: .ordinary, ordinaryIndex: 49,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "把愿望拆成细线，今天先织一小段。",
            details: "小纺轮的主人想织出一片会发光的夜空，却总在一大团乱线前发愁。织梦人教她先理出一根线，只完成今天能够稳稳织好的几针，收工时再把余线妥善放好。\n\n一夜一夜，短线连起了细密的星纹，纺轮也转得从容起来。后来，第一幅星幕挂上窗边，为远行的人照亮归处。她又坐回轮旁，带着已经练熟的双手，开始下一段新的梦。",
            hiddenRuleID: nil, series: "奇异装置"
        ),
        CollectibleDefinition(
            id: "growth.gap-seeking-key", name: "寻隙钥匙", kind: .ordinary, ordinaryIndex: 50,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "留心眼前的小缝隙，机会会有可以进入的形状。",
            details: "一把小钥匙在旧城里找不到自己的门，曾用力撬过许多锁。修门人让它停下来，先替街坊清理锁孔里的砂砾，观察每扇门真实需要的帮助。\n\n钥齿在一次次耐心的修整中变得清晰，它也渐渐听懂了门轴的轻响。终于有一扇沉寂的门稳稳打开，里面透出新的街道。小钥匙带着那份学会观察的本领，继续走向下一处微光。",
            hiddenRuleID: nil, series: "奇异装置"
        ),
        CollectibleDefinition(
            id: "growth.rift-starship", name: "裂空星舰", kind: .ordinary, ordinaryIndex: 51,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "把准备做扎实，再迎接更大的航程。",
            details: "幼小的星舰总想一次穿过整片星云，船壳却连近港的乱流也承受不住。年轻船员把宏大的航图收起，先学着检查铆钉、分配补给，在短短的航段里认真练习返航。\n\n后来，星舰拥有了结实的舷壁，也拥有了懂得合作的伙伴。第一道远空裂隙出现在眼前时，他们一起核对航线，从容驶入。长长的星河，终于成了能够一步步探索的前路。",
            hiddenRuleID: nil, series: "星际航行"
        ),
        CollectibleDefinition(
            id: "growth.gravity-sail", name: "引力风帆", kind: .ordinary, ordinaryIndex: 52,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "借助能够获得的支持，走出更远的距离。",
            details: "小风帆离开母港后，总想独自抵住每一股引力，几次险些被扯破。航海师教它看见星体之间细小的牵引，调整角度，在合适的时候顺着力量前进。\n\n风帆把这些经验一针针织进纹路，渐渐能托住更长的旅程。后来，它带着一艘满载种子的船穿过星海，也将途中得到的指引，留给随后赶来的远航者。",
            hiddenRuleID: nil, series: "星际航行"
        ),
        CollectibleDefinition(
            id: "growth.transit-ring", name: "跃迁之环", kind: .ordinary, ordinaryIndex: 53,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "抵达之前，先搭好下一步的支点。",
            details: "两端的星港隔得太远，小小的跃迁环试过许多次，也接不住瞬间涌来的光。守环人没有催它，只在沿途添上一个个安稳的中继点，让每一段传递都能被认真接住。\n\n光终于连成完整的环，远岸送来的第一封信稳稳落地。后来，更长的路也被一点点接通。跃迁环每亮起一次，都记得那些先被搭好、又被反复照看的小小支点。",
            hiddenRuleID: nil, series: "星际航行"
        ),
        CollectibleDefinition(
            id: "growth.memory-bottle", name: "回忆之瓶", kind: .ordinary, ordinaryIndex: 54,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "把珍惜的片刻收好，也给新故事留位置。",
            details: "小瓶子想留住旅途中所有声音与颜色，装得太满，连里面最温柔的笑声也分辨不清。旅人陪它停在河边，把真正想记住的事一件件整理出来。\n\n瓶中的微光慢慢沉淀，清晰照见曾经收到的帮助与勇气。后来，旅人每次出发，都只添进一段认真度过的经历。瓶口仍留着空隙，等待明天带回新的故事。",
            hiddenRuleID: nil, series: "记忆容器"
        ),
        CollectibleDefinition(
            id: "growth.soundkeeping-conch", name: "留声海螺", kind: .ordinary, ordinaryIndex: 55,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "听清一段声音，再把回应送回去。",
            details: "小海螺总重复听到的每一句话，声音堆在一起，反而谁也听不清。潮汐老人教它先安静下来，听完一个人的讲述，再留一点空白，让对方有时间呼吸。\n\n海螺渐渐学会保存那些真正需要被记住的声音。后来，远行的人把祝福托付给它，晚归的人也在它身旁听见久别的问候。一阵阵回声里，始终留着可以认真相遇的空间。",
            hiddenRuleID: nil, series: "记忆容器"
        ),
        CollectibleDefinition(
            id: "growth.dream-vault", name: "梦藏匣", kind: .ordinary, ordinaryIndex: 56,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "把重要的梦放好，也记得时常打开。",
            details: "小匣子收着许多尚未实现的愿望，主人却因害怕失望，很久不愿打开它。一天，她只取出最小的一件：修好窗边的花盆，再种下一粒早就准备好的种子。\n\n此后，每完成一小步，她便回来整理一次匣中的纸条。匣盖渐渐长出明亮的纹样，里面有了新的计划，也有了已经发生的故事。那些被珍藏的梦，开始在日常里慢慢生根。",
            hiddenRuleID: nil, series: "记忆容器"
        ),
        CollectibleDefinition(
            id: "growth.rising-snowcloud", name: "逆雪之云", kind: .ordinary, ordinaryIndex: 57,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "缓慢上升的努力，也有自己的季节。",
            details: "小云里的雪总向上飘，常被别的云团笑话。它也曾试着压住雪花，直到一片干冷的山林向天空伸出枝条，需要有人把远处的湿润带过去。\n\n小云开始跟着山势练习，把细小的雪送到更高的风里。后来，雪在山顶聚成新的水源，融化时润湿了长久沉寂的土地。它仍保持自己的方向，却已找到了愿意认真完成的使命。",
            hiddenRuleID: nil, series: "异界气象"
        ),
        CollectibleDefinition(
            id: "growth.gathering-rain-ring", name: "凝雨之环", kind: .ordinary, ordinaryIndex: 58,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "让细小的积累，有一处稳稳汇聚的地方。",
            details: "旱谷上方的小环接不住一场完整的雨，水滴总从边缘散落。守谷人陪它调整弧度，用细丝连好一处处缺口，先留住今天能接到的几滴水。\n\n日复一日，细小的水珠连成了清亮的雨帘。谷底的种子得到滋润，泥土里冒出第一层新绿。小环继续耐心收拢飘来的云气，让后来醒来的生命，也能分到属于自己的那一点雨。",
            hiddenRuleID: nil, series: "异界气象"
        ),
        CollectibleDefinition(
            id: "growth.spiraling-aurora", name: "回旋极光", kind: .ordinary, ordinaryIndex: 59,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "在反复练习里，找到从容舒展的轨迹。",
            details: "年轻的极光初次出现时，只能在天空留下一段打结的微亮。它越急着展开，颜色便越容易散去。夜风陪它慢慢转过山脊，让每一次弯折都有可以接续的空间。\n\n许多个清冷的夜晚之后，极光终于铺成流动的长带。山下的人仰望天空，在起伏的光里找到片刻宁静。它仍会顺着风改变形状，却能带着练习过的节奏，安稳地回旋。",
            hiddenRuleID: nil, series: "异界气象"
        ),
        CollectibleDefinition(
            id: "growth.sleeping-statue", name: "沉眠石像", kind: .ordinary, ordinaryIndex: 60,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "在安静的日子里，慢慢站稳。",
            details: "小石像沉睡在旧山门旁，许多年没有动过。风雨替它磨去锋利的边角，山上的孩子则每天清理脚边的碎石，让它不再向一侧倾斜。\n\n洪水到来时，石像缓缓醒来，站进被冲断的门道，替经过的人撑住最后一段石梁。水退以后，它又安静坐下，身上的纹路却已记住：长久被认真照料的安稳，也可以成为帮助别人的力量。",
            hiddenRuleID: nil, series: "古老守护"
        ),
        CollectibleDefinition(
            id: "growth.embracing-wall", name: "环抱之壁", kind: .ordinary, ordinaryIndex: 61,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "留下可以进出的门，也守好安心停留的地方。",
            details: "旧营地的小墙总想把所有风都挡在外面，越筑越紧，里面的人也渐渐看不见远方。修墙人替它留出通风的窗和能够开合的门，让生活重新有了呼吸。\n\n后来，墙身在一次次修补中变得结实。出门的人可以放心远行，疲惫的人也能回来歇脚。夜里，灯光从窗中温柔透出，照着一处有边界、也始终欢迎相逢的家。",
            hiddenRuleID: nil, series: "古老守护"
        ),
        CollectibleDefinition(
            id: "growth.watchful-feather", name: "守望之羽", kind: .ordinary, ordinaryIndex: 62,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "把温柔练成可靠的陪伴。",
            details: "一片幼羽落在高高的山口，总担心自己太轻，帮不上经过的人。它便从最小的事做起：替火苗挡一下风，替迷路的孩子指一指山下的灯。\n\n日子将细密的光织进羽脉，它渐渐能在风里站稳，也能为更远的旅途守望。后来，每当有人经过山口，总会看见那道柔和的光，安静地陪他们走完最难的一小段。",
            hiddenRuleID: nil, series: "古老守护"
        ),
        CollectibleDefinition(
            id: "growth.pulsar-core", name: "脉冲星核", kind: .ordinary, ordinaryIndex: 63,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "把愿望放进可以持续的节律。",
            details: "幼小的星核在寂静星野里闪烁，总因急着照亮远方而耗尽气力。守星人没有让它更用力，只陪它数清一次亮起、一次歇息，让光慢慢有了稳定的间隔。\n\n许多个长夜之后，微弱的闪光汇成了清晰的脉冲。远航者开始用它校准航向，在陌生的星海里辨认时间。星核依旧一明一暗地呼吸，却已经能把可靠的光，送到很远的地方。",
            hiddenRuleID: nil, series: "宇宙残响"
        ),
        CollectibleDefinition(
            id: "growth.collapsed-star-nest", name: "坍缩星巢", kind: .ordinary, ordinaryIndex: 64,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "慢慢整理，也能为新的开始腾出空间。",
            details: "旧星巢坍缩时，许多熟悉的轨道都挤在了一起。小小的筑巢者守着残片，不知道该从哪里重建。后来，它先清理出一条能够通行的缝，再把仍有余温的星石一颗颗安放好。\n\n散乱的碎光逐渐有了新的位置，巢心也重新响起安稳的回声。第一颗新星醒来时，筑巢者正替它整理身旁的空隙。曾经破碎的地方，在耐心的照看里，成了生命再次出发的家。",
            hiddenRuleID: nil, series: "宇宙残响"
        ),
        CollectibleDefinition(
            id: "growth.gravity-rift", name: "引力裂谷", kind: .ordinary, ordinaryIndex: 65,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "在遥远的两端之间，搭起可以信任的连接。",
            details: "一条裂谷将星原分开，幼小的引力丝只能牵住两岸最轻的尘埃。它曾为自己的微弱发愁，直到一位旅人沿岸留下第一枚锚点，请它试着把光送过去。\n\n一枚、两枚，新的锚点在两岸慢慢增多，细丝也织成了能承载脚步的通道。后来，远行的人相互照应着穿过裂谷。那片空旷依然辽阔，沿途却已经有了可以认真交付重量的地方。",
            hiddenRuleID: nil, series: "宇宙残响"
        ),
        CollectibleDefinition(
            id: "growth.wind-listening-lily", name: "听风之铃兰", kind: .ordinary, ordinaryIndex: 66,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "先认真倾听，再送出自己的回应。",
            details: "小铃兰初开时，总抢在风来以前摇动花冠，盼着花园听见自己。一次夜雨，它终于安静下来，听见叶背的小虫正在寻找能避雨的地方，便把一朵花轻轻低下。\n\n后来，铃兰长出更多花穗，学会随着不同的风调整姿态。每当谁经过花旁，总能找到一处合宜的停留。花园里有了轻柔的铃声，也有了许多被认真听见的小小声音。",
            hiddenRuleID: nil, series: "异界花园"
        ),
        CollectibleDefinition(
            id: "growth.reverse-growing-vine", name: "逆生藤蔓", kind: .ordinary, ordinaryIndex: 67,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "生长的方向，可以从自己的处境里找到。",
            details: "岩壁上的小藤总向下伸展，攀不上旁边高高的枝架。它反复扯回柔嫩的梢，直到发现，石壁下方有一片干渴的苔地，正等着有人把高处的水引来。\n\n小藤顺着自己的方向继续生长，让水滴沿叶缘缓缓落下。后来，石壁披上了连绵的绿，鸟也停在枝间歇脚。那些曾显得不同的弯曲，已经连成一条滋养山谷的路。",
            hiddenRuleID: nil, series: "异界花园"
        ),
        CollectibleDefinition(
            id: "growth.rainkeeping-fern", name: "藏雨之蕨", kind: .ordinary, ordinaryIndex: 68,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "留下一点滋养，照顾尚未到来的日子。",
            details: "小蕨长在雨来得很少的坡地，最初总在雨停后迅速失去精神。园丁陪它整理叶片，让细小的绒边接住露水，也在根旁铺上能留住湿润的苔。\n\n一季一季，蕨叶长成蓬松的绿伞，叶间蓄着清凉的水珠。漫长的晴日里，幼苗在它身旁慢慢扎根。它把从雨里学会的珍惜，变成了可以分享给别人的柔软荫凉。",
            hiddenRuleID: nil, series: "异界花园"
        ),
        CollectibleDefinition(
            id: "growth.reviving-amber", name: "复苏之珀", kind: .ordinary, ordinaryIndex: 69,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "被保存的可能，也值得重新照料。",
            details: "古珀里封着一粒未醒的种子，许多季节过去，表面只添了新的尘。年轻的看守者每天擦亮一小处，让温和的日光缓缓照进深处，从不拿尖锐的工具催它裂开。\n\n终于有一天，珀心泛起细微的绿，沉睡的纹路也开始流动。第一片叶子伸展时，看守者替它留出呼吸的空间。那份长久被耐心守护的可能，终于有了属于自己的新季节。",
            hiddenRuleID: nil, series: "远古化生"
        ),
        CollectibleDefinition(
            id: "growth.layered-shell", name: "叠纪之壳", kind: .ordinary, ordinaryIndex: 70,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "走过的岁月，会成为新的支撑。",
            details: "小壳每经过一片陌生的海，身上便多出一圈细纹。它嫌这些痕迹不够平滑，总想把它们磨去。一次深海急流袭来，那些层层叠起的纹路，恰好替柔软的内里分散了冲击。\n\n此后，它开始认真照料每一层新生的壳，也记住每一段旅程教会的本领。后来，它能安稳穿过更深的水域，带着岁月留下的形状，迎接尚未见过的海。",
            hiddenRuleID: nil, series: "远古化生"
        ),
        CollectibleDefinition(
            id: "growth.renewing-bone", name: "蜕生之骨", kind: .ordinary, ordinaryIndex: 71,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "为新的自己，留出舒展的位置。",
            details: "一截古骨在春潮里重新醒来，却被厚重的旧壳束住。它一度想带着所有残片一起站起，几次失去平衡后，才学着放下已经松脱的外层，保护里面仍在生长的纹路。\n\n新的光沿着骨脉慢慢延伸，支起轻盈而结实的轮廓。后来，它走出了潮湿的石窟，脚步里带着旧日的经验，也有了能够适应新路的柔韧。身后的碎壳，静静留在春天经过的地方。",
            hiddenRuleID: nil, series: "远古化生"
        ),
        CollectibleDefinition(
            id: "growth.twin-rings", name: "双生指环", kind: .ordinary, ordinaryIndex: 72,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "把彼此的步调，也放进共同的约定。",
            details: "两枚小指环初次相连时，都想按自己的节奏转动，常在碰撞里留下细小裂痕。修环人请它们停下来，轮流听一听对方的回声，再试着一起走完最短的一圈。\n\n长久的磨合让连接处变得平稳，也给各自的转动留出了余地。后来，两枚环共同托起一道明亮的光。佩戴它们的旅人每次启程，都记得先确认身旁的人，是否准备好一同出发。",
            hiddenRuleID: nil, series: "契约信物"
        ),
        CollectibleDefinition(
            id: "growth.promise-seal", name: "守诺之印", kind: .ordinary, ordinaryIndex: 73,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "让每个小约定，都有落在生活里的分量。",
            details: "年轻的刻印者想做一枚能承担宏大誓言的印，却连纸边的细纹也刻不稳。老师让他先记下一件今天答应的事，认真做完后，再在印面添上一刀。\n\n许多清晨过去，浅浅的刻痕渐渐组成清晰的图案。后来，人们把重要的托付交到他手里，因为那些细小约定，早已一次次被稳妥地接住。印章落下时，带着可以被生活验证的温度。",
            hiddenRuleID: nil, series: "契约信物"
        ),
        CollectibleDefinition(
            id: "growth.wish-binding-cord", name: "结愿之绳", kind: .ordinary, ordinaryIndex: 74,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "把愿望与行动，认真系在一起。",
            details: "小绳上挂满了写着愿望的纸，风一大，许多结就散开了。编绳人陪它逐一整理，只留下愿意为之行动的几张，再把每个愿望拆成能够练习的小步骤。\n\n每做完一步，他们便重新收紧一个结。松散的丝线渐渐织成结实的绳，带着已经发生的故事。后来，有人沿着它攀上山坡，纸上的远方，也一点点变成了脚下真实的风景。",
            hiddenRuleID: nil, series: "契约信物"
        ),
        CollectibleDefinition(
            id: "growth.suspended-dunes", name: "悬砂之丘", kind: .ordinary, ordinaryIndex: 75,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "一粒一粒，也能聚成可以站稳的地方。",
            details: "梦境里的砂总悬在半空，一阵风就能吹散小小的丘形。年轻的聚砂者曾急着堆起高峰，后来改用细线围出一个小圈，让今天收来的砂先有地方停留。\n\n日复一日，细砂在彼此之间找到支撑，慢慢托起了起伏的坡面。后来，远行的人能在丘上留下脚印，停下来看看路。那些轻得几乎看不见的小小积累，已经接住了真实的重量。",
            hiddenRuleID: nil, series: "梦境地貌"
        ),
        CollectibleDefinition(
            id: "growth.refracting-canyon", name: "折光峡谷", kind: .ordinary, ordinaryIndex: 76,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "让不同的目光，照见同一段前路。",
            details: "小峡谷只让一束光通过，谷底总有许多地方看不清。勘路者在两侧试着安放不同角度的晶石，听同行的人说出各自看见的暗礁，再慢慢调整光路。\n\n后来，光在岩壁间折出丰富的颜色，显出从前未被注意的台阶与水源。旅人们沿着这些线索走过山谷，也学会在停步时，邀请身旁的人指一指自己尚未看见的地方。",
            hiddenRuleID: nil, series: "梦境地貌"
        ),
        CollectibleDefinition(
            id: "growth.echo-cavern", name: "回声洞庭", kind: .ordinary, ordinaryIndex: 77,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "在回应里认识自己，也给沉默留一点时间。",
            details: "洞庭深处的小回声总模仿每一种声音，越学越多，却渐渐分不清自己的节奏。守洞人陪它坐在泉边，先听完一滴水落下，再安静等到涟漪散去。\n\n小回声开始认真选择要传向远处的音符，也学会让声音之间保持呼吸。后来，迷路的人在洞里轻声呼唤，总能听见清晰而温柔的回应，帮助他们一步步走回有光的出口。",
            hiddenRuleID: nil, series: "梦境地貌"
        ),
        CollectibleDefinition(
            id: "growth.mist-treading-hoof", name: "踏雾灵蹄", kind: .ordinary, ordinaryIndex: 78,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "看不清远处时，先确认脚下这一落。",
            details: "小灵蹄第一次走进雾里，总因望不见前路而僵在原地。山中的引路者没有催促，只陪它轻轻试一试脚下的石面，站稳以后，再向前挪出短短的一步。\n\n走过许多清晨，它渐渐听懂了泥土与岩石的回声。后来，灵蹄能带着迷路的伙伴穿过浓雾，也仍会在松动的地方停下来，等每一个脚步，都找到属于自己的支撑。",
            hiddenRuleID: nil, series: "灵性游兽"
        ),
        CollectibleDefinition(
            id: "growth.tide-coiling-eel", name: "卷潮长鳗", kind: .ordinary, ordinaryIndex: 79,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "顺着变化调整，也能守住想去的方向。",
            details: "幼鳗想笔直穿过海峡，总被回卷的潮水推回原处。它累得蜷在礁边，才发现老海鳗会在浪起时轻轻转身，借着下一段水流，重新靠近远方的出口。\n\n小鳗开始练习舒展与回旋，把自己的呼吸放进潮汐里。后来，它长成能穿过暗流的修长身影，也把学会的路线留给新来的伙伴。海仍不断变化，它的方向却愈发清晰。",
            hiddenRuleID: nil, series: "灵性游兽"
        ),
        CollectibleDefinition(
            id: "growth.mountain-bearing-sleeper", name: "负山眠兽", kind: .ordinary, ordinaryIndex: 80,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "放下片刻，也是在照顾长久前行的力量。",
            details: "小眠兽背上生着一座细小的山，起初总想不眠不休地守住山上的生命。直到一次疲惫让脚步摇晃，它才在伙伴的陪伴下，找了一处平稳的谷地，安心睡过一个夜晚。\n\n此后，它学会安排停歇，也让山上的居民参与照料水源与树林。山渐渐繁盛，眠兽的步伐也越来越稳。每次醒来，它都能带着休息过的力量，继续走向下一片温暖的土地。",
            hiddenRuleID: nil, series: "灵性游兽"
        ),
        CollectibleDefinition(
            id: "growth.lockless-gate", name: "无锁之门", kind: .ordinary, ordinaryIndex: 81,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "先看清阻碍，才能找到合适的用力方式。",
            details: "古道尽头的门没有锁孔，小修门匠带来的钥匙全都派不上用场。他停下反复敲打的手，仔细听门轴的轻响，终于发现，门脚被多年累积的砂石卡住了。\n\n他一铲一铲清理缝隙，又给生锈的转轴添上油。门缓缓打开时，许多等待的旅人一同走来。修门匠把工具收好，带着学会观察的耐心，继续前往下一段古道。",
            hiddenRuleID: nil, series: "隐秘机关"
        ),
        CollectibleDefinition(
            id: "growth.realm-turning-axle", name: "转境之轴", kind: .ordinary, ordinaryIndex: 82,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "从能够调整的一点，慢慢改变眼前的格局。",
            details: "小轴连着梦城里许多房间，却只要一转，就会把所有通路搅乱。机关师没有催它一次完成整座城的变化，只陪它标记位置，先稳稳转动其中最轻的一环。\n\n一次次校准以后，齿轮之间有了清晰的配合。后来，房间能在需要时移动，让阳光照进原本昏暗的角落。小轴也终于明白，细小而准确的调整，可以慢慢改变一整片风景。",
            hiddenRuleID: nil, series: "隐秘机关"
        ),
        CollectibleDefinition(
            id: "growth.hidden-path-box", name: "藏径之匣", kind: .ordinary, ordinaryIndex: 83,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "把尝试过的线索，收成下一次出发的准备。",
            details: "小匣里藏着许多折叠的小路，旅人每次打开，都容易被纷乱的岔口困住。他开始为走过的道路留一枚标记，记下哪里有水，哪里需要绕行，再把暂时用不到的路径妥善收起。\n\n匣中的空间渐渐清晰，新的线索也能找到安放的位置。后来，有人向他询问陌生山路，他便打开匣子，取出一段认真走过的经验，陪对方一起规划最初的几步。",
            hiddenRuleID: nil, series: "隐秘机关"
        ),
        CollectibleDefinition(
            id: "growth.star-gathering-pack", name: "拾星背囊", kind: .ordinary, ordinaryIndex: 84,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "认真选择要带走的东西，也给脚步留一点轻盈。",
            details: "小背囊想把旅途里遇见的每颗星都装下，渐渐重得让主人无法前行。夜里的营火旁，他们一起整理行囊，留下真正需要的工具与珍惜的信物，也把多余的星光分给同行的人。\n\n后来，背囊长出结实而柔软的纹路，能稳妥承载新的旅程。每次离开营地，主人都会检查一次里面的东西，让值得珍视的重量，与仍能轻快迈出的脚步，一同走向远方。",
            hiddenRuleID: nil, series: "旅途行装"
        ),
        CollectibleDefinition(
            id: "growth.night-crossing-cloak", name: "渡夜斗篷", kind: .ordinary, ordinaryIndex: 85,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "把自己照顾好，再慢慢穿过漫长的夜。",
            details: "初织好的小斗篷只能挡住一点寒风，旅人却总把它展开到最紧，想护住所有来客。几次撕裂以后，织衣人陪他缝好边缘，也教他在天冷时，先找一处能生火歇息的地方。\n\n斗篷在长久照料里变得温暖而坚韧。后来，大家围着营火轮流守夜，疲惫的人可以安心裹着它睡去。黎明到来时，他们带着恢复过的精神，一起收拾行装，继续赶路。",
            hiddenRuleID: nil, series: "旅途行装"
        ),
        CollectibleDefinition(
            id: "growth.wind-seeking-boots", name: "寻风之履", kind: .ordinary, ordinaryIndex: 86,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "找到自己的步幅，让每一步都能接续。",
            details: "一双新履总想跟上路上最快的脚步，鞋底很快磨出裂痕。修鞋人陪旅人重新丈量脚掌，调好松紧，再沿着熟悉的山径，试着用舒服的速度走完一小段。\n\n走过石路、草地与长坡，新履渐渐有了贴合脚步的形状。后来，旅人抵达更远的山口，仍记得在疲惫时放缓速度，让呼吸、风声和自己的步幅，安稳地接在一起。",
            hiddenRuleID: nil, series: "旅途行装"
        ),
        CollectibleDefinition(
            id: "growth.self-writing-scroll", name: "自生卷轴", kind: .ordinary, ordinaryIndex: 87,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "先写下真实的一行，故事才有继续的地方。",
            details: "幼小的卷轴只要听见别人的期待，就会急着长出新的篇章。纸面越来越满，执笔的旅人却找不到自己的声音。一天，他轻轻抹去那些代写的结局，只留下今天亲自走过的一段路。\n\n卷轴从这一行开始舒展，把笨拙的尝试、临时的转向和偶尔的欢喜都收进纸纹。后来，旅人终于读到一部属于自己的长卷，而下一页仍然空白，等着他亲自落笔。",
            hiddenRuleID: nil, series: "异界文字"
        ),
        CollectibleDefinition(
            id: "growth.wandering-ink-pen", name: "游墨之笔", kind: .ordinary, ordinaryIndex: 88,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "允许最初的笔画生涩，让练习慢慢长出力量。",
            details: "初醒的墨笔总在落纸前游开，怕一滴歪斜的墨毁掉整幅星图。画师便铺开许多旧纸，请它每天留下一道不同的线，弯曲也好，断开也好，都可以留下。\n\n那些线渐渐有了轻重与方向，墨笔也学会在停顿后重新落下。多年后，它替远行的人画出通往新大陆的航线。纸角仍留着最早的一笔，提醒它从哪里学会了开始。",
            hiddenRuleID: nil, series: "异界文字"
        ),
        CollectibleDefinition(
            id: "growth.floating-script-stele", name: "浮字石碑", kind: .ordinary, ordinaryIndex: 89,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "把经历沉淀成自己的理解，再带着它前行。",
            details: "小石碑上的文字一到风里就会散开。守碑人曾试着把所有字都刻得很深，却发现自己记住了句子，仍不懂该怎样过河。后来，他带着一个问题走到岸边，向摆渡人学会了辨认水纹。\n\n回来时，石碑上只多了一小行清楚的记述。这样的行走重复了许多次，漂浮的字逐渐围成稳定的环。旅人经过这里，可以借到一段经验，也会被邀请走向自己的河岸。",
            hiddenRuleID: nil, series: "异界文字"
        ),
        CollectibleDefinition(
            id: "growth.shadow-folding-prism", name: "折影棱镜", kind: .ordinary, ordinaryIndex: 90,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "换一个角度看看，眼前也许还有别的道路。",
            details: "小棱镜把一面高墙的影子折在脚下，怎么看都像没有出口。修镜师没有替它搬开墙，只把它转了半圈。光从另一侧穿过时，一段藏在阴影里的台阶显出了轮廓。\n\n后来，棱镜长出更多清晰的切面，陪许多困在原地的人重新观察来路。他们会停一停、绕一绕，再决定下一步。那面墙依然高大，脚下可走的地方却越来越清楚。",
            hiddenRuleID: nil, series: "光影奇物"
        ),
        CollectibleDefinition(
            id: "growth.day-night-dial", name: "昼夜双面盘", kind: .ordinary, ordinaryIndex: 91,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "认真行动，也给恢复留下完整的时间。",
            details: "小双面盘很喜欢白昼，便把夜色藏在背面，让工坊的灯一直亮着。渐渐地，齿轮开始错位，工匠也忘了手边正在做什么。看守人把盘轻轻翻过来，请大家先睡一个安稳的夜。\n\n醒来以后，他们一起调好两面的轮换。双面盘成熟时，白昼与夜色都能顺畅流转。工坊重新响起清晰的敲击声，每件作品完成以后，也都有一段让双手歇息的宁静。",
            hiddenRuleID: nil, series: "光影奇物"
        ),
        CollectibleDefinition(
            id: "growth.lightkeeping-shade", name: "藏光灯罩", kind: .ordinary, ordinaryIndex: 92,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "调好自己的光，照亮此刻能够照顾的地方。",
            details: "小灯罩害怕自己的灯火被忽略，便把缝隙越撑越大。光散向四处，桌前的字反而模糊了。制灯人请它把边缘轻轻收回，让一束柔和的光先落在摊开的书页上。\n\n日子久了，灯罩学会随着需要调整开合。读书时照清文字，同行时照见脚下，休息时留下一点温暖。它终于有了安稳的形状，让有限的灯火，也能陪人度过很长的一段时光。",
            hiddenRuleID: nil, series: "光影奇物"
        ),
        CollectibleDefinition(
            id: "growth.meteor-wheat", name: "陨星麦穗", kind: .ordinary, ordinaryIndex: 93,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "把收获的愿望，落实在每天的照料里。",
            details: "一粒陨星麦落进贫瘠的月壤，急着长成整片金色原野。种植者每天只带来一小杯水，松开一点硬土，再替它挡住过强的星风。起初，地面上几乎看不见变化。\n\n根须却在深处逐渐站稳，第一支麦穗终于越过石缝，结出沉甸甸的光粒。下一季，种植者留下足够的种子，也把一部分收获分给邻居。那片原野，便从有人持续照料的一株开始。",
            hiddenRuleID: nil, series: "深空植物"
        ),
        CollectibleDefinition(
            id: "growth.orbital-dandelion", name: "环轨蒲公英", kind: .ordinary, ordinaryIndex: 94,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "准备好自己的种子，也学习选择出发的时机。",
            details: "小蒲公英住在缓慢旋转的环轨边，第一次迎风就想送走所有种子。巡轨人拦下了它，陪它观察哪里有光、哪里有能停留的土，哪些风会把种子带进漫长的暗处。\n\n等到种子长好轻韧的绒翼，蒲公英在合适的风里放开花冠。许久以后，环轨另一端亮起一朵新的小花。它们隔着星空相望，各自扎根，也替下一次远行守候着风。",
            hiddenRuleID: nil, series: "深空植物"
        ),
        CollectibleDefinition(
            id: "growth.stardust-pinecone", name: "星尘松果", kind: .ordinary, ordinaryIndex: 95,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "珍惜缓慢积蓄的时日，让准备在需要时派上用场。",
            details: "幼小的松果把星尘藏在鳞片之间，总嫌自己的生长太慢。直到漫长的寒季来到，树冠上的新芽都收起了叶片，它才发现，那些一点点存下的温度仍留在身体里面。\n\n它守着枝头度过风雪，等暖流回来，才慢慢张开成熟的鳞片。种子带着积蓄许久的力量落进土中。第一根嫩枝探出地面时，松果终于看见，那些安静的日子正在另一处继续生长。",
            hiddenRuleID: nil, series: "深空植物"
        ),
        CollectibleDefinition(
            id: "growth.rift-slipping-serpent", name: "穿隙灵蛇", kind: .ordinary, ordinaryIndex: 96,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "先找到容得下自己的入口，再一点点向前。",
            details: "幼蛇来到封闭的岩壁前，试过撞开最厚的石面，也试过追随大兽留下的痕迹。疲惫时，它贴近地面，忽然听见细小的风正从一条狭缝里穿过。它收好身体，慢慢探了进去。\n\n一路上，幼蛇学会判断石缝的宽窄，在过紧的地方退回，也在合适的位置留下标记。成熟以后，它能引领许多小小的生命穿过山脉。那条路很窄，却足够让属于它们的旅途继续。",
            hiddenRuleID: nil, series: "边界行者"
        ),
        CollectibleDefinition(
            id: "growth.mirror-crossing-wings", name: "渡镜双翼", kind: .ordinary, ordinaryIndex: 97,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "看清自己站在哪里，才能稳稳越过新的边界。",
            details: "初生的双翼总扑向镜中的远方，几次撞上冰凉的镜面。镜湖边的老人请它先停在岸上，观察水纹，分清哪一道影子来自自己，哪一片光藏着真正能够穿越的门。\n\n双翼渐渐学会调整角度，在镜面平静时收拢羽尖，在门显现时舒展身体。它穿越第一面镜湖那天，没有追赶倒影，而是朝着亲自确认的方向，飞进了有风的天空。",
            hiddenRuleID: nil, series: "边界行者"
        ),
        CollectibleDefinition(
            id: "growth.boundary-striding-walker", name: "踏界长足", kind: .ordinary, ordinaryIndex: 98,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "把落脚处确认清楚，再把下一步交给远方。",
            details: "小长足站在两片漂移的界石之间，想一步跨过整道深渊。第一次抬脚，它便失去平衡，只好退回起点。同行者替它找到几处稳定的石面，陪它练习先站稳，再把重心慢慢移过去。\n\n随着长足长成，步幅也逐渐变远。它记得每块石面的承重，在陌生的边界耐心试探，也会为后来的旅人停下脚步。那些走得稳妥的小步，终于接成了一条能够往返的长路。",
            hiddenRuleID: nil, series: "边界行者"
        ),
        CollectibleDefinition(
            id: "growth.folding-tent", name: "折叠帐篷", kind: .ordinary, ordinaryIndex: 99,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "为自己留一个能安顿下来的地方，再继续远行。",
            details: "小帐篷第一次展开时，怎么也撑不出传说中宽阔的营地。旅人便先清理一片平地，把支架逐根放好，再添一盏灯。夜风到来时，这个小小的角落已经足够让人安心坐下。\n\n跟着旅人走过许多地方，帐篷逐渐学会舒展与收拢，能容下新的同伴，也能轻便地回到背囊。每次重新出发，旅人都知道，沿途仍有一处可以亲手搭起的家。",
            hiddenRuleID: nil, series: "梦境居所"
        ),
        CollectibleDefinition(
            id: "growth.suspended-cradle", name: "悬眠摇篮", kind: .ordinary, ordinaryIndex: 100,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "安心休息的时候，也有力量在慢慢恢复。",
            details: "幼小的摇篮悬在梦树枝头，总怕停止摆动就会掉下去。守梦人替它检查绳结，请风轻一点，再把一颗疲倦的小星放进篮里。它试着缓慢摇动，第一次听见了平稳的呼吸。\n\n后来，摇篮长出更柔韧的边缘，能随着来客的重量调整姿态。无数个夜晚，疲惫的旅人在这里睡去，醒来后重新找到赶路的精神。摇篮留在枝间，守着那份无需赶路的宁静。",
            hiddenRuleID: nil, series: "梦境居所"
        ),
        CollectibleDefinition(
            id: "growth.homecoming-dream-nest", name: "归梦巢屋", kind: .ordinary, ordinaryIndex: 101,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "把归来的路留在心里，让成长有可以安放的地方。",
            details: "小巢屋住在变换不停的梦境里，每天都照着别处的城堡改变模样。旅人几次归来，都找不到熟悉的门。于是，他们一起留下固定的门灯、一张旧桌，还有能看见晨星的窗。\n\n巢屋仍会随着日子生长，却保留着那些熟悉的位置。远行的人带回新的故事，在门前放下行囊。渐渐地，这里有了能接住重逢的空间，也有了让下一次出发更加踏实的温暖。",
            hiddenRuleID: nil, series: "梦境居所"
        ),
        CollectibleDefinition(
            id: "growth.star-measuring-instrument", name: "测星仪", kind: .ordinary, ordinaryIndex: 102,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "用亲自核对过的坐标，修正下一段航向。",
            details: "小测星仪继承了一张古老星图，却发现眼前的星空总与刻度错开。学徒起初以为自己看错了，后来决定逐夜记录，再和同伴交换观察。那些细小的偏差，终于拼出了星野缓慢移动的轨迹。\n\n他们一起调整仪器，让新的记录留在旧刻度旁。测星仪成熟时，已经能够帮助远航者确认位置。学徒仍会在出航前抬头看一眼星空，认真核对今天的方向。",
            hiddenRuleID: nil, series: "古老仪器"
        ),
        CollectibleDefinition(
            id: "growth.tide-listening-dish", name: "听潮盘", kind: .ordinary, ordinaryIndex: 103,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "在纷杂的声响里，辨认真正值得回应的信号。",
            details: "小听潮盘把海岸上每一种声音都收进盘心，浪花、脚步和自己的回声挤成一团。守潮人带它离开热闹的码头，在同一块礁石上听了许多个清晨，慢慢分清水位变化的低鸣。\n\n盘面上的纹路逐渐清晰，细微的潮讯也有了可以辨认的间隔。后来，出海的人会在这里确认归港的时刻。听潮盘依然听见很多声音，却能把最有用的那一道，稳稳送到需要它的人身边。",
            hiddenRuleID: nil, series: "古老仪器"
        ),
        CollectibleDefinition(
            id: "growth.vein-seeking-probe", name: "寻脉探针", kind: .ordinary, ordinaryIndex: 104,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "带着问题试探，也让每一次结果修正自己的判断。",
            details: "小探针循着传说里的矿脉钻进山腹，几次只找到普通的石块。矿师没有丢掉这些记录，而是把每一次探查的位置画在图上，比较岩层、温度与水流，重新圈出值得验证的方向。\n\n探针沿着新的线索继续前进，终于触到一缕温暖的地脉。成熟的针身留下许多细刻，每一刻都对应一次认真检查。后来的人借着这些记录，能少走一些弯路，也能继续发现图上还空着的地方。",
            hiddenRuleID: nil, series: "古老仪器"
        ),
        CollectibleDefinition(
            id: "growth.cooperating-ant-column", name: "协行蚁阵", kind: .ordinary, ordinaryIndex: 105,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "把力量接在一起，也让每个同伴都有合适的位置。",
            details: "最初的蚁阵只想让所有成员走得一样快，越过碎石时，队伍却不断散开。带路的老蚁停下来，让善于探路的先行，让能承重的运粮，也留出同伴轮换与休息的位置。\n\n一趟又一趟，它们学会传递路况，遇见难处便相互支援。成熟的蚁阵终于把足够的粮食送回巢中。队伍仍有快慢，每只小蚁却都知道，自己的那一段路怎样与大家相接。",
            hiddenRuleID: nil, series: "异界种群"
        ),
        CollectibleDefinition(
            id: "growth.floating-fungal-colony", name: "浮空菌落", kind: .ordinary, ordinaryIndex: 106,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "照顾共同生长的环境，让自己的成长也能滋养周围。",
            details: "几朵幼菌漂在稀薄的云层，各自收紧菌丝，争抢仅有的水汽。旱风到来时，它们才试着把细丝连在一起，把吸到的水分送向最干燥的一端，也为新生的小菌留出位置。\n\n菌落渐渐织成轻盈的云岛，能储存雨露，也能随季风调整高度。路过的种子在这里歇脚，细小的生命在菌伞下安家。它们共同照料的那片湿润，终于托起了更多种类的生长。",
            hiddenRuleID: nil, series: "异界种群"
        ),
        CollectibleDefinition(
            id: "growth.migrating-light-rays", name: "迁徙光鳐", kind: .ordinary, ordinaryIndex: 107,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "与同伴互相照应，也练习辨认自己的方向。",
            details: "幼小的光鳐跟在队尾，只认得前一条尾翼的亮光。一场星雾将队伍冲散，它便在原地焦急打转。领航者找到它后，陪它观察星位与暖流，让它试着带领一小段平缓的航程。\n\n几次迁徙以后，光鳐已经能与同伴轮流领航。遇见浓雾，它们会放慢速度，发出彼此能够辨认的光讯。长长的队伍游向远海，每一束光都能回应同伴，也知道自己正朝哪里前进。",
            hiddenRuleID: nil, series: "异界种群"
        ),
        CollectibleDefinition(
            id: "growth.unsent-letter", name: "未寄之笺", kind: .ordinary, ordinaryIndex: 108,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "把想说的话认真写下，再决定怎样送达。",
            details: "小信笺装着旅人许久未说出口的话，每到投递的时候，字迹便缩回折痕。信使没有催它出发，只陪旅人分清哪些是心愿、哪些是担忧，哪些话需要留到面对面时慢慢说。\n\n一遍遍整理以后，信笺终于有了清楚而温柔的内容。旅人选择一个合适的清晨，把它交给信使。无论回信何时到来，那些曾挤在心里的话，都已经有了能够被理解的形状。",
            hiddenRuleID: nil, series: "封存之物"
        ),
        CollectibleDefinition(
            id: "growth.still-tide-jar", name: "静潮之罐", kind: .ordinary, ordinaryIndex: 109,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "情绪翻涌时，先给自己一段安静辨认的时间。",
            details: "小罐子收下旅人从海边带回的潮水，每次委屈或激动，水便撞得罐壁作响。看罐人请旅人先把它放稳，陪着听一会儿浪声，再慢慢说出今天发生的事。\n\n随着一次次辨认与照料，罐中逐渐显出不同的水纹。成熟的潮罐仍会起伏，旅人却能认出自己需要休息、倾诉，或采取行动的时刻。浪声落下以后，他会带着更清楚的心情，重新走回岸边。",
            hiddenRuleID: nil, series: "封存之物"
        ),
        CollectibleDefinition(
            id: "growth.awakening-box", name: "待醒之盒", kind: .ordinary, ordinaryIndex: 110,
            symbolName: "sparkles", silhouetteSymbolName: "sparkles",
            summary: "给尚未完成的愿望一个位置，也为它安排一次新的尝试。",
            details: "小盒子里睡着许多被搁置的计划，旅人总想一次打开所有盖缝。愿望相互挤撞，谁也找不到出口。守盒人请他先选出此刻最想照料的一件，写下一个能够实际完成的小步骤。\n\n那件愿望有了行动的日期，盒面也亮起第一道细纹。后来，旅人定期回来整理，继续值得投入的事，也放下已经不合适的打算。成熟的盒子安稳地开合，让每次醒来的愿望，都有机会走进生活。",
            hiddenRuleID: nil, series: "封存之物"
        )
    ]

    static let hidden: [CollectibleDefinition] = HiddenCardCatalog.definitions

    static let all: [CollectibleDefinition] = ordinary + hidden

    static func visibleDefinitions(ownedIDs: Set<String>) -> [CollectibleDefinition] {
        ordinary + hidden.filter { ownedIDs.contains($0.id) }
    }

    static func definition(id: String) -> CollectibleDefinition? {
        all.first { $0.id == id }
    }

    static func ordinary(at index: Int) -> CollectibleDefinition? {
        guard ordinary.indices.contains(index) else { return nil }
        return ordinary[index]
    }
}
