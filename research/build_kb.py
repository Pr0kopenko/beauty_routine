# Generates ingredients-kb.json
import json, sys

OUT = "/tmp/claude-0/-home-user-beauty-routine/fe39948f-2eb6-5e74-b622-7323999bd2ee/scratchpad/ingredients-kb.json"

sources = [
    ("fda-aha", "FDA: Alpha Hydroxy Acids (CIR: <=10%, pH>=3.5; Sunburn Alert)", "https://www.fda.gov/cosmetics/cosmetic-ingredients/alpha-hydroxy-acids"),
    ("eu-1223", "Regulation (EC) No 1223/2009 on cosmetic products (art. 19 labelling, INCI order)", "https://eur-lex.europa.eu/eli/reg/2009/1223/oj"),
    ("eu-2024-996", "Commission Regulation (EU) 2024/996: vitamin A, alpha-arbutin, arbutin, kojic acid limits", "https://eur-lex.europa.eu/eli/reg/2024/996/oj"),
    ("coslaw-2024-996", "Coslaw: summary of 2024/996 (retinol 0.3% RE, body 0.05%; alpha-arbutin 2%/0.5%; arbutin 7%; kojic 1%)", "https://coslaw.eu/new-amendment-to-cosmetics-regulation-retinol-and-other-substances-banned-or-restricted-in-cosmetics/"),
    ("cosing", "EU CosIng database", "https://ec.europa.eu/growth/tools-databases/cosing/"),
    ("incidecoder-lists", "INCIDecoder: How to read an ingredient list", "https://incidecoder.com/ingredient-lists"),
    ("cosbiz-inci", "Cosmetics Business: writing ingredient lists in EU, US, Canada", "https://cosmeticsbusiness.com/a-guide-on-how-to-write-cosmetics-ingredient-lists-in-eu-us-and-canada-167611"),
    ("pc-dict", "Paula's Choice Ingredient Dictionary", "https://www.paulaschoice.com/ingredient-dictionary"),
    ("labmuffin", "Lab Muffin Beauty Science (Michelle Wong)", "https://labmuffin.com/"),
    ("labmuffin-bakuchiol", "Lab Muffin: Is bakuchiol better than retinol?", "https://labmuffin.com/bakuchiol-better-than-retinol/"),
    ("beautytap-mixing", "BeautyTap: interview with Michelle Wong on mixing actives (vit C + niacinamide is fine)", "https://beautytap.com/2018/8/avoid-mixing-in-skincare"),
    ("fb-mixing", "Formula Botanica: Mixing high-performance actives", "https://formulabotanica.com/mixing-high-performance-actives/"),
    ("dermnet-retinoids", "DermNet: Topical retinoids", "https://dermnetnz.org/topics/topical-retinoids"),
    ("dermnet-azelaic", "DermNet: Azelaic acid", "https://dermnetnz.org/topics/azelaic-acid"),
    ("dermnet-bpo", "DermNet: Benzoyl peroxide", "https://dermnetnz.org/topics/benzoyl-peroxide"),
    ("dermnet-sa", "DermNet: Salicylic acid", "https://dermnetnz.org/topics/salicylic-acid"),
    ("aad-sunscreen", "AAD: How to select a sunscreen", "https://www.aad.org/public/everyday-care/sun-protection/shade-clothing-sunscreen/how-to-select-sunscreen"),
    ("aad-acne-2024", "2024 AAD acne guidelines (MDedge summary)", "https://mdedge.com/content/inside-2024-aad-acne-guidelines-new-therapies-join-old-standbys"),
    ("ret-conc-pmc", "Retinol 0.1/0.3/1% in photoaged skin: efficacy and tolerability (PMC9826105)", "https://pmc.ncbi.nlm.nih.gov/articles/PMC9826105"),
    ("ret-tolerance", "Fluhr et al. Tolerance profile of retinol, retinaldehyde and retinoic acid (PubMed 10473963)", "https://pubmed.ncbi.nlm.nih.gov/10473963/"),
    ("bakuchiol-rct", "Dhaliwal et al. 2019 BJD: bakuchiol 0.5% vs retinol 0.5% RCT", "https://deepblue.lib.umich.edu/handle/2027.42/147746"),
    ("pinnell-laa", "Pinnell et al. 2001 Dermatol Surg: Topical L-ascorbic acid percutaneous absorption (pH<3.5, max 20%)", "https://www.lorealdermatologicalbeauty.com/inter/skinceuticals/download-pages/scientific-publications/topical-l-ascorbic-acid-percutaneous-absorption-studies"),
    ("bpo-jdd", "JDD: Advancement in benzoyl peroxide acne treatment (2.5/5/10% equally effective)", "https://jddonline.com/articles/dermatology/S1545961609P0657X"),
    ("acneorg-bpo", "Acne.org: benzoyl peroxide concentration study summary", "https://www.acne.org/everything-you-need-to-know-about-benzoyl-peroxide"),
    ("txa-review-2026", "Tranexamic acid for hyperpigmentation: literature review (PMC12848551)", "https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12848551/"),
    ("txa-jcad", "JCAD 2019: Tranexamic acid for melasma, formulations", "https://jcadonline.com/melasma-august-2019/"),
    ("preg-jabfm", "JABFM: Acne treatment in pregnancy review", "https://www.jabfm.org/content/29/2/254"),
    ("topical-acne-safety", "Akhavan & Bershad 2003: Topical acne drugs - systemic exposure and safety", "https://pubmed.ncbi.nlm.nih.gov/12814337/"),
    ("niacinamide-koh", "Adeline Koh PhD: How much niacinamide should you be using", "https://adelinekohphd.substack.com/p/how-much-niacinamide-should-you-be"),
    ("cu-evigrade", "Evigrade: Copper Tripeptide-1 (GHK-Cu) ingredient page", "https://www.evigrade.com/en/ingredients/copper-peptides-ghk-cu"),
    ("pdrn-evigrade", "Evigrade: PDRN ingredient page (topical evidence weak)", "https://www.evigrade.com/en/ingredients/pdrn"),
    ("pdrn-review", "PDRN in dermatology: systematic review (PMC11845969)", "https://pmc.ncbi.nlm.nih.gov/articles/PMC11845969/"),
    ("exo-dermtimes", "Dermatology Times: Social media mythbusters - exosomes", "https://www.dermatologytimes.com/view/social-media-mythbusters-exosomes-in-skin-care"),
    ("exo-natgeo", "National Geographic: What are exosomes in skincare", "https://www.nationalgeographic.com/health/article/what-are-exosomes-skincare"),
    ("greyb-kbeauty", "GreyB: K-Beauty industry report 2026", "https://greyb.com/resources/reports/k-beauty-industry-report-2026/"),
    ("grazia-kbeauty", "Grazia: Korean skin experts on 2026 K-beauty trends (PDRN 2025, EGF 2026)", "https://graziamagazine.com/us/articles/korean-skin-experts-reveal-which-2026-k-beauty-trends-are-actually-worth-your-money-and-which-are-pure-hype-25497/"),
    ("greyb-jbeauty", "GreyB: Japanese beauty industry report", "https://greyb.com/resources/reports/japanese-beauty-industry-report/"),
    ("cosmetech-jbeauty", "Cosmetech: Why J-beauty is gaining ground", "https://cosmetech.co.in/article/k-beauty-to-j-beauty-the-formulation-shift-reshaping-india-s-premium-skincare"),
    ("lookfantastic-2026", "Personal Care Insights: LookFantastic SS2026 trend report (peptides +79%, retinal +49.6%)", "https://www.personalcareinsights.com/news/spring-summer-beauty-trends-2026.html"),
    ("incos-2026", "in-cosmetics: 2026 skincare and beauty forecast", "https://www.in-cosmetics.com/group/en-gb/blog/trends/2026-skincare-and-beauty-forecast-data-driven-insights.html"),
    ("tj-pdrn", "Т—Ж: лучшие средства 2025, PDRN", "https://t-j.ru/best-of-2025-pdrn/"),
    ("rbc-style", "РБК Стиль: тренды ухода (экзосомы, PDRN)", "https://style.rbc.ru/visionaries/67d96ab39a7947570fb83846"),
    ("mt-pdrn", "The Moscow Times (2026): рынок ПДРН-препаратов в РФ 38,4 млрд руб. за 2025", "https://ru.themoscowtimes.com/2026/05/07/rossiyane-nachali-skupat-spermu-lososya-a194811"),
]

FREQ_LEGEND = {
    "1w": "1 раз в неделю", "2w": "2 раза в неделю", "3w": "3 раза в неделю", "eod": "через день",
    "daily": "1 раз в день", "2xdaily": "2 раза в день", "asneeded": "по необходимости",
}

actives = []

def A(id, nameRu, group, inci, strength, conc, tod, photo, spf, preg, start, mx, step,
      sens, notes, src, patterns=None, highInListOnly=False, evidence="medium", markets=None):
    d = {
        "id": id, "nameRu": nameRu, "group": group, "inci": inci,
        "strength": strength, "concentration": conc, "timeOfDay": tod,
        "photosensitizing": photo, "spfRequired": spf, "pregnancy": preg,
        "startFrequency": start, "maxFrequency": mx, "stepUpWeeks": step,
        "sensitiveSkin": sens, "notes": notes, "sources": src,
        "evidence": evidence,
    }
    if patterns: d["patterns"] = patterns
    if highInListOnly: d["activeOnlyIfAbove1pctLine"] = True
    if markets: d["markets"] = markets
    actives.append(d)

def C(low, med, high, notes, unit="%"):
    return {"unit": unit, "low": low, "medium": med, "high": high, "notes": notes}

# ---------- RETINOIDS ----------
A("retinol", "Ретинол", "retinoid",
  ["Retinol", "Vitamin A", "Encapsulated Retinol", "Retinol (encapsulated)"], 3,
  C(0.1, 0.3, 1.0, "В ЕС с 2025–2027 лимит 0,3% (ретиноловый эквивалент) для лица, 0,05% для тела. 0,3% переносится заметно лучше 1% при сопоставимом эффекте. Инкапсуляция снижает раздражение, но по INCI её не видно."),
  "evening", True, True, "avoid", "2w", "daily", 2,
  "Начинать с 0,1–0,2% или с инкапсулированной формы, 2 раза в неделю, поверх крема («сэндвич»).",
  "Разлагается на свету, поэтому вечером. Шелушение и покраснение в первые 2–6 недель типичны.",
  ["dermnet-retinoids", "ret-conc-pmc", "eu-2024-996", "coslaw-2024-996"], evidence="high", markets=["US", "EU", "KR", "RU"])
A("retinal", "Ретиналь (ретинальдегид)", "retinoid",
  ["Retinal", "Retinaldehyde"], 4,
  C(0.025, 0.05, 0.1, "Примерно в 10 раз «сильнее» ретинола на ту же концентрацию (на шаг ближе к ретиноевой кислоте). 0,1% считается сильной дозой."),
  "evening", True, True, "avoid", "2w", "daily", 3,
  "Не первым ретиноидом при чувствительной коже; начинать с 0,025–0,05%.",
  "Тренд 2025–2026 (поисковые запросы +50%). Переносимость сравнима с ретинолом, ниже, чем у третиноина.",
  ["ret-tolerance", "lookfantastic-2026", "dermnet-retinoids"], evidence="medium", markets=["US", "EU", "KR"])
A("retinyl_esters", "Эфиры ретинола", "retinoid",
  ["Retinyl Palmitate", "Retinyl Acetate", "Retinyl Propionate", "Retinyl Linoleate", "Retinyl Retinoate"], 1,
  C(0.1, 0.5, 2.0, "Слабые: должны превратиться в ретинол, затем в ретиналь и кислоту. В ЕС входят в общий лимит 0,3% RE."),
  "evening", False, True, "avoid", "eod", "daily", 2,
  "Обычно хорошо переносятся; подходят для старта.",
  "Ретинил пальмитат часто стоит в составе как антиоксидант-витамин в малой дозе.",
  ["dermnet-retinoids", "coslaw-2024-996"], evidence="medium")
A("hpr", "Гидроксипинаколон ретиноат (HPR)", "retinoid",
  ["Hydroxypinacolone Retinoate", "Granactive Retinoid", "HPR"], 2,
  C(0.1, 0.5, 1.0, "Эфир ретиноевой кислоты. Продаётся как «мягкий» ретиноид; независимых сравнений с ретинолом мало. Часто идёт смесью (Granactive Retinoid 2% = ~0,2% HPR)."),
  "evening", True, True, "avoid", "2w", "daily", 2,
  "Хороший первый ретиноид для реактивной кожи, но всё равно с постепенным стартом.",
  "Данные о мягкости в основном от производителей сырья.",
  ["dermnet-retinoids"], evidence="low")
A("adapalene", "Адапален", "retinoid",
  ["Adapalene"], 4,
  C(0.1, 0.1, 0.3, "0,1% — безрецептурный в США; 0,3% — рецептурный. В РФ продаётся в аптеках (Дифферин, Клензит)."),
  "evening", True, True, "avoid", "2w", "daily", 3,
  "Сухость и жжение в первые недели; начинать через 2–3 дня, короткими контактами.",
  "Лекарство от акне. Стабилен с бензоилпероксидом (есть готовые комбинации).",
  ["aad-acne-2024", "dermnet-retinoids", "topical-acne-safety"], evidence="high")
A("tretinoin", "Третиноин (ретиноевая кислота)", "retinoid",
  ["Tretinoin", "Retinoic Acid"], 5,
  C(0.025, 0.05, 0.1, "Рецептурный препарат. В косметике ЕС запрещён."),
  "evening", True, True, "avoid", "2w", "daily", 4,
  "Только по назначению врача; при чувствительной коже — 0,025% и редкие нанесения.",
  "Окисляется бензоилпероксидом и разрушается на свету — не наносить вместе.",
  ["dermnet-retinoids", "ret-tolerance", "aad-acne-2024"], evidence="high")
A("bakuchiol", "Бакучиол", "other",
  ["Bakuchiol", "Psoralea Corylifolia Seed Extract"], 1,
  C(0.5, 1.0, 2.0, "В исследовании 0,5% дважды в день ≈ 0,5% ретинола раз в день по морщинам и пигменту, меньше шелушения."),
  "any", False, False, "caution", "daily", "2xdaily", 1,
  "Обычно мягкий, но бывает покраснение и контактный дерматит.",
  "Растительная альтернатива ретинолу, не ретиноид. Неочищенный экстракт псоралеи может содержать фотосенсибилизаторы-псоралены.",
  ["bakuchiol-rct", "labmuffin-bakuchiol"], evidence="medium", markets=["US", "EU", "KR"])

# ---------- AHA ----------
A("glycolic_acid", "Гликолевая кислота", "aha", ["Glycolic Acid"], 4,
  C(5.0, 8.0, 10.0, "Домашний уход: до 10% при pH ≥ 3,5 (CIR/FDA). Салонные пилинги 20–70%. Важны и % и pH: 5% при pH 3 раздражает сильнее, чем 8% при pH 4."),
  "evening", True, True, "ok", "2w", "eod", 2,
  "Самая мелкая молекула AHA — сильнее всех щиплет. При чувствительной коже лучше миндальная или PHA.",
  "Повышает чувствительность к солнцу ещё неделю после отмены (FDA).",
  ["fda-aha", "pc-dict"], evidence="high")
A("lactic_acid", "Молочная кислота", "aha", ["Lactic Acid"], 3,
  C(5.0, 10.0, 12.0, "Отшелушивание от ~5%; ниже 2% и у конца списка — регулятор pH/увлажнитель."),
  "evening", True, True, "ok", "2w", "eod", 2,
  "Мягче гликолевой, дополнительно увлажняет.",
  "Sodium Lactate — увлажнитель, не кислотный пилинг.",
  ["fda-aha", "pc-dict"], highInListOnly=True, evidence="high")
A("mandelic_acid", "Миндальная кислота", "aha", ["Mandelic Acid"], 2,
  C(5.0, 10.0, 15.0, "Крупная молекула, проникает медленнее — меньше жжения."),
  "evening", True, True, "ok", "2w", "eod", 2,
  "Подходит для чувствительной и смуглой кожи, склонной к пигментации.",
  "Популярна в акне-уходе и при постакне.",
  ["pc-dict", "fda-aha"], evidence="medium")
A("fruit_acids", "Фруктовые кислоты (яблочная, винная, лимонная)", "aha",
  ["Malic Acid", "Tartaric Acid", "Citric Acid"], 2,
  C(1.0, 3.0, 5.0, "Лимонная кислота чаще всего — регулятор pH (<0,5%). Считать активом только если стоит выше линии 1%."),
  "evening", True, True, "ok", "2w", "eod", 2,
  "Обычно мягкие в смесях, но суммируются с другими кислотами.",
  "Часто в составе «комплекса AHA» вместе с гликолевой и молочной.",
  ["fda-aha", "pc-dict"], highInListOnly=True, evidence="low")

# ---------- BHA ----------
A("salicylic_acid", "Салициловая кислота (BHA)", "bha", ["Salicylic Acid", "BHA", "Beta Hydroxy Acid"], 3,
  C(0.5, 1.0, 2.0, "В ЕС для несмываемых средств лица до 2% (лосьоны для тела — 0,5%); в США безрецептурно от акне 0,5–2%. Салонные пилинги 20–30%."),
  "any", False, True, "caution", "2w", "daily", 2,
  "Сушит; при сухой коже — 0,5–1% или смываемые формы.",
  "Жирорастворима, чистит поры — первый выбор при чёрных точках. Не путать с Ethylhexyl Salicylate (это УФ-фильтр).",
  ["dermnet-sa", "cosing", "pc-dict"], evidence="high")
A("betaine_salicylate", "Бетаин салицилат", "bha", ["Betaine Salicylate"], 2,
  C(1.0, 2.0, 4.0, "~4% бетаина салицилата ≈ 1% салициловой кислоты (по данным производителей)."),
  "any", False, True, "caution", "eod", "daily", 2,
  "Мягче салициловой; частый К-бьюти вариант BHA.",
  "Эффективность по сравнению с салициловой изучена слабо.",
  ["pc-dict"], evidence="low", markets=["KR"])
A("willow_bark", "Экстракт коры ивы", "bha", ["Salix Alba (Willow) Bark Extract", "Salix Alba Bark Extract", "Salix Nigra Bark Extract"], 1,
  None, "any", False, False, "ok", "daily", "daily", 1,
  "Мягкий; редко раздражает.",
  "Содержит салицин, а не салициловую кислоту; отшелушивающий эффект слабый.",
  ["pc-dict"], evidence="low")
A("lha", "Липогидроксикислота (LHA)", "bha", ["Capryloyl Salicylic Acid", "LHA"], 2,
  C(0.1, 0.3, 1.0, "Работает в низких концентрациях; часто 0,1–0,5% (La Roche-Posay)."),
  "any", False, True, "caution", "eod", "daily", 2,
  "Мягче салициловой, но тоже может сушить.",
  "Производное салициловой кислоты, медленное поверхностное отшелушивание.",
  ["pc-dict"], evidence="low", markets=["EU"])

# ---------- PHA ----------
A("gluconolactone", "Глюконолактон (PHA)", "pha", ["Gluconolactone", "PHA"], 1,
  C(2.0, 5.0, 10.0, "Отшелушивание от ~4–5%; в малых дозах — увлажнитель/хелатор."),
  "any", False, True, "ok", "eod", "daily", 1,
  "Хороший вариант кислоты для чувствительной кожи и розацеа.",
  "Крупная молекула, почти не щиплет, удерживает влагу.",
  ["pc-dict"], evidence="medium", markets=["KR", "EU"])
A("lactobionic_acid", "Лактобионовая/мальтобионовая кислота (PHA)", "pha", ["Lactobionic Acid", "Maltobionic Acid"], 1,
  C(2.0, 5.0, 10.0, "Работают как мягкие отшелушивающие и антиоксиданты."),
  "any", False, True, "ok", "eod", "daily", 1,
  "Подходят чувствительной коже.",
  "Часто в паре с глюконолактоном.",
  ["pc-dict"], evidence="low")

# ---------- AZELAIC ----------
A("azelaic_acid", "Азелаиновая кислота", "azelaic", ["Azelaic Acid"], 3,
  C(5.0, 10.0, 20.0, "Косметика 5–10%; лекарства 15% (гель, розацеа) и 20% (крем, акне)."),
  "any", False, True, "ok", "eod", "2xdaily", 2,
  "Покалывание и зуд в первые 1–2 недели — частая и обычно проходящая реакция.",
  "Помогает при акне, розацеа и пигментации. Безопасна при беременности.",
  ["dermnet-azelaic", "preg-jabfm"], evidence="high")
A("azeloyl_glycinate", "Азелоилглицинат калия", "azelaic", ["Potassium Azeloyl Diglycinate", "Azeloglicina"], 1,
  C(3.0, 5.0, 10.0, "Водорастворимое производное; данных меньше, чем по азелаиновой кислоте."),
  "any", False, False, "ok", "daily", "2xdaily", 1,
  "Мягче азелаиновой кислоты.",
  "Себорегуляция и выравнивание тона; доказательная база слабее.",
  ["pc-dict"], evidence="low")

# ---------- VITAMIN C ----------
A("vitc_laa", "Аскорбиновая кислота (чистый витамин C)", "vitc", ["Ascorbic Acid", "L-Ascorbic Acid", "Vitamin C"], 3,
  C(5.0, 10.0, 20.0, "Нужен pH < 3,5. Выше 20% проникновение не растёт, а раздражение — да. Если стоит у конца списка — это стабилизатор, не актив."),
  "morning", False, True, "ok", "eod", "daily", 2,
  "При чувствительной коже — 5–10% или производные.",
  "Окисляется (темнеет до оранжевого) — такой флакон лучше заменить. Усиливает защиту SPF, но не заменяет его.",
  ["pinnell-laa", "pc-dict"], highInListOnly=True, evidence="high")
A("vitc_sap", "Аскорбилфосфат натрия (SAP)", "vitc", ["Sodium Ascorbyl Phosphate"], 1,
  C(1.0, 3.0, 5.0, "~5% показало противоакне-эффект."),
  "any", False, False, "ok", "daily", "2xdaily", 1,
  "Хорошо переносится.",
  "Стабильная форма, работает при нейтральном pH.",
  ["pc-dict"], evidence="medium")
A("vitc_map", "Аскорбилфосфат магния (MAP)", "vitc", ["Magnesium Ascorbyl Phosphate"], 1,
  C(1.0, 3.0, 10.0, "Мягкое осветление при 3–10%."),
  "any", False, False, "ok", "daily", "2xdaily", 1,
  "Хорошо переносится.",
  "Стабильная форма; уровень витамина C в коже повышает слабо.",
  ["pc-dict", "pinnell-laa"], evidence="low")
A("vitc_ag", "Аскорбилглюкозид", "vitc", ["Ascorbyl Glucoside"], 1,
  C(1.0, 2.0, 5.0, "В Корее 2% — порог «функциональной» отбеливающей косметики."),
  "any", False, False, "ok", "daily", "2xdaily", 1,
  "Подходит чувствительной коже.",
  "Популярен в K- и J-beauty.",
  ["pc-dict"], evidence="low", markets=["KR", "JP"])
A("vitc_ethyl", "Этиласкорбиновая кислота", "vitc", ["3-O-Ethyl Ascorbic Acid", "Ethyl Ascorbic Acid", "Ethyl Ascorbate"], 2,
  C(1.0, 5.0, 15.0, "Стабильная форма; часто 2–15%."),
  "any", False, False, "ok", "daily", "2xdaily", 1,
  "Чаще мягкая, но при высоких % возможно покалывание.",
  "Популярна в азиатских сыворотках.",
  ["pc-dict"], evidence="low", markets=["KR", "JP", "CN"])
A("vitc_thd", "Тетрагексилдецил аскорбат (THD)", "vitc", ["Tetrahexyldecyl Ascorbate", "Ascorbyl Tetraisopalmitate", "Ascorbyl Palmitate"], 1,
  C(1.0, 5.0, 20.0, "Жирорастворимая форма; аскорбилпальмитат обычно < 0,5% как антиоксидант формулы."),
  "any", False, False, "ok", "daily", "2xdaily", 1,
  "Обычно не щиплет.",
  "Эффективность для кожи изучена мало.",
  ["pc-dict"], evidence="low")

# ---------- NIACINAMIDE ----------
A("niacinamide", "Ниацинамид (витамин B3)", "niacinamide", ["Niacinamide", "Nicotinamide", "Vitamin B3"], 1,
  C(2.0, 5.0, 10.0, "Большинство исследований — 2–5%. 10% и выше чаще дают покраснение и покалывание; пользы сверх 5% почти не доказано. В Корее 2–5% — «функциональное» осветление."),
  "any", False, False, "ok", "daily", "2xdaily", 1,
  "При реактивной коже выбирать 2–5%, а не 10–20%.",
  "Укрепляет барьер, снижает жирность и пигментацию. Совместим почти со всем.",
  ["niacinamide-koh", "pc-dict", "labmuffin"], evidence="high")

# ---------- PEPTIDES ----------
A("matrixyl", "Пальмитоил пентапептид-4 (Matrixyl)", "peptides", ["Palmitoyl Pentapeptide-4", "Palmitoyl Pentapeptide-3", "Matrixyl"], 1,
  C(None, None, None, "Работает в ppm (миллионных долях); в составе как раствор 2–8%. Процент по INCI оценить нельзя.", unit="ppm"),
  "any", False, False, "ok", "daily", "2xdaily", 1,
  "Хорошо переносится.", "Сигнальный пептид, стимулирует коллаген (данные в основном производителей).",
  ["pc-dict"], evidence="low")
A("matrixyl3000", "Пальмитоил трипептид-1 + тетрапептид-7 (Matrixyl 3000)", "peptides", ["Palmitoyl Tripeptide-1", "Palmitoyl Tetrapeptide-7", "Palmitoyl Oligopeptide"], 1,
  C(None, None, None, "Сырьё вводят 3–8%, сам пептид — ppm.", unit="ppm"),
  "any", False, False, "ok", "daily", "2xdaily", 1,
  "Хорошо переносится.", "Сигнальные пептиды.", ["pc-dict"], evidence="low")
A("argireline", "Ацетил гексапептид-8 (Аргирелин)", "peptides", ["Acetyl Hexapeptide-8", "Acetyl Hexapeptide-3", "Argireline", "Acetyl Octapeptide-3", "SNAP-8"], 1,
  C(2.0, 5.0, 10.0, "Проценты на упаковке обычно про раствор сырья, а не чистый пептид."),
  "any", False, False, "ok", "daily", "2xdaily", 1,
  "Хорошо переносится.", "«Ботокс-подобный» эффект на коже выражен слабо.", ["pc-dict"], evidence="low")
A("syn_ake", "Пептиды-миорелаксанты (Syn-Ake и др.)", "peptides", ["Dipeptide Diaminobutyroyl Benzylamide Diacetate", "Syn-Ake", "Pentapeptide-18", "Leuphasyl"], 1,
  C(None, None, None, "Процент по INCI не определить.", unit="ppm"),
  "any", False, False, "ok", "daily", "2xdaily", 1,
  "Хорошо переносится.", "Доказательства эффекта слабые.", ["pc-dict"], evidence="low")
A("peptides_other", "Прочие пептиды", "peptides", ["Palmitoyl Tripeptide-5", "Palmitoyl Tripeptide-38", "Acetyl Tetrapeptide-9", "Tripeptide-1", "Oligopeptide", "Peptide Complex"],
  1, C(None, None, None, "Сигнальные/транспортные пептиды обычно в ppm.", unit="ppm"),
  "any", False, False, "ok", "daily", "2xdaily", 1,
  "Хорошо переносится.", "Тренд №1 2025 по поисковым запросам; эффекты скромные, но безопасные.",
  ["pc-dict", "lookfantastic-2026"], patterns=[r"peptide-\d+", r"\bpeptide\b"], evidence="low")

# ---------- COPPER ----------
A("copper_peptides", "Медные пептиды (GHK-Cu)", "copper_peptides", ["Copper Tripeptide-1", "GHK-Cu", "Copper Peptide", "Copper Peptides"], 2,
  C(0.05, 0.5, 1.0, "Синие сыворотки ~1% (The Ordinary «Buffet + Copper»). Высокие дозы теоретически раздражают."),
  "any", False, False, "caution", "eod", "daily", 2,
  "Иногда покраснение; начинать через день.",
  "Заживление и ремоделирование; в кожу проникает плохо. Конфликт с кислотами и чистым витамином C — теоретический.",
  ["cu-evigrade", "pc-dict"], evidence="low")

# ---------- BPO / SULFUR ----------
A("benzoyl_peroxide", "Бензоилпероксид", "bpo", ["Benzoyl Peroxide"], 4,
  C(2.5, 5.0, 10.0, "2,5%, 5% и 10% примерно одинаково эффективны; 10% сильнее сушат и раздражают. Начинать с 2,5%."),
  "any", False, False, "ok", "eod", "2xdaily", 2,
  "Сухость и шелушение; можно короткий контакт 1–5 мин и смыть.",
  "Отбеливает ткани и волосы. Окисляет третиноин и чистый витамин C.",
  ["dermnet-bpo", "bpo-jdd", "acneorg-bpo", "aad-acne-2024", "preg-jabfm"], evidence="high")
A("sulfur", "Сера", "sulfur", ["Sulfur", "Sulphur", "Colloidal Sulfur"], 3,
  C(3.0, 5.0, 10.0, "В США безрецептурно от акне 3–10%."),
  "evening", False, False, "ok", "eod", "daily", 2,
  "Сушит, специфический запах; точечно или маской.",
  "Подсушивает воспаления, помогает при себорее и розацеа.",
  ["pc-dict", "preg-jabfm"], evidence="medium")

# ---------- BRIGHTENING ----------
A("tranexamic_acid", "Транексамовая кислота", "brightening", ["Tranexamic Acid", "Cetyl Tranexamate HCl", "Cetyl Tranexamate Mesylate"], 1,
  C(2.0, 3.0, 5.0, "В исследованиях мелазмы 2–5%, 8–12 недель."),
  "any", False, True, "caution", "daily", "2xdaily", 1,
  "Обычно хорошо переносится, раздражает меньше гидрохинона.",
  "Тренд K-beauty и J-beauty. Данных о беременности для местного применения нет.",
  ["txa-review-2026", "txa-jcad", "greyb-kbeauty"], evidence="medium", markets=["KR", "JP", "US"])
A("alpha_arbutin", "Альфа-арбутин", "brightening", ["Alpha-Arbutin", "Alpha Arbutin"], 1,
  C(0.5, 1.0, 2.0, "ЕС: не более 2% в средствах для лица и 0,5% для тела."),
  "any", False, True, "caution", "daily", "2xdaily", 1,
  "Хорошо переносится.",
  "Может выделять гидрохинон в малых количествах — отсюда лимиты.",
  ["eu-2024-996", "coslaw-2024-996"], evidence="medium")
A("arbutin", "Арбутин (бета)", "brightening", ["Arbutin", "Beta-Arbutin"], 1,
  C(1.0, 3.0, 7.0, "ЕС: не более 7% для лица. В Корее 2–5% — «функциональное» осветление."),
  "any", False, True, "caution", "daily", "2xdaily", 1,
  "Хорошо переносится.", "Слабее альфа-арбутина.", ["eu-2024-996", "coslaw-2024-996"], evidence="medium")
A("kojic_acid", "Койевая кислота", "brightening", ["Kojic Acid", "Kojic Dipalmitate"], 2,
  C(0.5, 1.0, 1.0, "ЕС: не более 1% (лицо и руки). Дипальмитат мягче и стабильнее."),
  "any", False, True, "caution", "eod", "daily", 2,
  "Возможна контактная аллергия; патч-тест обязателен.",
  "Классика J-beauty (побочный продукт сакэ/коджи).",
  ["eu-2024-996", "coslaw-2024-996", "greyb-jbeauty"], evidence="medium", markets=["JP", "KR", "US"])
A("licorice", "Экстракт солодки (глабридин)", "brightening", ["Glycyrrhiza Glabra (Licorice) Root Extract", "Glycyrrhiza Glabra Root Extract", "Glycyrrhiza Uralensis Root Extract", "Glabridin"], 1,
  None, "any", False, False, "ok", "daily", "2xdaily", 1,
  "Мягкий, успокаивает.", "Осветление и противовоспалительное действие; доза в экстрактах неизвестна.",
  ["pc-dict"], evidence="low")
A("butylresorcinol", "4-бутилрезорцинол", "brightening", ["4-Butylresorcinol", "Rucinol"], 2,
  C(0.1, 0.3, 0.5, "Сильный ингибитор тирозиназы при низких %."),
  "any", False, True, "caution", "eod", "2xdaily", 2,
  "Возможно раздражение; патч-тест.", "Один из самых эффективных безрецептурных осветлителей.",
  ["pc-dict"], evidence="medium", markets=["EU", "KR", "JP"])
A("hexylresorcinol", "Гексилрезорцинол", "brightening", ["Hexylresorcinol"], 2,
  C(0.5, 1.0, 1.0, "Обычно 0,5–1%."),
  "any", False, True, "caution", "eod", "2xdaily", 2,
  "Иногда раздражает.", "Осветление и антиоксидантное действие.", ["pc-dict"], evidence="low")
A("glutathione", "Глутатион", "brightening", ["Glutathione"], 1,
  None, "any", False, False, "ok", "daily", "2xdaily", 1,
  "Мягкий.", "Популярен в Азии; местный эффект на пигмент изучен слабо.", ["pc-dict"], evidence="low", markets=["KR", "CN"])
A("cysteamine", "Цистеамин", "brightening", ["Cysteamine HCl", "Cysteamine Hydrochloride"], 4,
  C(5.0, 5.0, 5.0, "Обычно 5% с коротким контактом 15–30 мин и смыванием."),
  "evening", False, True, "caution", "daily", "daily", 2,
  "Часто жжение и покраснение; строго по инструкции.",
  "Используется при мелазме; резкий запах.", ["pc-dict"], evidence="medium", markets=["EU"])

# ---------- SOOTHING ----------
A("centella", "Центелла азиатская (мадекассосид, азиатикосид)", "soothing",
  ["Centella Asiatica Extract", "Centella Asiatica Leaf Extract", "Madecassoside", "Asiaticoside", "Asiatic Acid", "Madecassic Acid", "Cica", "Hydrocotyl"], 1,
  None, "any", False, False, "ok", "daily", "2xdaily", 1,
  "Хорошо переносится; редко — аллергия.", "Главный «цика»-ингредиент K-beauty: успокаивает и помогает заживлению.",
  ["pc-dict", "greyb-kbeauty"], patterns=[r"centella", r"madecass", r"asiatic"], evidence="medium", markets=["KR", "RU", "EU"])
A("panthenol", "Пантенол (провитамин B5)", "soothing", ["Panthenol", "D-Panthenol", "Dexpanthenol", "Provitamin B5"], 1,
  C(1.0, 2.0, 5.0, "Обычно 1–5%."),
  "any", False, False, "ok", "daily", "2xdaily", 1,
  "Подходит почти всем.", "Успокаивает и восстанавливает барьер.", ["pc-dict", "greyb-kbeauty"], evidence="medium")
A("allantoin", "Аллантоин", "soothing", ["Allantoin"], 1,
  C(0.1, 0.5, 2.0, "Обычно 0,1–2%."), "any", False, False, "ok", "daily", "2xdaily", 1,
  "Подходит почти всем.", "Смягчает и успокаивает.", ["pc-dict"], evidence="low")
A("mugwort", "Полынь (мугворт)", "soothing", ["Artemisia Princeps Extract", "Artemisia Princeps Leaf Extract", "Artemisia Vulgaris Extract", "Artemisia Annua Extract", "Artemisia Capillaris Extract"], 1,
  None, "any", False, False, "ok", "daily", "2xdaily", 1,
  "При аллергии на сложноцветные (амброзия, ромашка) — осторожно.",
  "K-beauty тренд для успокоения; доказательства в основном лабораторные.",
  ["pc-dict"], patterns=[r"artemisia"], evidence="low", markets=["KR"])
A("heartleaf", "Хауттюния (heartleaf)", "soothing", ["Houttuynia Cordata Extract", "Houttuynia Cordata Leaf Extract"], 1,
  None, "any", False, False, "ok", "daily", "2xdaily", 1,
  "Обычно мягкая.", "K-beauty успокаивающий экстракт для кожи с акне.",
  ["pc-dict"], evidence="low", markets=["KR"])
A("bisabolol", "Бисаболол", "soothing", ["Bisabolol", "Alpha-Bisabolol"], 1,
  C(0.1, 0.5, 1.0, None), "any", False, False, "ok", "daily", "2xdaily", 1,
  "Подходит почти всем.", "Компонент ромашки, противовоспалительный.", ["pc-dict"], evidence="low")
A("beta_glucan", "Бета-глюкан", "soothing", ["Beta-Glucan", "Oat Beta Glucan", "Sodium Carboxymethyl Beta-Glucan", "Schizophyllan"], 1,
  None, "any", False, False, "ok", "daily", "2xdaily", 1,
  "Подходит почти всем.", "Увлажняет и успокаивает; тренд 2026 по данным Spate.", ["pc-dict", "incos-2026"], evidence="low")
A("oat", "Коллоидная овсянка", "soothing", ["Avena Sativa Kernel Flour", "Avena Sativa (Oat) Kernel Flour", "Colloidal Oatmeal", "Avena Sativa Kernel Extract"], 1,
  None, "any", False, False, "ok", "daily", "2xdaily", 1,
  "Подходит при атопии; редко аллергия.", "Успокаивает зуд и сухость.", ["pc-dict"], evidence="medium")
A("glycyrrhizate", "Глицирризинат дикалия", "soothing", ["Dipotassium Glycyrrhizate", "Ammonium Glycyrrhizate"], 1,
  C(0.1, 0.3, 0.5, None), "any", False, False, "ok", "daily", "2xdaily", 1,
  "Подходит почти всем.", "Противовоспалительный компонент солодки, частый в J-beauty.", ["pc-dict"], evidence="low", markets=["JP", "KR"])
A("ectoin", "Эктоин", "soothing", ["Ectoin"], 1,
  C(0.5, 1.0, 2.0, None), "any", False, False, "ok", "daily", "2xdaily", 1,
  "Подходит почти всем.", "Защищает клетки от стресса и обезвоживания; популярен в ЕС.", ["pc-dict"], evidence="low", markets=["EU"])

# ---------- HYDRATING ----------
A("hyaluronic_acid", "Гиалуроновая кислота", "hydrating",
  ["Sodium Hyaluronate", "Hyaluronic Acid", "Hydrolyzed Hyaluronic Acid", "Hydrolyzed Sodium Hyaluronate", "Sodium Acetylated Hyaluronate", "Sodium Hyaluronate Crosspolymer", "Potassium Hyaluronate"], 1,
  C(0.1, 0.5, 2.0, "Обычно 0,1–2%; выше — липкость. «2%» на этикетке часто означает 2% раствора."),
  "any", False, False, "ok", "daily", "2xdaily", 1,
  "Подходит почти всем.", "Увлажнитель; не «нейтрализует» кислоты и ретиноиды.", ["pc-dict", "labmuffin"], evidence="medium")
A("polyglutamic_acid", "Полиглутаминовая кислота", "hydrating", ["Polyglutamic Acid", "Sodium Polyglutamate"], 1,
  C(0.1, 0.5, 1.0, None), "any", False, False, "ok", "daily", "2xdaily", 1,
  "Подходит почти всем.", "Плёнкообразующий увлажнитель, K-beauty.", ["pc-dict"], evidence="low", markets=["KR"])
A("urea", "Мочевина", "hydrating", ["Urea", "Carbamide"], 2,
  C(5.0, 10.0, 20.0, "До 10% — увлажнение; 10–20% — заметное отшелушивание; 30–40% — кератолитик для пяток и ногтей."),
  "any", False, False, "ok", "daily", "2xdaily", 1,
  "До 5% подходит при атопии; выше 10% может щипать на повреждённой коже.",
  "При >10% учитывать как отшелушивающий актив.", ["pc-dict", "incos-2026"], evidence="high", markets=["EU", "JP", "RU"])
A("snail_mucin", "Муцин улитки", "hydrating", ["Snail Secretion Filtrate", "Snail Mucin", "Snail Mucus Extract"], 1,
  None, "any", False, False, "ok", "daily", "2xdaily", 1,
  "Обычно мягкий; при аллергии на моллюсков — осторожно.", "Увлажнение и заживление; часто стоит первым (до 90%).",
  ["pc-dict"], evidence="low", markets=["KR"])
A("collagen", "Коллаген гидролизованный", "hydrating", ["Hydrolyzed Collagen", "Soluble Collagen", "Collagen"], 1,
  None, "any", False, False, "ok", "daily", "2xdaily", 1,
  "Подходит почти всем.", "Плёнкообразующий увлажнитель; в кожу как коллаген не встраивается.", ["pc-dict"], evidence="low")

# ---------- BARRIER ----------
A("ceramides", "Керамиды", "barrier",
  ["Ceramide NP", "Ceramide AP", "Ceramide EOP", "Ceramide NS", "Ceramide AS", "Ceramide EOS", "Ceramide NG", "Ceramide 1", "Ceramide 3", "Ceramide 6 II", "Hydroxypropyl Bispalmitamide MEA", "Cetyl-PG Hydroxyethyl Palmitamide"], 1,
  C(0.1, 0.5, 1.0, "Обычно < 1%; важнее комбинация с холестерином и жирными кислотами."),
  "any", False, False, "ok", "daily", "2xdaily", 1,
  "Подходит почти всем.", "Восстановление барьера; хорошая «подушка» под ретиноиды и кислоты.", ["pc-dict", "incos-2026"],
  patterns=[r"ceramide"], evidence="medium")
A("barrier_lipids", "Холестерин, фитосфингозин, жирные кислоты", "barrier", ["Cholesterol", "Phytosphingosine", "Sphingolipids", "Linoleic Acid"], 1,
  None, "any", False, False, "ok", "daily", "2xdaily", 1,
  "Подходит почти всем.", "Липиды барьера; работают в паре с керамидами.", ["pc-dict"], evidence="medium")
A("squalane", "Сквалан", "barrier", ["Squalane"], 1,
  None, "any", False, False, "ok", "daily", "2xdaily", 1,
  "Подходит почти всем, не комедогенен.", "Эмолент, смягчает и уменьшает потерю влаги.", ["pc-dict"], evidence="medium")

# ---------- ANTIOXIDANTS ----------
A("vitamin_e", "Витамин E (токоферол)", "antioxidant", ["Tocopherol", "Tocopheryl Acetate", "Vitamin E"], 1,
  C(0.1, 0.5, 1.0, "Часто < 0,5% как стабилизатор масел."), "morning", False, False, "ok", "daily", "2xdaily", 1,
  "Ацетат иногда вызывает аллергию.", "Усиливает витамин C (связка C+E+феруловая).", ["pc-dict"], highInListOnly=True, evidence="medium")
A("ferulic_acid", "Феруловая кислота", "antioxidant", ["Ferulic Acid"], 1,
  C(0.2, 0.5, 1.0, "Классическая связка: 15% L-AA + 1% токоферол + 0,5% феруловая."), "morning", False, False, "ok", "daily", "2xdaily", 1,
  "Подходит почти всем.", "Стабилизирует витамин C и E.", ["pc-dict"], evidence="medium")
A("resveratrol", "Ресвератрол", "antioxidant", ["Resveratrol"], 1, C(0.5, 1.0, 1.0, None), "any", False, False, "ok", "daily", "2xdaily", 1,
  "Подходит почти всем.", "Антиоксидант; клинических данных мало.", ["pc-dict"], evidence="low")
A("green_tea", "Зелёный чай (EGCG)", "antioxidant", ["Camellia Sinensis Leaf Extract", "Camellia Sinensis Leaf Water", "Epigallocatechin Gallate", "EGCG"], 1,
  None, "any", False, False, "ok", "daily", "2xdaily", 1, "Подходит почти всем.", "Антиоксидант и противовоспалительный.", ["pc-dict"], evidence="low", markets=["KR", "JP"])
A("coq10", "Коэнзим Q10", "antioxidant", ["Ubiquinone", "Coenzyme Q10"], 1, None, "any", False, False, "ok", "daily", "2xdaily", 1,
  "Подходит почти всем.", "Антиоксидант, популярен в РФ и ЕС.", ["pc-dict"], evidence="low", markets=["EU", "RU"])
A("astaxanthin", "Астаксантин", "antioxidant", ["Astaxanthin", "Haematococcus Pluvialis Extract"], 1, None, "any", False, False, "ok", "daily", "2xdaily", 1,
  "Подходит почти всем; окрашивает средство в красный.", "Антиоксидант, популярен в J-beauty.", ["pc-dict"], evidence="low", markets=["JP"])
A("ginseng", "Женьшень", "antioxidant", ["Panax Ginseng Root Extract", "Panax Ginseng Berry Extract", "Ginsenosides"], 1, None, "any", False, False, "ok", "daily", "2xdaily", 1,
  "Подходит почти всем.", "Классика корейской «хан-бан» косметики.", ["pc-dict"], evidence="low", markets=["KR"])
A("propolis", "Прополис", "antioxidant", ["Propolis Extract", "Propolis Cera"], 2, None, "any", False, False, "ok", "daily", "2xdaily", 1,
  "Частый аллерген (контактный дерматит); при аллергии на продукты пчёл — избегать.", "K-beauty: успокоение, антиоксидант, для кожи с акне.",
  ["pc-dict"], evidence="low", markets=["KR"])
A("caffeine", "Кофеин", "antioxidant", ["Caffeine"], 1, C(1.0, 3.0, 5.0, None), "any", False, False, "ok", "daily", "2xdaily", 1,
  "Подходит почти всем.", "Временно уменьшает отёчность под глазами.", ["pc-dict"], evidence="low")

# ---------- ENZYMES / PHYSICAL ----------
A("enzymes", "Энзимы (папаин, бромелайн, протеазы)", "enzyme", ["Papain", "Bromelain", "Subtilisin", "Protease", "Lipase"], 2,
  None, "any", False, True, "ok", "1w", "2w", 2,
  "Мягче кислот, но тоже могут раздражать; держать по инструкции.", "Энзимные пудры и маски K-/J-beauty.", ["pc-dict"], evidence="low", markets=["JP", "KR"])
A("spicules", "Спикулы (гидролизованная губка)", "exfoliant_physical", ["Hydrolyzed Sponge", "Spongilla Lacustris Powder", "Sponge Spicules", "Spicule"], 3,
  C(None, None, None, "Сила задаётся количеством спикул (например «100 / 300 / 500 shots»), а не %."),
  "evening", False, True, "caution", "1w", "2w", 2,
  "При розацеа, акне в фазе воспаления и тонкой коже — не использовать.",
  "Тренд K-beauty 2025 («reedle shot»): микроповреждения усиливают проникновение остальных средств, а значит и их раздражение.",
  ["rbc-style", "tj-pdrn"], patterns=[r"sponge", r"spicul"], evidence="low", markets=["KR", "RU"])
A("scrub", "Скраб (механические частицы)", "exfoliant_physical", ["Jojoba Esters", "Walnut Shell Powder", "Juglans Regia Shell Powder", "Prunus Armeniaca Seed Powder", "Perlite", "Oryza Sativa Bran Powder"], 2,
  None, "any", False, False, "ok", "1w", "2w", 2,
  "Крупные острые частицы травмируют кожу; при чувствительной коже — не использовать.",
  "Не сочетать в один вечер с кислотами и ретиноидами.", ["pc-dict"], evidence="low")

# ---------- SPF ----------
A("spf_mineral", "Минеральные фильтры (оксид цинка, диоксид титана)", "spf_filter", ["Zinc Oxide", "Titanium Dioxide", "CI 77947", "CI 77891"], 1,
  C(5.0, 10.0, 25.0, "ЕС: каждый до 25%. Оксид цинка — широкий UVA/UVB."),
  "morning", False, False, "ok", "daily", "2xdaily", 0,
  "Лучший выбор для реактивной кожи и при беременности.",
  "CI 77891 у конца списка — краситель, а не фильтр.", ["aad-sunscreen", "cosing"], evidence="high")
A("spf_organic", "Органические (химические) УФ-фильтры", "spf_filter",
  ["Ethylhexyl Methoxycinnamate", "Octinoxate", "Butyl Methoxydibenzoylmethane", "Avobenzone", "Bis-Ethylhexyloxyphenol Methoxyphenyl Triazine", "Bemotrizinol", "Tinosorb S",
   "Methylene Bis-Benzotriazolyl Tetramethylbutylphenol", "Tinosorb M", "Diethylamino Hydroxybenzoyl Hexyl Benzoate", "Uvinul A Plus", "Ethylhexyl Triazone",
   "Drometrizole Trisiloxane", "Terephthalylidene Dicamphor Sulfonic Acid", "Octocrylene", "Homosalate", "Ethylhexyl Salicylate", "Octisalate", "Benzophenone-3", "Oxybenzone",
   "Phenylbenzimidazole Sulfonic Acid", "Diethylhexyl Butamido Triazone", "Polysilicone-15"], 1,
  None, "morning", False, False, "ok", "daily", "2xdaily", 0,
  "Изредка жжение у глаз или аллергия (чаще на октокрилен, оксибензон).",
  "Лимиты по каждому фильтру в Annex VI ЕС. Ethylhexyl Salicylate — фильтр, не кислота.", ["aad-sunscreen", "cosing"], evidence="high")

# ---------- OTHER / TRENDY ----------
A("pdrn", "PDRN (полидезоксирибонуклеотид, ДНК лосося)", "other", ["Sodium DNA", "Polydeoxyribonucleotide", "PDRN", "Hydrolyzed DNA", "DNA", "Salmon DNA", "Polynucleotide"], 1,
  C(None, None, None, "В кремах обычно 0,01–1% (часто не раскрывается)."),
  "any", False, False, "caution", "daily", "2xdaily", 1,
  "Обычно хорошо переносится; при аллергии на рыбу — осторожно.",
  "Хит 2025 (K-beauty, РФ). Инъекционные данные сильнее, данные для кремов — слабые.",
  ["pdrn-review", "pdrn-evigrade", "tj-pdrn", "mt-pdrn", "greyb-kbeauty"], evidence="low", markets=["KR", "RU", "US"])
A("exosomes", "Экзосомы", "other", ["Exosomes", "Rosa Damascena Callus Exosomes", "Bacillus Ferment Exosomes", "Human Adipocyte Conditioned Media Extract", "Conditioned Media"], 1,
  None, "any", False, False, "caution", "daily", "daily", 1,
  "Данных о безопасности мало; осторожно при беременности и реактивной коже.",
  "Тренд 2025–2026. Ни одного одобренного FDA продукта; в ЕС ингредиенты человеческого происхождения запрещены.",
  ["exo-dermtimes", "exo-natgeo", "greyb-kbeauty"], patterns=[r"exosom", r"conditioned media"], evidence="low", markets=["KR", "US", "RU"])
A("egf", "EGF (фактор роста эпидермиса)", "other", ["sh-Oligopeptide-1", "rh-Oligopeptide-1", "Human Oligopeptide-1", "EGF", "sh-Polypeptide-1"], 1,
  C(None, None, None, "Обычно ppm.", unit="ppm"),
  "any", False, False, "caution", "daily", "daily", 1,
  "Обычно хорошо переносится.",
  "Прогноз K-beauty на 2026. Теоретический вопрос о стимуляции роста клеток не закрыт; доказательства слабые.",
  ["grazia-kbeauty", "greyb-kbeauty"], evidence="low", markets=["KR"])
A("ferments", "Ферменты (галактомисис, сакэ, бифидо)", "other",
  ["Galactomyces Ferment Filtrate", "Saccharomyces Ferment Filtrate", "Bifida Ferment Lysate", "Lactobacillus Ferment", "Rice Ferment Filtrate (Sake)", "Aspergillus Ferment", "Saccharomyces/Rice Ferment Filtrate"], 1,
  None, "any", False, False, "ok", "daily", "2xdaily", 1,
  "Обычно мягкие; редко реакция.", "Основа J-beauty (сакэ, коджи) и K-beauty эссенций; часто стоят первыми.",
  ["greyb-jbeauty", "cosmetech-jbeauty"], patterns=[r"ferment"], evidence="low", markets=["JP", "KR"])
A("zinc_pca", "Цинк PCA", "other", ["Zinc PCA", "Zinc Gluconate", "Zinc Sulfate"], 1,
  C(0.5, 1.0, 1.0, "Обычно ~1%."), "any", False, False, "ok", "daily", "2xdaily", 1,
  "Подходит почти всем.", "Снижает жирность и воспаление; хорошо с ниацинамидом.", ["pc-dict"], evidence="low")
A("hypochlorous_acid", "Гипохлорная кислота", "other", ["Hypochlorous Acid"], 1,
  None, "any", False, False, "ok", "daily", "2xdaily", 1,
  "Подходит почти всем, щадящий антисептик.", "Тренд 2026 по данным Spate; спреи для кожи с акне и после процедур.", ["incos-2026"], evidence="low", markets=["US"])
A("tea_tree", "Масло чайного дерева", "other", ["Melaleuca Alternifolia (Tea Tree) Leaf Oil", "Melaleuca Alternifolia Leaf Oil", "Tea Tree Oil"], 2,
  C(1.0, 3.0, 5.0, "В исследованиях акне 5%; окислённое масло — сильный аллерген."), "any", False, False, "caution", "eod", "daily", 1,
  "Частый аллерген; не наносить неразбавленным.", "Слабее бензоилпероксида, но мягче.", ["pc-dict"], evidence="low")
A("adenosine", "Аденозин", "other", ["Adenosine"], 1,
  C(0.04, 0.04, 0.1, "В Корее 0,04% — порог «функциональной» антивозрастной косметики."), "any", False, False, "ok", "daily", "2xdaily", 1,
  "Подходит почти всем.", "Почти в каждом корейском креме «против морщин»; эффект мягкий.", ["pc-dict"], evidence="low", markets=["KR"])

# ---------------- PAIRS ----------------
pairs = []
def P(a, b, verdict, why, conf, cond=None, src=None, myth=False):
    d = {"a": a, "b": b, "verdict": verdict, "why": why, "confidence": conf}
    if cond: d["condition"] = cond
    d["sources"] = src or []
    if myth: d["myth"] = True
    pairs.append(d)

S_MIX = ["labmuffin", "fb-mixing"]
# retinoid
P("retinoid", "retinoid", "avoid_same_time", "Два ретиноида сразу не усиливают эффект, но суммируют раздражение.", "high", None, ["dermnet-retinoids"])
P("retinoid", "aha", "alternate_days", "Оба отшелушивают и сушат; вместе резко растёт раздражение.", "high",
  "Опытным с крепкой кожей допустимо в один вечер при низких % (AHA до 5%, ретинол до 0,3%).", ["dermnet-retinoids", "fda-aha"])
P("retinoid", "bha", "alternate_days", "Сумма раздражения и сухости. Вариант: BHA утром, ретиноид вечером.", "high",
  "При жирной коже и низкой BHA (0,5–1%) можно разнести по утру и вечеру.", ["dermnet-retinoids", "dermnet-sa"])
P("retinoid", "pha", "caution", "PHA мягкие, но всё равно добавляют отшелушивание.", "medium", "Лучше через день; в один вечер — только если кожа спокойна.", ["pc-dict"])
P("retinoid", "azelaic", "ok", "Частая врачебная схема при акне и пигментации; разные механизмы.", "medium",
  "При 15–20% азелаиновой и сильном ретиноиде — разнести на утро и вечер.", ["dermnet-azelaic", "aad-acne-2024"])
P("retinoid", "vitc", "separate_slots", "Химически друг друга не «гасят», но чистый витамин C кислый и тоже может раздражать. Удобнее: C утром, ретиноид вечером.", "medium",
  "Стабильные производные C (SAP, MAP, аскорбилглюкозид) можно и вечером вместе.", ["pc-dict", "labmuffin"])
P("retinoid", "niacinamide", "good_together", "Ниацинамид укрепляет барьер и снижает раздражение от ретиноидов.", "high", None, ["pc-dict", "niacinamide-koh"])
P("retinoid", "peptides", "good_together", "Конфликта нет; оба антивозрастные, пептиды не раздражают.", "medium", None, ["pc-dict"])
P("retinoid", "copper_peptides", "ok", "Химической несовместимости не показано; запрет — из соображений раздражения.", "low",
  "При чувствительной коже — разные вечера.", ["cu-evigrade"], myth=True)
P("retinoid", "bpo", "separate_slots", "Бензоилпероксид окисляет третиноин и, вероятно, ретинол; вместе сильно сушат. Адапален стабилен — с ним можно.", "medium",
  "Для адапалена — ok (есть готовые комбинации).", ["aad-acne-2024", "dermnet-bpo"])
P("retinoid", "sulfur", "caution", "Оба сушат; суммарное раздражение.", "medium", "Серу точечно, ретиноид на всё лицо — допустимо.", ["pc-dict"])
P("retinoid", "brightening", "ok", "Транексамовая, арбутин, солодка с ретиноидами совместимы и дополняют друг друга.", "medium",
  "Койевая кислота, бутилрезорцинол и цистеамин сами раздражают — разносить.", ["pc-dict"])
P("retinoid", "soothing", "good_together", "Центелла, пантенол, аллантоин снижают раздражение.", "high", None, ["pc-dict"])
P("retinoid", "hydrating", "good_together", "Увлажнение уменьшает сухость от ретиноидов. Гиалуроновая кислота ретиноид не нейтрализует.", "high", None, ["pc-dict"], myth=True)
P("retinoid", "barrier", "good_together", "Крем с керамидами до/после ретиноида («сэндвич») снижает раздражение.", "high", None, ["pc-dict", "dermnet-retinoids"])
P("retinoid", "antioxidant", "ok", "Конфликта нет.", "medium", None, ["pc-dict"])
P("retinoid", "exfoliant_physical", "avoid_same_time", "Скраб или спикулы на коже под ретиноидом — травма и сильное раздражение.", "high", "Скраб — за 2–3 дня до/после.", ["dermnet-retinoids"])
P("retinoid", "enzyme", "alternate_days", "Энзимы отшелушивают — суммируется раздражение.", "medium", None, ["pc-dict"])
P("retinoid", "spf_filter", "good_together", "Ретиноид вечером, SPF утром обязателен: кожа тоньше и чувствительнее к солнцу.", "high", None, ["dermnet-retinoids", "aad-sunscreen"])
P("retinoid", "other", "ok", "PDRN, экзосомы, ферменты, цинк — конфликтов не описано.", "low", "Тиа-три и прочие эфирные масла — осторожно.", [])
# aha
P("aha", "aha", "caution", "Несколько кислотных средств подряд суммируют силу.", "high", "Одно кислотное средство за вечер; комплексы AHA в одном флаконе — норм.", ["fda-aha"])
P("aha", "bha", "caution", "В одной формуле — обычная практика; два отдельных кислотных средства подряд — перебор.", "medium",
  "При чувствительной коже — разные дни.", ["pc-dict", "fda-aha"])
P("aha", "pha", "caution", "Суммарное отшелушивание; PHA добавляют немного.", "medium", None, ["pc-dict"])
P("aha", "azelaic", "caution", "Обе кислоты могут щипать; комбинация допустима при спокойной коже.", "medium", "При сенсибилизации — разные слоты.", ["dermnet-azelaic"])
P("aha", "vitc", "caution", "Миф: кислоты не «разрушают» витамин C (ему нужна кислая среда). Но два кислых средства подряд раздражают.", "medium",
  "Чистая L-AA утром, AHA вечером. Производные C — без ограничений.", ["pinnell-laa", "fb-mixing"], myth=True)
P("aha", "niacinamide", "ok", "Миф: при нормальном уходе ниацинамид не превращается в никотиновую кислоту от кислот. Можно в один вечер.", "medium",
  "Если появляется покраснение — разнести на 10–15 минут или на разные слоты.", S_MIX, myth=True)
P("aha", "peptides", "ok", "Миф о «разрушении» пептидов кислотами при наслаивании не подтверждён; проблема только внутри одной формулы.", "low", None, ["pc-dict"], myth=True)
P("aha", "copper_peptides", "separate_slots", "Кислая среда теоретически ослабляет связь меди с пептидом; доказательств на коже нет.", "low", None, ["cu-evigrade"])
P("aha", "bpo", "alternate_days", "Сильная сухость и раздражение вместе.", "medium", None, ["dermnet-bpo", "fda-aha"])
P("aha", "sulfur", "caution", "Суммарная сухость.", "low", None, ["pc-dict"])
P("aha", "brightening", "good_together", "Отшелушивание усиливает действие осветлителей (транексамовая, арбутин).", "medium", "С койевой кислотой и бутилрезорцинолом — следить за раздражением.", ["pc-dict"])
P("aha", "soothing", "good_together", "Успокаивающие снижают дискомфорт после кислот.", "medium", None, ["pc-dict"])
P("aha", "hydrating", "good_together", "Гиалуроновая кислота и мочевина до 10% не мешают кислотам.", "medium", "Мочевина >10% тоже отшелушивает — считать как кислоту.", ["pc-dict"], myth=True)
P("aha", "barrier", "good_together", "Крем с керамидами после кислоты снижает раздражение.", "medium", None, ["pc-dict"])
P("aha", "antioxidant", "ok", "Конфликта нет.", "medium", None, [])
P("aha", "exfoliant_physical", "avoid_same_time", "Двойное отшелушивание — риск повредить барьер.", "high", None, ["fda-aha"])
P("aha", "enzyme", "avoid_same_time", "Двойное отшелушивание.", "medium", None, ["pc-dict"])
P("aha", "spf_filter", "good_together", "AHA повышают чувствительность к солнцу ещё неделю — SPF обязателен.", "high", None, ["fda-aha", "aad-sunscreen"])
P("aha", "other", "ok", "Конфликтов не описано.", "low", "Кроме спикул и тиа-три — осторожно.", [])
# bha
P("bha", "bha", "caution", "Два средства с BHA суммируют сухость.", "medium", None, ["dermnet-sa"])
P("bha", "pha", "ok", "PHA мягкие; сочетание обычно переносится.", "medium", "При сухой коже — разные дни.", ["pc-dict"])
P("bha", "azelaic", "ok", "Частая связка при акне и розацеа (с BHA 0,5–2%).", "medium", "Если щиплет — разные слоты.", ["dermnet-azelaic", "dermnet-sa"])
P("bha", "vitc", "caution", "Чистая L-AA и BHA кислые — вместе щиплет. Миф о взаимной инактивации не подтверждён.", "medium", "Производные C — ok.", ["fb-mixing"], myth=True)
P("bha", "niacinamide", "ok", "Миф о несовместимости; классическая связка для жирной кожи.", "medium", None, S_MIX, myth=True)
P("bha", "peptides", "ok", "Конфликта на коже не показано.", "low", None, [], myth=True)
P("bha", "copper_peptides", "separate_slots", "Теоретическое ослабление комплекса меди в кислой среде.", "low", None, ["cu-evigrade"])
P("bha", "bpo", "caution", "Обе — противоакне, но вместе сушат.", "medium", "Смываемый BPO + несмываемый BHA, либо утро/вечер.", ["dermnet-bpo", "aad-acne-2024"])
P("bha", "sulfur", "ok", "Частая противоакне комбинация в одном средстве.", "medium", "Следить за сухостью.", ["pc-dict"])
P("bha", "brightening", "ok", "Конфликта нет.", "medium", None, [])
P("bha", "soothing", "good_together", "Снижает дискомфорт.", "medium", None, [])
P("bha", "hydrating", "good_together", "Компенсирует сухость от BHA.", "medium", None, [])
P("bha", "barrier", "good_together", "Компенсирует сухость от BHA.", "medium", None, [])
P("bha", "antioxidant", "ok", "Конфликта нет.", "medium", None, [])
P("bha", "exfoliant_physical", "avoid_same_time", "Двойное отшелушивание.", "high", None, [])
P("bha", "enzyme", "avoid_same_time", "Двойное отшелушивание.", "medium", None, [])
P("bha", "spf_filter", "good_together", "Любое отшелушивание — повод для ежедневного SPF.", "high", None, ["aad-sunscreen"])
P("bha", "other", "ok", "Цинк PCA и чайное дерево дополняют BHA при акне.", "low", None, [])
# pha
P("pha", "pha", "ok", "Мягкие; суммирование минимально.", "medium", None, [])
P("pha", "azelaic", "ok", "Обе подходят реактивной коже.", "low", None, [])
P("pha", "vitc", "ok", "PHA мягкие; с C обычно совместимы.", "low", "С чистой L-AA при чувствительной коже — разные слоты.", [])
P("pha", "niacinamide", "ok", "Совместимы.", "medium", None, S_MIX, myth=True)
P("pha", "peptides", "ok", "Совместимы.", "low", None, [])
P("pha", "copper_peptides", "caution", "Теоретически кислая среда; PHA слабокислые.", "low", None, ["cu-evigrade"])
P("pha", "bpo", "ok", "PHA мягкие и увлажняют; вместе переносятся.", "low", None, [])
P("pha", "sulfur", "ok", "Совместимы.", "low", None, [])
P("pha", "brightening", "good_together", "Мягкое отшелушивание усиливает осветлители.", "low", None, [])
P("pha", "soothing", "good_together", "Совместимы.", "medium", None, [])
P("pha", "hydrating", "good_together", "Совместимы.", "medium", None, [])
P("pha", "barrier", "good_together", "Совместимы.", "medium", None, [])
P("pha", "antioxidant", "ok", "Совместимы.", "medium", None, [])
P("pha", "exfoliant_physical", "caution", "Двойное отшелушивание, хоть и мягкое.", "medium", None, [])
P("pha", "enzyme", "caution", "Двойное отшелушивание.", "medium", None, [])
P("pha", "spf_filter", "good_together", "SPF днём при любом отшелушивании.", "high", None, ["aad-sunscreen"])
# azelaic
P("azelaic", "vitc", "caution", "Обе могут щипать.", "low", "С производными C — ok.", [])
P("azelaic", "niacinamide", "good_together", "Связка при акне, розацеа и пигментации.", "medium", None, ["dermnet-azelaic", "pc-dict"])
P("azelaic", "peptides", "ok", "Конфликта нет.", "low", None, [])
P("azelaic", "copper_peptides", "caution", "Кислая среда; теоретически.", "low", None, ["cu-evigrade"])
P("azelaic", "bpo", "ok", "Обе применяются при акне, часто в одной схеме.", "medium", "Следить за сухостью.", ["dermnet-azelaic", "aad-acne-2024"])
P("azelaic", "sulfur", "ok", "Совместимы; обе при розацеа и акне.", "low", None, [])
P("azelaic", "brightening", "good_together", "Разные пути борьбы с пигментом.", "medium", None, ["dermnet-azelaic", "txa-review-2026"])
P("azelaic", "soothing", "good_together", "Снижает покалывание.", "medium", None, [])
P("azelaic", "hydrating", "good_together", "Совместимы.", "medium", None, [])
P("azelaic", "barrier", "good_together", "Совместимы.", "medium", None, [])
P("azelaic", "antioxidant", "ok", "Совместимы.", "low", None, [])
P("azelaic", "exfoliant_physical", "caution", "Повреждённая кожа сильнее реагирует на кислоту.", "medium", None, [])
P("azelaic", "enzyme", "caution", "Суммарное раздражение.", "low", None, [])
P("azelaic", "spf_filter", "good_together", "При пигментации SPF обязателен.", "high", None, ["aad-sunscreen"])
# vitc
P("vitc", "vitc", "ok", "Две формы витамина C можно, но обычно избыточно.", "medium", "Две кислотные L-AA подряд — не надо.", [])
P("vitc", "niacinamide", "ok", "Миф из старых опытов с нагревом. В реальных средствах и на коже — совместимы.", "high",
  "Если краснеете — разнести по времени; это редкое индивидуальное.", ["beautytap-mixing", "labmuffin", "fb-mixing"], myth=True)
P("vitc", "peptides", "ok", "Наслаивание допустимо; несовместимость — проблема формулы, а не ухода.", "low", None, [], myth=True)
P("vitc", "copper_peptides", "caution", "Аскорбиновая кислота может восстанавливать медь и разрушать комплекс в растворе; на коже не доказано.", "low",
  "Касается чистой L-AA; производные C — ok.", ["cu-evigrade"])
P("vitc", "bpo", "avoid_same_time", "Бензоилпероксид — окислитель и окисляет аскорбиновую кислоту.", "medium", "C утром, BPO вечером (или наоборот).", ["dermnet-bpo"])
P("vitc", "sulfur", "caution", "Мало данных; оба могут раздражать.", "low", None, [])
P("vitc", "brightening", "good_together", "Витамин C, транексамовая и арбутин дополняют друг друга при пигментации.", "medium", None, ["txa-review-2026", "pc-dict"])
P("vitc", "soothing", "ok", "Совместимы.", "medium", None, [])
P("vitc", "hydrating", "ok", "Совместимы.", "medium", None, [])
P("vitc", "barrier", "ok", "Совместимы.", "medium", None, [])
P("vitc", "antioxidant", "good_together", "Витамин C + E + феруловая кислота стабилизируют друг друга и усиливают защиту.", "high", None, ["pinnell-laa", "pc-dict"])
P("vitc", "exfoliant_physical", "caution", "На свежеотшелушенной коже кислая C щиплет.", "low", None, [])
P("vitc", "enzyme", "ok", "Совместимы, но после энзимов L-AA может щипать.", "low", None, [])
P("vitc", "spf_filter", "good_together", "Антиоксидант утром усиливает защиту SPF, но не заменяет его.", "high", None, ["pinnell-laa", "aad-sunscreen"])
P("vitc", "other", "ok", "Конфликтов не описано.", "low", None, [])
# niacinamide
P("niacinamide", "peptides", "good_together", "Совместимы, оба мягкие.", "medium", None, [])
P("niacinamide", "copper_peptides", "ok", "Утверждения о несовместимости — фольклор.", "low", None, [], myth=True)
P("niacinamide", "bpo", "good_together", "Ниацинамид снижает раздражение и сам помогает при акне.", "medium", None, ["pc-dict"])
P("niacinamide", "sulfur", "ok", "Совместимы.", "low", None, [])
P("niacinamide", "brightening", "good_together", "Ниацинамид + транексамовая/арбутин — популярная связка от пигмента.", "medium", None, ["pc-dict", "txa-review-2026"])
P("niacinamide", "soothing", "good_together", "Совместимы.", "medium", None, [])
P("niacinamide", "hydrating", "good_together", "Совместимы.", "medium", None, [])
P("niacinamide", "barrier", "good_together", "Ниацинамид усиливает синтез керамидов.", "high", None, ["pc-dict"])
P("niacinamide", "antioxidant", "ok", "Совместимы.", "medium", None, [])
P("niacinamide", "exfoliant_physical", "ok", "Совместимы.", "low", None, [])
P("niacinamide", "enzyme", "ok", "Совместимы.", "low", None, [])
P("niacinamide", "spf_filter", "good_together", "Утром ниацинамид + SPF — удобная связка.", "medium", None, [])
P("niacinamide", "other", "good_together", "Цинк PCA + ниацинамид — классика для жирной кожи.", "medium", None, ["pc-dict"])
P("niacinamide", "niacinamide", "caution", "Несколько средств с ниацинамидом дают в сумме >10% — чаще покраснение.", "low", None, ["niacinamide-koh"])
# peptides / copper
P("peptides", "peptides", "ok", "Совместимы.", "medium", None, [])
P("peptides", "copper_peptides", "ok", "Запрет смешивать пептиды — фольклор.", "low", None, [], myth=True)
P("peptides", "bpo", "caution", "Окислитель теоретически может повредить пептиды.", "low", "Лучше разные слоты.", [])
P("peptides", "enzyme", "separate_slots", "Протеазы расщепляют белки и, вероятно, пептиды.", "low", None, [])
P("peptides", "sulfur", "ok", "Конфликта нет.", "low", None, [])
P("peptides", "brightening", "ok", "Совместимы.", "low", None, [])
P("peptides", "soothing", "good_together", "Совместимы.", "low", None, [])
P("peptides", "hydrating", "good_together", "Совместимы.", "low", None, [])
P("peptides", "barrier", "good_together", "Совместимы.", "low", None, [])
P("peptides", "antioxidant", "ok", "Совместимы.", "low", None, [])
P("peptides", "spf_filter", "ok", "Совместимы.", "low", None, [])
P("peptides", "other", "ok", "Совместимы.", "low", None, [])
P("peptides", "exfoliant_physical", "ok", "Совместимы.", "low", None, [])
P("copper_peptides", "bpo", "avoid_same_time", "Окислитель плюс ион меди — нежелательная реакция; теоретически.", "low", None, [])
P("copper_peptides", "sulfur", "caution", "Мало данных.", "low", None, [])
P("copper_peptides", "brightening", "caution", "Койевая кислота связывает медь; может ослабить пептид.", "low", "Транексамовая и арбутин — ok.", [])
P("copper_peptides", "soothing", "good_together", "Совместимы.", "low", None, [])
P("copper_peptides", "hydrating", "good_together", "Совместимы.", "low", None, [])
P("copper_peptides", "barrier", "good_together", "Совместимы.", "low", None, [])
P("copper_peptides", "antioxidant", "ok", "Совместимы (кроме чистой аскорбиновой — см. vitc).", "low", None, [])
P("copper_peptides", "enzyme", "separate_slots", "Протеазы могут расщеплять пептид.", "low", None, [])
P("copper_peptides", "spf_filter", "ok", "Совместимы.", "low", None, [])
P("copper_peptides", "exfoliant_physical", "caution", "Мало данных.", "low", None, [])
P("copper_peptides", "copper_peptides", "caution", "Избыток меди теоретически раздражает.", "low", None, [])
# bpo / sulfur
P("bpo", "bpo", "avoid_same_time", "Две формы BPO — лишняя сухость без пользы.", "medium", None, ["bpo-jdd"])
P("bpo", "sulfur", "caution", "Обе сильно сушат.", "medium", None, [])
P("bpo", "brightening", "caution", "Окислитель может разрушать часть осветлителей.", "low", "Разные слоты.", [])
P("bpo", "soothing", "good_together", "Снижает раздражение.", "medium", None, [])
P("bpo", "hydrating", "good_together", "Снижает сухость.", "medium", None, [])
P("bpo", "barrier", "good_together", "Увлажняющий крем снижает раздражение от BPO.", "high", None, ["dermnet-bpo", "aad-acne-2024"])
P("bpo", "antioxidant", "separate_slots", "BPO окисляет антиоксиданты.", "low", None, [])
P("bpo", "exfoliant_physical", "avoid_same_time", "Сильное раздражение.", "medium", None, [])
P("bpo", "enzyme", "caution", "Суммарное раздражение.", "low", None, [])
P("bpo", "spf_filter", "ok", "Совместимы; SPF всё равно нужен.", "medium", None, ["aad-sunscreen"])
P("bpo", "other", "caution", "С чайным деревом — суммарное раздражение.", "low", None, [])
P("sulfur", "sulfur", "caution", "Избыточно.", "low", None, [])
P("sulfur", "soothing", "good_together", "Совместимы.", "low", None, [])
P("sulfur", "hydrating", "good_together", "Совместимы.", "low", None, [])
P("sulfur", "barrier", "good_together", "Совместимы.", "low", None, [])
P("sulfur", "brightening", "ok", "Совместимы.", "low", None, [])
P("sulfur", "antioxidant", "ok", "Совместимы.", "low", None, [])
P("sulfur", "exfoliant_physical", "caution", "Суммарное раздражение.", "low", None, [])
P("sulfur", "enzyme", "caution", "Суммарное раздражение.", "low", None, [])
P("sulfur", "spf_filter", "ok", "Совместимы.", "low", None, [])
# brightening etc.
P("brightening", "brightening", "ok", "Комбинации осветлителей обычны (TXA + арбутин + солодка).", "medium", "Две раздражающие (койевая + бутилрезорцинол) — следить.", ["txa-review-2026"])
P("brightening", "soothing", "good_together", "Совместимы.", "medium", None, [])
P("brightening", "hydrating", "good_together", "Совместимы.", "medium", None, [])
P("brightening", "barrier", "good_together", "Совместимы.", "medium", None, [])
P("brightening", "antioxidant", "good_together", "Антиоксиданты тоже уменьшают пигментацию.", "medium", None, [])
P("brightening", "exfoliant_physical", "caution", "Раздражение может усилить пигментацию.", "low", None, [])
P("brightening", "enzyme", "ok", "Совместимы.", "low", None, [])
P("brightening", "spf_filter", "good_together", "Без SPF осветлители почти бесполезны.", "high", None, ["aad-sunscreen", "txa-review-2026"])
P("brightening", "other", "ok", "Совместимы.", "low", None, [])
P("soothing", "soothing", "good_together", "Совместимы.", "high", None, [])
P("soothing", "hydrating", "good_together", "Совместимы.", "high", None, [])
P("soothing", "barrier", "good_together", "Совместимы.", "high", None, [])
P("soothing", "antioxidant", "good_together", "Совместимы.", "medium", None, [])
P("soothing", "exfoliant_physical", "ok", "Успокаивающие после скраба уместны.", "medium", None, [])
P("soothing", "enzyme", "ok", "Совместимы.", "medium", None, [])
P("soothing", "spf_filter", "good_together", "Совместимы.", "medium", None, [])
P("soothing", "other", "good_together", "Совместимы.", "low", None, [])
P("hydrating", "hydrating", "good_together", "Совместимы.", "high", None, [])
P("hydrating", "barrier", "good_together", "Увлажнитель + липиды — лучший базовый уход.", "high", None, [])
P("hydrating", "antioxidant", "ok", "Совместимы.", "medium", None, [])
P("hydrating", "exfoliant_physical", "ok", "Совместимы.", "medium", None, [])
P("hydrating", "enzyme", "ok", "Совместимы.", "medium", None, [])
P("hydrating", "spf_filter", "good_together", "Совместимы.", "medium", None, [])
P("hydrating", "other", "good_together", "Совместимы.", "low", None, [])
P("barrier", "barrier", "good_together", "Керамиды + холестерин + жирные кислоты работают вместе.", "high", None, [])
P("barrier", "antioxidant", "ok", "Совместимы.", "medium", None, [])
P("barrier", "exfoliant_physical", "ok", "Крем после скраба уместен.", "medium", None, [])
P("barrier", "enzyme", "ok", "Совместимы.", "medium", None, [])
P("barrier", "spf_filter", "good_together", "Совместимы.", "medium", None, [])
P("barrier", "other", "good_together", "Совместимы.", "low", None, [])
P("antioxidant", "antioxidant", "good_together", "Антиоксиданты поддерживают друг друга.", "medium", None, [])
P("antioxidant", "exfoliant_physical", "ok", "Совместимы.", "low", None, [])
P("antioxidant", "enzyme", "ok", "Совместимы.", "low", None, [])
P("antioxidant", "spf_filter", "good_together", "Антиоксиданты утром дополняют SPF.", "high", None, ["aad-sunscreen"])
P("antioxidant", "other", "ok", "Совместимы.", "low", None, [])
P("exfoliant_physical", "exfoliant_physical", "avoid_same_time", "Двойная механическая травма.", "high", None, [])
P("exfoliant_physical", "enzyme", "avoid_same_time", "Двойное отшелушивание.", "medium", None, [])
P("exfoliant_physical", "spf_filter", "good_together", "После отшелушивания кожа чувствительнее к солнцу.", "medium", None, ["aad-sunscreen"])
P("exfoliant_physical", "other", "caution", "Спикулы усиливают проникновение любых активов, включая раздражающие.", "low", None, [])
P("enzyme", "enzyme", "caution", "Избыточно.", "low", None, [])
P("enzyme", "spf_filter", "good_together", "SPF после любого отшелушивания.", "medium", None, [])
P("enzyme", "other", "ok", "Совместимы.", "low", None, [])
P("spf_filter", "spf_filter", "ok", "Сочетания фильтров — норма; несколько SPF-средств не складывают SPF арифметически.", "high", None, ["aad-sunscreen"])
P("spf_filter", "other", "ok", "Совместимы.", "low", None, [])
P("other", "other", "ok", "Конфликтов не описано.", "low", None, [])

P("pha", "other", "ok", "Конфликтов не описано.", "low", None, [])
P("azelaic", "azelaic", "caution", "Два средства с азелаиновой кислотой — избыточно.", "low", None, [])
P("azelaic", "other", "ok", "Конфликтов не описано.", "low", None, [])
P("copper_peptides", "other", "ok", "Конфликтов не описано.", "low", None, [])
P("sulfur", "other", "caution", "С чайным деревом и спикулами — суммарное раздражение.", "low", None, [])
# specific actives
P("tretinoin", "benzoyl_peroxide", "separate_slots", "BPO окисляет третиноин и ослабляет его. BPO утром, третиноин вечером.", "high", "Кроме специальных стабильных комбинаций (микроинкапсуляция).", ["aad-acne-2024", "dermnet-retinoids", "dermnet-bpo"])
P("adapalene", "benzoyl_peroxide", "good_together", "Адапален стабилен с BPO; есть готовые комбинации (Эффезел/Epiduo).", "high", "Сухость — ввод через день.", ["aad-acne-2024", "dermnet-bpo"])
P("retinol", "benzoyl_peroxide", "separate_slots", "Ретинол легко окисляется; вместе ещё и сушит.", "medium", None, ["dermnet-bpo"])
P("vitc_laa", "copper_peptides", "separate_slots", "Химическая реакция в растворе правдоподобна; на коже вред не доказан. Разнести по утру/вечеру — дешёвая страховка.", "low", None, ["cu-evigrade"])
P("vitc_laa", "niacinamide", "ok", "Миф. Комплекс образуется обратимо и не вредит; ниацин образуется только при нагреве.", "high", "При покраснении — разнести.", ["beautytap-mixing", "fb-mixing"], myth=True)
P("vitc_laa", "benzoyl_peroxide", "avoid_same_time", "BPO окисляет аскорбиновую кислоту.", "medium", None, ["dermnet-bpo"])
P("vitc_laa", "glycolic_acid", "caution", "Два низких pH подряд — сильное покалывание.", "medium", "Разные слоты.", ["fda-aha", "pinnell-laa"])
P("vitc_laa", "retinol", "separate_slots", "C утром, ретинол вечером — удобнее и мягче.", "medium", None, ["pc-dict"])
P("glycolic_acid", "retinol", "alternate_days", "Самая раздражающая частая связка у новичков.", "high", "Только опытным и при низких %.", ["fda-aha", "dermnet-retinoids"])
P("glycolic_acid", "tretinoin", "avoid_same_time", "Высокий риск ожога и дерматита.", "high", None, ["dermnet-retinoids"])
P("salicylic_acid", "tretinoin", "alternate_days", "Суммарная сухость и раздражение.", "high", None, ["dermnet-retinoids"])
P("urea", "aha", "caution", "Мочевина >10% тоже отшелушивает и щиплет вместе с кислотами.", "medium", "Ниже 10% — ok.", ["pc-dict"])
P("urea", "retinoid", "caution", "Мочевина >10% усиливает проникновение и раздражение.", "low", "Ниже 10% — good_together.", ["pc-dict"])
P("spicules", "retinoid", "avoid_same_time", "Спикулы открывают микроканалы — ретиноид проникает сильнее и сильнее раздражает.", "medium", "Минимум 2–3 дня между ними.", ["rbc-style"])
P("spicules", "aha", "avoid_same_time", "Кислоты на микроповреждённой коже — жжение.", "medium", None, ["rbc-style"])
P("spicules", "vitc_laa", "avoid_same_time", "Кислая C на микроповреждённой коже — жжение.", "medium", None, [])
P("kojic_acid", "copper_peptides", "caution", "Койевая кислота связывает медь.", "low", None, [])
P("bakuchiol", "retinol", "good_together", "Бакучиол часто добавляют к ретинолу для мягкости; данных о вреде нет.", "low", None, ["labmuffin-bakuchiol"])
P("bakuchiol", "retinoid", "ok", "Совместимы; бакучиол не ретиноид.", "low", None, ["labmuffin-bakuchiol"])
P("zinc_pca", "niacinamide", "good_together", "Себорегуляция при жирной коже.", "medium", None, ["pc-dict"])
P("tea_tree", "benzoyl_peroxide", "caution", "Оба раздражают; вместе — избыточно.", "low", None, [])
P("pdrn", "retinoid", "ok", "Конфликтов не описано; PDRN мягкий.", "low", None, ["pdrn-review"])
P("exosomes", "retinoid", "ok", "Конфликтов не описано; данных мало.", "low", None, ["exo-dermtimes"])
P("hyaluronic_acid", "aha", "ok", "Миф о «нейтрализации» кислот гиалуроновой кислотой не подтверждён.", "medium", None, ["labmuffin"], myth=True)
P("cysteamine", "retinoid", "avoid_same_time", "Оба сильно раздражают.", "medium", None, [])
P("cysteamine", "aha", "avoid_same_time", "Оба сильно раздражают.", "medium", None, [])
P("azelaic_acid", "niacinamide", "good_together", "Связка при розацеа и постакне.", "medium", None, ["dermnet-azelaic"])
P("tranexamic_acid", "niacinamide", "good_together", "Частая противопигментная связка.", "medium", None, ["txa-review-2026"])

RULE_SRC = {"inci-order": ["eu-1223", "cosbiz-inci", "incidecoder-lists"], "inci-1pct-line": ["incidecoder-lists", "cosing", "eu-1223"], "inci-estimate": ["incidecoder-lists"], "spf-daily": ["fda-aha", "aad-sunscreen"], "pregnancy": ["preg-jabfm", "topical-acne-safety"], "concentration-modifier": ["fda-aha", "ret-conc-pmc", "bpo-jdd"]}
rules = [
    {"id": "irritation-load", "text": "Считаем нагрузку за один приём: сумма strength всех кислот, ретиноидов, BPO, серы, отшелушивающих и сильных осветлителей (strength ≥ 2). Новичок и чувствительная кожа — не больше 4, обычная — 6, опытная — 8. Не больше одного актива со strength ≥ 4 за приём."},
    {"id": "concentration-modifier", "text": "К базовому strength: концентрация ≤ low → −1, между medium и high → +1, выше high → +2 (не ниже 1 и не выше 5). Если концентрация неизвестна — берём medium. Для AHA pH < 3 даёт ещё +1."},
    {"id": "one-new-active", "text": "Вводить только один новый актив за раз; следующий — через 2 недели (ретиноиды и сильные кислоты — через 4)."},
    {"id": "escalation", "text": "Сначала повышаем частоту, потом концентрацию: 2 раза в неделю → через день → ежедневно, шаг — stepUpWeeks при отсутствии раздражения. Переход на следующую концентрацию — не раньше чем через 4–8 недель ежедневного применения без раздражения."},
    {"id": "patch-test", "text": "Новое средство с активами — патч-тест 2–3 вечера на линии челюсти или за ухом."},
    {"id": "spf-daily", "text": "Если в уходе есть ретиноид, кислота, осветлитель или скраб — ежедневный SPF 30+ утром (FDA: после AHA ещё 7 дней)."},
    {"id": "pause-on-irritation", "text": "Жжение дольше 10 минут, отёк, мокнутие или сильное шелушение — пауза всех активов на 3–7 дней, только мягкое очищение, крем и SPF; затем возврат с меньшей частотой. Сыпь, отёк век или волдыри — к врачу."},
    {"id": "slots", "text": "Утро: антиоксиданты (витамин C), ниацинамид, увлажнение, SPF. Вечер: ретиноиды, AHA, спикулы, сера. Если двум активам нельзя «same_time» — разводим утро/вечер или чередуем дни."},
    {"id": "one-exfoliant-per-evening", "text": "Не больше одного отшелушивающего средства за вечер (кислоты, ретиноид, энзимы, скраб, спикулы, мочевина >10%)."},
    {"id": "recovery-nights", "text": "При 3+ вечерах с активами в неделю — 1–2 вечера «отдыха» только с барьерным уходом."},
    {"id": "sensitive-skin", "text": "Чувствительная кожа, розацеа, атопия: ограничить активы strength ≤ 3, стартовать с минимальных концентраций, предпочитать PHA, азелаиновую, ниацинамид 2–5%, производные C, инкапсулированный ретинол."},
    {"id": "pregnancy", "text": "Беременность/кормление: все ретиноиды — исключить (включая эфиры и HPR); салициловую — только низкие % на небольших участках; высокие % и пилинги — нет. Допустимы азелаиновая, AHA, витамин C, ниацинамид, BPO (по мнению врача), минеральный SPF. Для активов без данных — «осторожно»."},
    {"id": "rx-drugs", "text": "Третиноин, адапален 0,3%, азелаиновая 15–20%, рецептурный гидрохинон — лекарства. Приложение не меняет схему, назначенную врачом; только напоминает о совместимости."},
    {"id": "layering", "text": "Порядок: от жидкого к плотному; ждать между слоями обычно не нужно (миф о 20 минутах для кислот без доказательств). Ретиноид при чувствительности — «сэндвич»: крем, ретиноид, крем."},
    {"id": "no-summer-ban", "text": "Ретиноиды и кислоты летом не запрещены, если есть ежедневный SPF; перед отпуском у моря — снизить частоту за 1 неделю."},
    {"id": "purge", "text": "Ретиноиды и кислоты в первые 4–6 недель могут вызывать временное усиление высыпаний там, где они обычно бывают; новые зоны и зуд — признак раздражения, а не «очищения»."},
    {"id": "inci-order", "text": "INCI перечисляется по убыванию массовой доли (ЕС ст. 19 Регламента 1223/2009; США — аналогично). Всё, что меньше 1%, может идти в любом порядке после ингредиентов >1%. Красители (CI ...) — в конце."},
    {"id": "inci-1pct-line", "text": "Линию 1% ищем по маркерам: феноксиэтанол (ЕС макс. 1%), этилгексилглицерин, бензоат натрия, сорбат калия, ксантан, карбомер, отдушка (Parfum/Fragrance), аллергены (Linalool, Limonene), EDTA. Всё после первого маркера — вероятно ≤1%. Актив выше воды/основы и на 2–5 месте — вероятно высокая концентрация."},
    {"id": "inci-estimate", "text": "Если процент не указан: актив до линии 1% и в первой трети — оценка medium..high; до линии, но ниже середины — low..medium; после линии — ≤1% (для ретинола/пептидов это может быть нормальной рабочей дозой, для кислот и ниацинамида — слабо). Активы с activeOnlyIfAbove1pctLine после линии считаем вспомогательными (регулятор pH, стабилизатор)."},
    {"id": "label-percent", "text": "Процент на этикетке приоритетнее оценки по INCI. Но «2% гиалуроновой» или «10% пептидов» часто означает долю раствора сырья, а не чистого вещества."},
    {"id": "matching", "text": "Сопоставление INCI: регистронезависимо, по целым словам, побеждает самое длинное совпадение (Alpha-Arbutin раньше Arbutin; Ethylhexyl Salicylate — УФ-фильтр, а не BHA; Sodium Lactate — не AHA)."},
    {"id": "low-confidence", "text": "Пары с confidence=low показываются как мягкий совет, а не запрет."},
]

for r in rules:
    if r["id"] in RULE_SRC: r["sources"] = RULE_SRC[r["id"]]

concentration_markers = [
    {"inci": "Phenoxyethanol", "maxPct": 1.0, "note": "ЕС лимит 1%"},
    {"inci": "Ethylhexylglycerin", "maxPct": 1.0, "note": "обычно 0,1–1%"},
    {"inci": "Sodium Benzoate", "maxPct": 1.0, "note": "обычно ≤0,5%"},
    {"inci": "Potassium Sorbate", "maxPct": 0.6, "note": "ЕС лимит 0,6% (как кислота)"},
    {"inci": "Benzyl Alcohol", "maxPct": 1.0, "note": "консервант до 1%"},
    {"inci": "Chlorphenesin", "maxPct": 0.3, "note": "ЕС лимит 0,3%"},
    {"inci": "Methylparaben", "maxPct": 0.4, "note": "ЕС лимит 0,4%"},
    {"inci": "Xanthan Gum", "maxPct": 1.0, "note": "загуститель 0,1–1%"},
    {"inci": "Carbomer", "maxPct": 1.0, "note": "загуститель 0,1–1%"},
    {"inci": "Parfum", "maxPct": 1.0, "note": "отдушка в уходе обычно ≤1%"},
    {"inci": "Fragrance", "maxPct": 1.0, "note": "отдушка в уходе обычно ≤1%"},
    {"inci": "Disodium EDTA", "maxPct": 0.2, "note": "хелатор 0,05–0,2%"},
    {"inci": "Linalool", "maxPct": 0.1, "note": "аллерген, указывается от 0,001%"},
    {"inci": "Limonene", "maxPct": 0.1, "note": "аллерген, указывается от 0,001%"},
    {"inci": "Citric Acid", "maxPct": 0.5, "note": "обычно регулятор pH, если стоит в конце"},
    {"inci": "Sodium Hydroxide", "maxPct": 0.5, "note": "регулятор pH"},
]

kb = {
    "version": 1,
    "generated": "2026-10-18",
    "disclaimer": "Справочные правила для косметики, не медицинская рекомендация. Рецептурные препараты — по назначению врача.",
    "frequencyLegend": FREQ_LEGEND,
    "groups": ["retinoid", "aha", "bha", "pha", "azelaic", "vitc", "niacinamide", "peptides", "copper_peptides", "bpo", "sulfur",
               "brightening", "soothing", "hydrating", "barrier", "antioxidant", "exfoliant_physical", "enzyme", "spf_filter", "other"],
    "sources": [{"id": i, "title": t, "url": u} for i, t, u in sources],
    "actives": actives,
    "pairs": pairs,
    "rules": rules,
    "concentrationMarkers": concentration_markers,
}

# ---- validation ----
src_ids = {s["id"] for s in kb["sources"]}
act_ids = [a["id"] for a in actives]
assert len(act_ids) == len(set(act_ids)), "dup active ids"
groups = set(kb["groups"])
errs = []
for a in actives:
    if a["group"] not in groups: errs.append(("group", a["id"]))
    for s in a["sources"]:
        if s not in src_ids: errs.append(("src", a["id"], s))
    assert 1 <= a["strength"] <= 5
    for f in ("startFrequency", "maxFrequency"):
        assert a[f] in FREQ_LEGEND, (a["id"], f)
    assert a["timeOfDay"] in ("evening", "morning", "any")
    assert a["pregnancy"] in ("avoid", "caution", "ok")
keys = groups | set(act_ids)
seen = set()
for p in pairs:
    for k in ("a", "b"):
        if p[k] not in keys: errs.append(("pairkey", p[k]))
    assert p["verdict"] in ("avoid_same_time", "separate_slots", "alternate_days", "ok", "good_together", "caution"), p
    assert p["confidence"] in ("high", "medium", "low")
    key = tuple(sorted((p["a"], p["b"])))
    if key in seen: errs.append(("duppair", key))
    seen.add(key)
    for s in p["sources"]:
        if s not in src_ids: errs.append(("src", key, s))
# inci duplicates across actives
inci_map = {}
for a in actives:
    for n in a["inci"]:
        k = n.lower()
        if k in inci_map: errs.append(("dupinci", n, inci_map[k], a["id"]))
        inci_map[k] = a["id"]
# group pair coverage
gl = kb["groups"]
missing = [(x, y) for i, x in enumerate(gl) for y in gl[i:] if tuple(sorted((x, y))) not in seen]
print("errors:", errs)
print("missing group pairs:", missing)
used = set(s for a in actives for s in a["sources"]) | set(s for p in pairs for s in p["sources"]) | set(s for r in rules for s in r.get("sources", []))
print("unused sources:", src_ids - used)
print("actives", len(actives), "pairs", len(pairs), "group pairs", sum(1 for p in pairs if p["a"] in groups and p["b"] in groups),
      "specific", sum(1 for p in pairs if not (p["a"] in groups and p["b"] in groups)), "myths", sum(1 for p in pairs if p.get("myth")),
      "rules", len(rules), "sources", len(sources), "inci names", len(inci_map))
if errs: sys.exit(1)
with open(OUT, "w", encoding="utf-8") as f:
    json.dump(kb, f, ensure_ascii=False, indent=1)
print("wrote", OUT)
