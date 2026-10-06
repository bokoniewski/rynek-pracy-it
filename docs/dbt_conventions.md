# Konwencje nazewnicze — dbt

Dokument opisuje konwencje nazewnicze stosowane dla modeli, plików i zmiennych w projekcie dbt znajdującym się w folderze `transform/project_job/`.

## Spis treści

1. [Zasady ogólne](#zasady-ogólne)
2. [Struktura folderów modeli](#struktura-folderów-modeli)
3. [Konwencje nazewnicze plików modeli](#konwencje-nazewnicze-plików-modeli)
   - [Staging](#staging)
   - [Intermediate — per portal](#intermediate--per-portal)
   - [Intermediate — wszystkie portale](#intermediate--wszystkie-portale)
   - [Marts Silver](#marts-silver)
   - [Marts Gold](#marts-gold)
4. [Materialization per warstwa](#materialization-per-warstwa)
5. [Zmienne (vars)](#zmienne-vars)
6. [Aliasy modeli](#aliasy-modeli)
7. [Konwencje w kodzie SQL](#konwencje-w-kodzie-sql)
8. [Testy jakości danych (tests/)](#testy-jakości-danych-tests)
9. [Makra (macros/)](#makra-macros)

---

## Zasady ogólne

- Wszystkie nazwy plików używają **snake_case** — małe litery z podkreślnikami.
- Język nazw: **angielski**.
- Nazwa pliku `.sql` = nazwa modelu w dbt = domyślna nazwa obiektu w bazie (chyba że nadpisana przez `alias`).
- Każdy plik modelu zawiera na początku komentarz z opisem przeznaczenia modelu oraz komendą uruchomienia.

---

## Struktura folderów modeli

```
models/
├── staging/          ← widoki Bronze — czyszczenie i rename kolumn
├── intermediate/     ← modele ephemeral — parsowanie i ujednolicenie danych
└── marts/
    ├── silver/       ← tabele Silver — znormalizowany model relacyjny
    └── gold/         ← tabele Gold — agregaty analityczne
```

---

## Konwencje nazewnicze plików modeli

### Staging

Modele staging to widoki odwołujące się wyłącznie do tabel w schemacie Bronze. Wykonują wyłącznie operacje techniczne — trim, nullif, rename kolumn, cast typów. Brak logiki biznesowej.

**Wzorzec:** `stg_<portal>.sql`

| Plik | Źródło Bronze |
|---|---|
| `stg_pracuj.sql` | `bronze.raw_offers_pracuj` |
| `stg_nofluff.sql` | `bronze.raw_offers_nofluff` |
| `stg_joinit.sql` | `bronze.raw_offers_joinit` |
| `stg_protocol.sql` | `bronze.raw_offers_protocol` |

Staging jest punktem wejścia dla wszystkich modeli intermediate — żaden model niżej nie sięga bezpośrednio do tabel w schemacie Bronze.

---

### Intermediate — per portal

Modele parsujące dane specyficzne dla jednego portalu. Używane gdy logika parsowania znacząco różni się per portal — np. format salary_info jest inny dla każdego źródła.

**Wzorzec:** `int_<portal>__<encja>.sql`

Podwójny podkreślnik `__` oddziela nazwę portalu od nazwy encji. To świadoma konwencja dbt oznaczająca grupowanie — wszystkie modele dla tego samego portalu są wizualnie zgrupowane.

| Plik | Portal | Opis |
|---|---|---|
| `int_pracuj__offers.sql` | pracuj.pl | Przygotowanie rekordów ofert z pracuj do silver.offers |
| `int_nofluff__offers.sql` | nofluffjobs.com | Przygotowanie rekordów ofert z nofluff do silver.offers |
| `int_joinit__offers.sql` | justjoin.it | Przygotowanie rekordów ofert z joinit do silver.offers |
| `int_protocol__offers.sql` | theprotocol.it | Przygotowanie rekordów ofert z protocol do silver.offers |
| `int_pracuj__offer_salaries.sql` | pracuj.pl | Parsowanie salary_info z pracuj — string z kwotą i walutą |
| `int_nofluff__offer_salaries.sql` | nofluffjobs.com | Parsowanie salary_info z nofluff — string z zakresem |
| `int_joinit__offer_salaries.sql` | justjoin.it | Parsowanie salary z joinit — obiekt JSON {min, max, currency, period} |
| `int_protocol__offer_salaries.sql` | theprotocol.it | Parsowanie salary_info z protocol — lista obiektów {contract_type, salary} |

---

### Intermediate — wszystkie portale

Modele łączące dane z wszystkich portali do jednego zbioru przez `UNION ALL`. Używane gdy logika jest wspólna dla wszystkich portali — np. parsowanie trybów pracy, poziomów stanowisk, benefitów.

**Wzorzec:** `int_all__<encja>.sql`

Podwójny podkreślnik `__` po `all` zachowuje spójność z konwencją per-portal. `all` oznacza że model agreguje dane ze wszystkich portali.

| Plik | Opis |
|---|---|
| `int_all__offers.sql` | Łączy oferty z portali — używa modeli `int_<portal>__offers` |
| `int_all__offer_salaries.sql` | Łączy wynagrodzenia z portali — używa modeli `int_<portal>__offer_salaries` |
| `int_all__offer_technologies.sql` | Parsuje technologie z JSONB — wymagane i opcjonalne |
| `int_all__offer_benefits.sql` | Parsuje benefity |
| `int_all__offer_locations.sql` | Normalizuje lokalizacje do wspólnego formatu |
| `int_all__offer_modes.sql` | Normalizuje tryby pracy (Remote/Hybrid/Office) |
| `int_all__offer_levels.sql` | Normalizuje poziomy stanowisk (Junior/Mid/Senior/Expert) |
| `int_all__offer_contracts.sql` | Normalizuje typy umów (B2B/UoP/Zlecenie) |
| `int_all__offer_requirements.sql` | Parsuje wymagania — wymagane i mile widziane |
| `int_all__offer_responsibilities.sql` | Parsuje zakres obowiązków |
| `int_all__offer_schedules.sql` | Parsuje harmonogram pracy |
| `int_all__offer_specs.sql` | Parsuje specjalizacje IT |

---

### Marts Silver

Modele Silver ładują dane do tabel w schemacie `silver`. Materialized jako `incremental` ze strategią `delete+insert` per `offer_date` lub `offer_id`.

**Wzorzec:** `silver_<encja>.sql`

Nazwa pliku zawiera prefix `silver_` dla jednoznacznego odróżnienia od modeli intermediate o podobnych nazwach. Alias modelu nadpisuje nazwę obiektu w bazie — model `silver_offers.sql` tworzy tabelę `silver.offers` (nie `silver.silver_offers`).

| Plik | Alias (tabela w bazie) | Opis |
|---|---|---|
| `silver_offers.sql` | `silver.offers` | Główna tabela ofert |
| `silver_offer_salaries.sql` | `silver.offer_salaries` | Wynagrodzenia per oferta |
| `silver_offer_technologies.sql` | `silver.offer_technologies` | Technologie per oferta |
| `silver_offer_benefits.sql` | `silver.offer_benefits` | Benefity per oferta |
| `silver_offer_locations.sql` | `silver.offer_locations` | Lokalizacje per oferta |
| `silver_offer_modes.sql` | `silver.offer_modes` | Tryby pracy per oferta |
| `silver_offer_levels.sql` | `silver.offer_levels` | Poziomy stanowisk per oferta |
| `silver_offer_contracts.sql` | `silver.offer_contracts` | Typy umów per oferta |
| `silver_offer_requirements.sql` | `silver.offer_requirements` | Wymagania per oferta |
| `silver_offer_responsibilities.sql` | `silver.offer_responsibilities` | Zakres obowiązków per oferta |
| `silver_offer_specs.sql` | `silver.offer_specs` | Specjalizacje IT per oferta |
| `silver_offer_schedules.sql` | `silver.offer_schedules` | Harmonogram pracy per oferta |

---

### Marts Gold

Modele Gold budują warstę analityczną. Konwencje nazewnicze plików są spójne z konwencjami tabel Gold w bazie danych.

**Wzorzec staging Gold:** `stg_gold_<encja>.sql`

Widok staging filtrujący dane Silver po `FILE_DATE` — punkt wejścia dla wszystkich modeli faktów Gold.

| Plik | Opis |
|---|---|
| `stg_gold_offers.sql` | Widok na `silver.offers` przefiltrowany po `FILE_DATE` |

**Wzorzec faktów dziennych:** `f_day_<encja>.sql`

| Plik | Opis |
|---|---|
| `f_day_offers.sql` | Liczba ofert per dzień z wymiarami |
| `f_day_offers_loc.sql` | Oferty per dzień z lokalizacją |
| `f_day_salaries.sql` | Wynagrodzenia per dzień znormalizowane do stawki miesięcznej |
| `f_day_offers_technology.sql` | Technologie per dzień |
| `f_day_offers_benefit.sql` | Benefity per dzień |

**Wzorzec agregacji miesięcznych:** `f_month_<encja>_agg.sql`

Sufiks `_agg` oznacza model agregujący dane z tabel dziennych — nie jest bezpośrednio zasilany ze Silver.

| Plik | Opis |
|---|---|
| `f_month_offers_agg.sql` | Agregat miesięczny ofert z `f_day_offers` |
| `f_month_offers_loc_agg.sql` | Agregat miesięczny lokalizacji z `f_day_offers_loc` |
| `f_month_salaries_agg.sql` | Agregat miesięczny wynagrodzeń z `f_day_salaries` |

**Wzorzec agregacji rocznych:** `f_year_<encja>_agg.sql`

| Plik | Opis |
|---|---|
| `f_year_offers_agg.sql` | Agregat roczny ofert |
| `f_year_offers_loc_agg.sql` | Agregat roczny lokalizacji |
| `f_year_salaries_agg.sql` | Agregat roczny wynagrodzeń |

---

## Materialization per warstwa

Każda warstwa ma określony typ materializacji zdefiniowany w `dbt_project.yml` i nadpisywany w plikach modeli przez `{{ config(...) }}`:

| Warstwa | Folder | Materialization | Strategia |
|---|---|---|---|
| Staging | `staging/` | `view` | — |
| Intermediate per portal | `intermediate/` | `ephemeral` | — |
| Intermediate all | `intermediate/` | `ephemeral` | — |
| Silver | `marts/silver/` | `incremental` | `delete+insert` per `offer_date` / `offer_id` |
| Gold — stg | `marts/gold/` | `view` | — |
| Gold — f_day | `marts/gold/` | `incremental` | `delete+insert` per `d_date_id` |
| Gold — f_month | `marts/gold/` | `incremental` | `delete+insert` per `year + month` |
| Gold — f_year | `marts/gold/` | `incremental` | `delete+insert` per `year` |

**Ephemeral** — modele intermediate nie tworzą żadnych obiektów w bazie. Są wbudowywane jako CTE do modeli które je wywołują przez `{{ ref(...) }}`. Dzięki temu baza nie ma zbędnych obiektów pośredniczących w procesie.

---

## Zmienne (vars)

Projekt używa dwóch zmiennych przekazywanych przez Airflow przy uruchomieniu:

| Zmienna | Typ | Wartość domyślna | Opis |
|---|---|---|---|
| `FILE_DATE` | `DATE` string `'YYYY-MM-DD'` | `'1899-12-30'` | Data pliku JSON do przetworzenia — filtruje dane we wszystkich modelach |
| `portals` | lista stringów | `['pracuj', 'joinit', 'nofluff', 'protocol']` | Lista portali do przetworzenia — pozwala uruchomić pipeline dla wybranego portalu |

Wartość domyślna `1899-12-30` dla `FILE_DATE` jest celowa — zwraca pusty wynik zamiast crashować model gdy zmienna nie zostanie przekazana.

**Przekazanie przez Airflow (BashOperator):**
```bash
dbt run --profiles-dir . --select +silver_offers \
  --vars '{"FILE_DATE": "{{ run_date }}"}'
```

**Uruchomienie ręczne dla jednego portalu:**
```bash
dbt run --profiles-dir . --select silver_offer_salaries \
  --vars '{"FILE_DATE": "2026-05-15", "portals": ["pracuj"]}'
```

---

## Aliasy modeli

Modele Silver używają `alias` w konfiguracji żeby nazwa tabeli w bazie nie zawierała prefiksu `silver_`:

```sql
{{ config(
    materialized = 'incremental',
    alias        = 'offers'       -- tworzy silver.offers, nie silver.silver_offers
) }}
```

Modele Gold nie używają aliasów — nazwa pliku odpowiada bezpośrednio nazwie tabeli w bazie (`f_day_offers.sql` → `gold.f_day_offers`).

---

## Konwencje w kodzie SQL

**Komentarz nagłówkowy** — każdy plik modelu zaczyna się od komentarza zawierającego:
- ścieżkę pliku
- opis przeznaczenia modelu
- komendę uruchomienia przez CLI

```sql
-- models/staging/stg_pracuj.sql
-- Czyszczenie i rename kolumn z bronze.raw_offers_pracuj
-- Brak logiki biznesowej — tylko trim, cast, rename
-- wywolanie w cmd: dbt run --profiles-dir . --select stg_pracuj --vars "{\"FILE_DATE\": \"2026-03-23\"}"
```

**Prefix `+` przy uruchamianiu Silver** — modele Silver wymagają uruchomienia z prefiksem `+` który nakazuje dbt uruchomić też wszystkie modele od których zależy (staging i intermediate):

```bash
dbt run --profiles-dir . --select +silver_offers
```

Bez `+` model Silver nie zadziała bo modele intermediate są ephemeral i muszą być uruchomione razem z modelem który je wywołuje.


---

## Testy jakości danych (tests/)

Testy jakości danych dla warstwy Silver zaimplementowane jako **singular tests** — osobny plik SQL per model w folderze `tests/`. Każdy plik zwraca wiersze gdy dane nie spełniają warunków — brak wierszy oznacza test passed.

**Wzorzec nazewnictwa:** `<nazwa_modelu>.sql`

Jeden plik per model Silver — nazwa pliku odpowiada nazwie testowanego modelu:

| Plik | Testowany model |
|---|---|
| `silver_offers.sql` | `silver.offers` |
| `silver_offer_salaries.sql` | `silver.offer_salaries` |
| `silver_offer_technologies.sql` | `silver.offer_technologies` |
| `silver_offer_benefits.sql` | `silver.offer_benefits` |
| `silver_offer_locations.sql` | `silver.offer_locations` |
| `silver_offer_modes.sql` | `silver.offer_modes` |
| `silver_offer_levels.sql` | `silver.offer_levels` |
| `silver_offer_contracts.sql` | `silver.offer_contracts` |
| `silver_offer_requirements.sql` | `silver.offer_requirements` |
| `silver_offer_responsibilities.sql` | `silver.offer_responsibilities` |
| `silver_offer_specs.sql` | `silver.offer_specs` |
| `silver_offer_schedules.sql` | `silver.offer_schedules` |

Singular tests zamiast `schema.yml` z powodu ograniczenia parsera dbt 1.7 — makra Jinja nie są obsługiwane w konfiguracji `config.where` dla testów generycznych. W plikach SQL makra działają bez ograniczeń.

Każdy test ograniczony do danych z bieżącego dnia przez makra `file_date_filter()` i `file_date_filter_by_offer_id()` — szczegóły w sekcji [Makra](#makra-macros).

Uruchomienie testów Silver:
```bash
dbt test --profiles-dir . --select silver_offers silver_offer_salaries silver_offer_technologies silver_offer_benefits silver_offer_locations silver_offer_modes silver_offer_levels silver_offer_contracts silver_offer_requirements silver_offer_responsibilities silver_offer_specs silver_offer_schedules --vars "{FILE_DATE: YYYY-MM-DD}"
```

---

## Makra (macros/)

Projekt używa dwóch plików z makrami w folderze `macros/`.

### generate_schema_name.sql

Nadpisuje domyślne zachowanie dbt przy budowaniu nazwy schematu. Bez tego makra dbt doklejałby `target.schema` jako prefiks do każdego custom schema — modele Silver lądowałyby w `silver_silver` zamiast `silver`. Makro wywoływane automatycznie przez dbt przy każdym `dbt run`.

### filter_file_date.sql

Centralizuje filtr po `FILE_DATE` używany w testach Silver. Zawiera dwa makra:

**`file_date_filter()`** — filtr bezpośredni dla `silver.offers` gdzie kolumna `offer_date` jest dostępna:

```sql
offer_date = CAST('{{ var("FILE_DATE", "1899-12-30") }}' AS DATE)
```

**`file_date_filter_by_offer_id()`** — filtr przez podzapytanie dla tabel szczegółowych Silver gdzie nie ma kolumny `offer_date`:

```sql
offer_id IN (
    SELECT id FROM silver.offers
    WHERE offer_date = CAST('{{ var("FILE_DATE", "1899-12-30") }}' AS DATE)
)
```

Wartość domyślna `1899-12-30` jest celowa — przy braku `FILE_DATE` zwraca pusty wynik zamiast crashować test. Używane wyłącznie w plikach `tests/` — makra w `config.where` dla testów generycznych nie są obsługiwane przez parser dbt 1.7.