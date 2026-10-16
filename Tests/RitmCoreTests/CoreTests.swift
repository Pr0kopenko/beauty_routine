import XCTest
@testable import RitmCore

// Порт web/tests/logic.test.mjs + поведение нативной версии.

private func sample() -> AppState {
    var s = AppState()
    s.onboarded = true
    s.items = [
        Item(id: "retinal", name: "Ретиналь", actives: ["retinoid"], block: "evening", schedule: Schedule(type: "interval", freq: "2w"), type: "serum", retinoidForm: "retinal"),
        Item(id: "aravia", name: "Пептидная сыворотка Aravia", actives: ["peptides"], block: "morning", type: "serum"),
        Item(id: "aza-serum", name: "Сыворотка с азелаиновой кислотой", actives: ["azelaic"], block: "evening", type: "serum"),
        Item(id: "aza-cream", name: "Крем с азелаиновой кислотой", actives: ["azelaic"], block: "optional", schedule: Schedule(type: "asneeded"), type: "cream"),
        Item(id: "niac", name: "Сыворотка с ниацинамидом", actives: ["niacinamide"], block: "morning", type: "serum"),
        Item(id: "spf", name: "SPF Skin1004", actives: ["spf"], block: "morning", type: "spf"),
        Item(id: "magnesium", name: "Магний", actives: ["supplement"], block: "supplements", type: "supplement"),
    ]
    return s
}
private func mark(_ id: String, _ day: String, _ slot: String = "evening") -> Entry { Entry(itemId: id, day: day, slot: slot) }
private func prod(_ id: String, _ actives: [String], form: String? = nil) -> Item { Item(id: id, name: id, actives: actives, block: "optional", schedule: Schedule(type: "asneeded"), type: "serum", retinoidForm: form) }

final class DaysTests: XCTestCase {
    func testDayBoundary4am() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Europe/Moscow")!
        let d = { (h: Int, m: Int) in cal.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: h, minute: m))! }
        XCTAssertEqual(Days.key(d(0, 40), calendar: cal), "2026-10-15")
        XCTAssertEqual(Days.key(d(4, 0), calendar: cal), "2026-10-16")
        XCTAssertEqual(Days.key(d(23, 59), calendar: cal), "2026-10-16")
    }
    func testArithmeticAcrossDST() {
        XCTAssertEqual(Days.add("2026-10-24", 3), "2026-10-27")
        XCTAssertEqual(Days.between("2026-10-24", "2026-10-27"), 3)
        XCTAssertEqual(Days.add("2026-12-30", 3), "2027-01-02")
    }
    func testFriday() {
        XCTAssertEqual(Days.weekday("2026-10-16"), 5)
        XCTAssertEqual(Days.long("2026-10-16"), "Пятница, 16 октября")
    }
    func testPlural() {
        XCTAssertEqual(Days.daysWord(1), "1\u{00a0}день"); XCTAssertEqual(Days.daysWord(3), "3\u{00a0}дня")
        XCTAssertEqual(Days.daysWord(11), "11\u{00a0}дней"); XCTAssertEqual(Days.daysWord(22), "22\u{00a0}дня")
    }
}

final class RetinoidTests: XCTestCase {
    func testStatus2w() {
        var s = sample()
        let item = s.item("retinal")!
        XCTAssertEqual(Retinoid.status(item, s, today: "2026-10-16").state, .notStarted)
        s.entries = [mark("retinal", "2026-10-14")]
        let at = { (d: String) in Retinoid.status(item, s, today: d) }
        XCTAssertEqual(at("2026-10-14").state, .done); XCTAssertEqual(at("2026-10-14").next, "2026-10-17")
        XCTAssertEqual(at("2026-10-15").state, .resting); XCTAssertEqual(at("2026-10-16").next, "2026-10-17")
        XCTAssertEqual(at("2026-10-17").state, .today); XCTAssertEqual(at("2026-10-19").state, .today)
        XCTAssertEqual(at("2026-10-20").state, .overdue); XCTAssertEqual(at("2026-10-20").since, 6)
    }
    func testFrequencyChangeOnlyFuture() {
        var s = sample(); s.entries = [mark("retinal", "2026-10-14")]
        var item = s.item("retinal")!; item.schedule.freq = "1w"
        XCTAssertEqual(Retinoid.status(item, s, today: "2026-10-17").state, .resting)
        XCTAssertEqual(Retinoid.status(item, s, today: "2026-10-17").next, "2026-10-21")
    }
    func testFutureAndSkippedIgnored() {
        var s = sample()
        var skipped = mark("retinal", "2026-10-15"); skipped.skipped = true
        s.entries = [mark("retinal", "2026-10-10"), skipped, mark("retinal", "2026-10-20")]
        let st = Retinoid.status(s.item("retinal")!, s, today: "2026-10-16")
        XCTAssertEqual(st.last, "2026-10-10"); XCTAssertEqual(st.state, .overdue)
    }
    func testStagesWeeklyLimit() {
        var s = sample()
        var r = s.item("retinal")!; r.schedule.freq = "eod"
        s.entries = ["2026-10-10", "2026-10-12", "2026-10-14"].map { mark("retinal", $0) }
        XCTAssertEqual(Retinoid.status(r, s, today: "2026-10-15").state, .resting)
        XCTAssertEqual(Retinoid.status(r, s, today: "2026-10-16").state, .today)
        r.schedule.freq = "5w"
        s.entries = ["2026-10-12", "2026-10-13", "2026-10-14", "2026-10-15", "2026-10-16"].map { mark("retinal", $0) }
        XCTAssertEqual(Retinoid.status(r, s, today: "2026-10-17").state, .resting)
        XCTAssertEqual(Retinoid.status(r, s, today: "2026-10-17").next, "2026-10-19")
    }
    func testTwoRetinoidsShareInterval() {
        var s = sample(); s.items.append(prod("rol", ["retinoid"], form: "retinol"))
        s.entries = [mark("rol", "2026-10-15")]
        XCTAssertEqual(Retinoid.status(s.item("retinal")!, s, today: "2026-10-16").state, .resting, "любой ретиноид сбрасывает интервал")
        XCTAssertFalse(Compatibility.check(itemId: "retinal", day: "2026-10-16", slot: "evening", in: s).filter { $0.rule == "retinoid-interval" }.isEmpty)
    }
    func testPause() {
        var s = sample(); s.entries = [mark("retinal", "2026-10-10")]
        let ret = s.item("retinal")!
        s.diary = ["2026-10-15": DiaryDay(reactions: ["redness": 2])]
        XCTAssertEqual(Retinoid.status(ret, s, today: "2026-10-16").state, .paused)
        XCTAssertEqual(Retinoid.status(ret, s, today: "2026-10-18").state, .overdue)
        s.diary = ["2026-10-12": DiaryDay(reactions: ["burning": 3])]
        XCTAssertEqual(Retinoid.status(ret, s, today: "2026-10-17").state, .paused, "сильная реакция не снимается сама через 4 дня")
        s.diary["2026-10-16"] = DiaryDay(reactions: ["burning": 1, "redness": 0])
        XCTAssertNotEqual(Retinoid.status(ret, s, today: "2026-10-17").state, .paused)
        s.diary = ["2026-10-15": DiaryDay(reactions: ["breakouts": 3])]
        XCTAssertNotEqual(Retinoid.status(ret, s, today: "2026-10-16").state, .paused, "высыпания — не раздражение")
        s.diary = [:]; s.settings.pregnancy = true
        XCTAssertEqual(Retinoid.status(ret, s, today: "2026-10-16").state, .blocked)
    }
    func testAdvice() {
        var s = sample()
        var ret = s.item("retinal")!; ret.schedule = Schedule(type: "interval", freq: "2w", since: "2026-10-01")
        s.entries = ["2026-10-01", "2026-10-05", "2026-10-09", "2026-10-13"].map { mark("retinal", $0) }
        let up = Retinoid.advice(ret, s, today: "2026-10-16")
        XCTAssertEqual(up?.kind, .up); XCTAssertEqual(up?.to, "eod")
        XCTAssertNil(Retinoid.advice(ret, s, today: "2026-10-10"))
        ret.schedule.freq = "eod"; s.diary = ["2026-10-15": DiaryDay(reactions: ["dryness": 2])]
        let down = Retinoid.advice(ret, s, today: "2026-10-16")
        XCTAssertEqual(down?.kind, .down); XCTAssertEqual(down?.to, "2w")
        ret.retinoidForm = "tretinoin"; s.diary = [:]
        XCTAssertNil(Retinoid.advice(ret, s, today: "2026-10-30"), "рецептурные — шаги ведёт врач")
    }
}

final class CompatibilityTests: XCTestCase {
    func testIntervalHint() {
        var s = sample(); s.entries = [mark("retinal", "2026-10-14")]
        XCTAssertTrue(Compatibility.check(itemId: "retinal", day: "2026-10-15", slot: "evening", in: s).contains { $0.rule == "retinoid-interval" })
        XCTAssertTrue(Compatibility.check(itemId: "retinal", day: "2026-10-17", slot: "evening", in: s).isEmpty)
        s.entries = [mark("retinal", "2026-10-17")]
        XCTAssertTrue(Compatibility.check(itemId: "retinal", day: "2026-10-15", slot: "evening", in: s).contains { $0.rule == "retinoid-interval" }, "задним числом")
    }
    func testAzelaicBothWaysAndToggle() {
        var s = sample(); s.entries = [mark("aza-cream", "2026-10-17")]
        XCTAssertTrue(Compatibility.check(itemId: "retinal", day: "2026-10-17", slot: "evening", in: s).contains { $0.rule == "retinoid-azelaic" })
        s.entries = [mark("retinal", "2026-10-17")]
        XCTAssertTrue(Compatibility.check(itemId: "aza-serum", day: "2026-10-17", slot: "evening", in: s).contains { $0.rule == "retinoid-azelaic" })
        XCTAssertTrue(Compatibility.check(itemId: "aza-serum", day: "2026-10-17", slot: "morning", in: s).isEmpty)
        s.rules["retinoid-azelaic"] = false
        XCTAssertTrue(Compatibility.check(itemId: "aza-serum", day: "2026-10-17", slot: "evening", in: s).isEmpty)
    }
    func testAcids() {
        var s = sample(); s.items.append(prod("toner", ["aha"]))
        s.entries = [mark("retinal", "2026-10-17")]
        XCTAssertFalse(Compatibility.check(itemId: "toner", day: "2026-10-18", slot: "evening", in: s).contains { $0.rule == "retinoid-acids-adjacent" })
        s.rules["retinoid-acids-adjacent"] = true
        XCTAssertTrue(Compatibility.check(itemId: "toner", day: "2026-10-18", slot: "evening", in: s).contains { $0.rule == "retinoid-acids-adjacent" })
        s.entries += [mark("toner", "2026-10-10"), mark("toner", "2026-10-12")]
        XCTAssertTrue(Compatibility.check(itemId: "toner", day: "2026-10-14", slot: "evening", in: s).contains { $0.rule == "acids-weekly" })
        XCTAssertFalse(Compatibility.check(itemId: "toner", day: "2026-10-20", slot: "evening", in: s).contains { $0.rule == "acids-weekly" })
        XCTAssertTrue(Compatibility.check(itemId: "retinal", day: "2026-10-17", slot: "morning", in: s).contains { $0.rule == "retinoid-evening" })
    }
    func testBpoVitcExfoliantCopper() {
        var s = sample()
        s.items = [prod("bpo", ["bpo"]), prod("rol", ["retinoid"], form: "retinol"), prod("ada", ["retinoid"], form: "adapalene"), prod("c", ["vitc"]), prod("aha", ["aha"]), prod("scrub", ["exfoliant"]), prod("cu", ["copper"])]
        s.entries = [mark("bpo", "2026-10-17")]
        XCTAssertTrue(Compatibility.check(itemId: "rol", day: "2026-10-17", slot: "evening", in: s).contains { $0.rule == "retinoid-bpo" })
        XCTAssertFalse(Compatibility.check(itemId: "ada", day: "2026-10-17", slot: "evening", in: s).contains { $0.rule == "retinoid-bpo" })
        XCTAssertFalse(Compatibility.check(itemId: "rol", day: "2026-10-17", slot: "morning", in: s).contains { $0.rule == "retinoid-bpo" })
        s.entries = [mark("rol", "2026-10-17"), mark("aha", "2026-10-15", "morning")]
        XCTAssertTrue(Compatibility.check(itemId: "c", day: "2026-10-17", slot: "evening", in: s).contains { $0.rule == "vitc-retinoid" })
        XCTAssertTrue(Compatibility.check(itemId: "c", day: "2026-10-17", slot: "morning", in: s).isEmpty)
        XCTAssertTrue(Compatibility.check(itemId: "scrub", day: "2026-10-15", slot: "evening", in: s).contains { $0.rule == "one-exfoliant" })
        XCTAssertTrue(Compatibility.check(itemId: "cu", day: "2026-10-15", slot: "morning", in: s).contains { $0.rule == "copper-acids" })
    }
    func testPauseHintsForAllStrongActives() {
        var s = sample(); s.items.append(prod("c", ["vitc"]))
        s.diary = ["2026-10-16": DiaryDay(reactions: ["redness": 2])]
        XCTAssertTrue(Compatibility.check(itemId: "c", day: "2026-10-16", slot: "morning", in: s).contains { $0.rule == "pause" })
        XCTAssertTrue(Compatibility.check(itemId: "niac", day: "2026-10-16", slot: "morning", in: s).isEmpty, "ниацинамид не активный раздражитель")
    }
}

final class PlannerTests: XCTestCase {
    func testRetinoidEveningDefersAzelaic() {
        var s = sample(); s.entries = [mark("retinal", "2026-10-14")]
        let p = Planner.plan(s, day: "2026-10-17")
        XCTAssertEqual(p.evening.first?.item.id, "retinal")
        XCTAssertNotNil(p.optional.first { $0.item.id == "aza-serum" }?.deferred)
    }
    func testRestingDay() {
        var s = sample(); s.entries = [mark("retinal", "2026-10-14")]
        let p = Planner.plan(s, day: "2026-10-15")
        XCTAssertTrue(p.evening.contains { $0.item.id == "aza-serum" })
        XCTAssertNotNil(p.optional.first { $0.item.id == "retinal" }?.deferred)
    }
    func testSpfAccent() {
        var s = sample(); s.entries = [mark("retinal", "2026-10-17")]
        XCTAssertNotNil(Planner.plan(s, day: "2026-10-18").morning.first { $0.item.id == "spf" }?.accent)
        XCTAssertNil(Planner.plan(s, day: "2026-10-19").morning.first { $0.item.id == "spf" }?.accent)
    }
    func testPauseDefersAllStrongActives() {
        var s = sample(); s.items.append(Item(id: "c", name: "Витамин C", actives: ["vitc"], block: "morning", type: "serum"))
        s.diary = ["2026-10-16": DiaryDay(reactions: ["redness": 2])]
        let p = Planner.plan(s, day: "2026-10-16")
        XCTAssertTrue(p.paused)
        XCTAssertNotNil(p.optional.first { $0.item.id == "c" }?.deferred)
        XCTAssertNotNil(p.optional.first { $0.item.id == "aza-serum" }?.deferred)
        XCTAssertTrue(p.morning.contains { $0.item.id == "niac" })
    }
}

final class InciTests: XCTestCase {
    func testDetect() {
        let r = Inci.detect("Aqua, Glycolic Acid, Butylene Glycol, Niacinamide, Panthenol, Retinal, Palmitoyl Tripeptide-1, Citric Acid")
        XCTAssertEqual(Set(r.actives), ["aha", "niacinamide", "retinoid", "peptides"])
        XCTAssertFalse(Inci.detect("Water, Glycerin, Citric Acid, Xanthan Gum").actives.contains("aha"))
        XCTAssertEqual(Inci.detect("Вода, азелаиновая кислота").actives, ["azelaic"])
        XCTAssertEqual(Inci.retinoidForm("Aqua, Retinal, Squalane"), "retinal")
        XCTAssertEqual(Inci.retinoidForm("Aqua, Hydroxypinacolone Retinoate"), "hpr")
    }
}

final class BackupTests: XCTestCase {
    func testImportPwaV1() throws {
        let json = """
        {"version":1,"onboarded":true,"items":[{"id":"retinal","name":"Ретиналь","actives":["retinoid"],"block":"evening","schedule":{"type":"interval","freq":"2w"},"archived":false},{"id":"m","name":"Магний","actives":["supplement"],"block":"supplements","schedule":{"type":"daily"}}],
         "entries":[{"id":"a","itemId":"retinal","day":"2026-10-13","slot":"evening","at":""}],"rules":{"retinoid-acids-adjacent":true},
         "reminders":{"morning":{"weekdays":"07:45","weekend":"09:30"},"evening":"22:00","overrides":{}},"lastBackupAt":null}
        """
        let (s, photos) = try Backup.decode(Data(json.utf8))
        XCTAssertEqual(s.items[0].retinoidForm, "retinal")
        XCTAssertEqual(s.items[1].type, "supplement")
        XCTAssertEqual(s.rules["retinoid-acids-adjacent"], false)
        XCTAssertEqual(s.rules["retinoid-evening"], true)
        XCTAssertEqual(s.reminders.followUpMinutes, 60)
        XCTAssertTrue(photos.isEmpty)
        XCTAssertEqual(s.version, 2)
    }
    func testRoundTrip() throws {
        var s = sample(); s.entries = [mark("retinal", "2026-10-14")]; s.diary = ["2026-10-14": DiaryDay(reactions: ["redness": 1], note: "ок", photos: ["p1"])]
        let data = try Backup.encode(s, photos: [BackupPhoto(id: "p1", day: "2026-10-14", at: nil, data: "data:image/jpeg;base64,AAAA")])
        let (back, photos) = try Backup.decode(data)
        XCTAssertEqual(back.items, s.items); XCTAssertEqual(back.entries, s.entries); XCTAssertEqual(back.diary, s.diary)
        XCTAssertEqual(photos.count, 1)
    }
    func testErrors() {
        XCTAssertThrowsError(try Backup.decode(Data("nope".utf8))) { XCTAssertEqual($0 as? BackupError, .notJson) }
        XCTAssertThrowsError(try Backup.decode(Data("{\"hello\":1}".utf8))) { XCTAssertEqual($0 as? BackupError, .notOurs) }
        XCTAssertThrowsError(try Backup.decode(Data("{\"items\":[],\"entries\":[],\"version\":99}".utf8))) { XCTAssertEqual($0 as? BackupError, .tooNew) }
    }
}

final class NotificationPlannerTests: XCTestCase {
    func testPlanSkipsDoneAndPast() {
        var s = sample(); s.entries = [mark("retinal", "2026-10-14"), mark("magnesium", "2026-10-16", "morning"), mark("aravia", "2026-10-16", "morning"), mark("niac", "2026-10-16", "morning"), mark("spf", "2026-10-16", "morning")]
        let r = NotificationPlanner.plan(s, today: "2026-10-16", now: "08:30")
        XCTAssertNil(r.first { $0.id == "m-2026-10-16" }, "утро сделано")
        XCTAssertNotNil(r.first { $0.id == "e-2026-10-16" })
        XCTAssertEqual(r.first { $0.id == "e-2026-10-17" }?.title, "Сегодня вечер — Ретиналь")
        XCTAssertEqual(r.first { $0.id == "m-2026-10-17" }?.time, "09:30", "суббота — выходное время")
        XCTAssertLessThanOrEqual(r.count, 30)
        s.reminders.overrides["2026-10-19"] = "07:15"
        XCTAssertEqual(NotificationPlanner.plan(s, today: "2026-10-16", now: "08:30").first { $0.id == "m-2026-10-19" }?.time, "07:15")
    }
    func testFollowUpRespectsQuietHours() {
        var s = sample(); s.reminders.evening = "23:00"
        let r = NotificationPlanner.plan(s, today: "2026-10-16", now: "08:00")
        XCTAssertNil(r.first { $0.id == "f-e-2026-10-16" }, "повтор после 23:30 не ставим")
        XCTAssertNotNil(r.first { $0.id == "f-m-2026-10-17" })
    }
}

final class RecognitionTests: XCTestCase {
    func testParseStrictJson() {
        let text = #"{"is_skincare":true,"brand":"Skin1004","name":"Madagascar Centella Sun","product_type":"spf","actives":["spf","unknown"],"retinoid_form":"none","strength":"SPF 50+","time_of_day":"morning","inci_text":"","confidence":"high","note_ru":"Солнцезащитный крем."}"#
        let r = Recognition.parse(text)!
        XCTAssertEqual(r.type, "spf")
        XCTAssertEqual(r.actives, ["spf"], "неизвестный актив отброшен")
        XCTAssertNil(r.retinoidForm)
        XCTAssertEqual(r.displayName, "Skin1004 Madagascar Centella Sun")
        XCTAssertEqual(r.suggestedBlock, "morning")
    }
    func testParseDirtyJsonAddsRetinoid() {
        let r = Recognition.parse("Вот ответ: ```json\n{\"brand\":\"\",\"name\":\"Retinal 0.1\",\"product_type\":\"bogus\",\"actives\":[],\"retinoid_form\":\"retinal\",\"time_of_day\":\"night\"}\n```")!
        XCTAssertEqual(r.type, "other")
        XCTAssertEqual(r.actives, ["retinoid"])
        XCTAssertEqual(r.retinoidForm, "retinal")
        XCTAssertEqual(r.time, "any")
        XCTAssertNil(Recognition.parse("не json"))
    }
}

final class ActionsTests: XCTestCase {
    func testMakeRetinoidItem() {
        let r = RecognizedProduct(brand: "", name: "Ретинол 0.3", type: "serum", actives: ["retinoid"], retinoidForm: nil, time: "any")
        let it = Actions.makeItem(r, block: "morning", today: "2026-10-16")
        XCTAssertEqual(it.block, "evening", "ретиноид всегда вечером")
        XCTAssertEqual(it.retinoidForm, "retinol")
        XCTAssertEqual(it.schedule, Schedule(type: "interval", freq: "2w", since: "2026-10-16"))
        let supp = Actions.makeItem(RecognizedProduct(name: "Магний B6", actives: ["supplement"]), today: "2026-10-16")
        XCTAssertEqual(supp.block, "supplements")
        XCTAssertEqual(supp.type, "supplement")
        let opt = Actions.makeItem(RecognizedProduct(name: "Маска"), today: "2026-10-16")
        XCTAssertEqual(opt.schedule.type, "asneeded")
    }
    func testMarkBlockSkipsConflicts() {
        var s = sample()
        s.entries = [mark("retinal", "2026-10-12")]
        let added = Actions.markBlock(&s, kind: "evening", day: "2026-10-16")
        XCTAssertEqual(Set(added.map(\.itemId)), ["retinal"], "азелаиновая отложена в вечер ретиноида")
        let morning = Actions.markBlock(&s, kind: "morning", day: "2026-10-16")
        XCTAssertEqual(Set(morning.map(\.itemId)), ["aravia", "niac", "spf", "magnesium"])
        XCTAssertTrue(Planner.plan(s, day: "2026-10-16").allDone)
    }
    func testSkipDoesNotCountAsRetinoid() {
        var s = sample()
        s.entries = [mark("retinal", "2026-10-12")]
        Actions.skipBlock(&s, kind: "evening", day: "2026-10-16")
        XCTAssertEqual(Retinoid.days(s), ["2026-10-12"])
        let r = NotificationPlanner.plan(s, today: "2026-10-16", now: "08:00")
        XCTAssertNil(r.first { $0.id == "e-2026-10-16" }, "пропущенный вечер не напоминаем")
        XCTAssertNotNil(r.first { $0.id == "e-2026-10-17" }, "ретиноид снова завтра")
    }
    func testOnboarding() {
        var s = sample(); s.items[0].schedule = Schedule()
        var o = Actions.Onboarding(); o.last = "3"; o.freq = "2w"; o.weekdays = "07:30"
        let r = Actions.applyOnboarding(s, o, today: "2026-10-16")
        XCTAssertEqual(r.entries.filter(\.fromOnboarding).map(\.day), ["2026-10-13"])
        XCTAssertEqual(r.items[0].schedule.type, "interval")
        XCTAssertEqual(r.reminders.morning.weekdays, "07:30")
        XCTAssertEqual(Retinoid.status(r.items[0], r, today: "2026-10-16").state, .today)
        o.last = "never"; o.freq = nil
        let n = Actions.applyOnboarding(r, o, today: "2026-10-16")
        XCTAssertTrue(n.entries.filter(\.fromOnboarding).isEmpty)
        XCTAssertEqual(n.items[0].schedule.freq, "2w")
    }
}
