# Тестовые данные для скриншотов в CI: набор как у автора, даты — от сегодняшнего дня.
import json, datetime, sys
today = datetime.date.today()
def d(n): return (today + datetime.timedelta(days=n)).isoformat()
items = [
 dict(id="retinal", name="Ретиналь", brand="", type="serum", actives=["retinoid"], retinoidForm="retinal", strength="0.05%", block="evening", schedule=dict(type="interval", freq="2w", since=d(-20))),
 dict(id="salantra", name="Салантра", type="cream", actives=[], block="morning", schedule=dict(type="daily")),
 dict(id="aravia", name="Пептидная сыворотка Aravia", type="serum", actives=["peptides"], block="morning", schedule=dict(type="daily")),
 dict(id="niac", name="Сыворотка с ниацинамидом", type="serum", actives=["niacinamide"], block="morning", schedule=dict(type="daily")),
 dict(id="spf", name="SPF Skin1004", type="spf", actives=["spf"], block="morning", schedule=dict(type="daily")),
 dict(id="lrp", name="La Roche-Posay SPF", type="spf", actives=["spf"], block="optional", schedule=dict(type="asneeded")),
 dict(id="aza", name="Сыворотка с азелаиновой кислотой", type="serum", actives=["azelaic"], block="evening", schedule=dict(type="daily")),
 dict(id="azac", name="Крем с азелаиновой кислотой", type="cream", actives=["azelaic"], block="optional", schedule=dict(type="asneeded")),
 dict(id="patch", name="Роллер-патчи", type="eye", actives=[], block="optional", schedule=dict(type="asneeded")),
 dict(id="mg", name="Магний", type="supplement", actives=["supplement"], block="supplements", dose="1 капсула", schedule=dict(type="daily")),
]
entries = []
def e(i, day, slot, time=None): entries.append(dict(id=f"{i}-{day}-{slot}", itemId=i, day=day, slot=slot, at=day + "T08:00:00Z", time=time))
ret_days = (-15, -11, -8, -4)
for n in ret_days: e("retinal", d(n), "evening")
for n in range(-12, 0):
    e("mg", d(n), "morning", "07:52")
    for i in ("salantra", "aravia", "niac", "spf"): e(i, d(n), "morning")
    if n not in ret_days: e("aza", d(n), "evening")
e("mg", d(0), "morning", "07:48"); e("salantra", d(0), "morning", "07:55")
diary = {d(-8): dict(reactions=dict(redness=1, dryness=1), note="Немного стянуто после ретиналя", photos=[]),
         d(-1): dict(reactions=dict(redness=0, dryness=1, breakouts=1), note="", photos=[])}
state = dict(version=2, onboarded=True, items=items, entries=entries, diary=diary, startedAt=d(-20), lastBackupAt=d(-2) + "T10:00:00Z",
             reminders=dict(morning=dict(weekdays="07:45", weekend="09:30"), evening="22:00", overrides={}, followUpMinutes=60, quietAfter="23:30"),
             settings=dict(pregnancy=False))
json.dump(state, open(sys.argv[1], "w"), ensure_ascii=False, indent=1)
