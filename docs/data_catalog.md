# Katalog danych — Data-Pipeline-rynek-pracy-IT

Dokument opisuje wszystkie obiekty bazodanowe projektu — tabele, widoki, procedury i funkcje we wszystkich schematach. Dane zorganizowane są warstwowo zgodnie z architekturą Medallion.

## Spis treści

1. [Schemat Bronze](#schemat-bronze)
   - [Tabele danych](#tabele-danych)
   - [Tabela audytowa](#tabela-audytowa)
   - [Widoki data quality](#widoki-data-quality-bronze)
2. [Schemat Silver](#schemat-silver)
   - [Tabele słownikowe](#tabele-słownikowe)
   - [Tabela główna ofert](#tabela-główna-ofert)
   - [Tabele szczegółowe ofert](#tabele-szczegółowe-ofert)
   - [Widoki data quality](#widoki-data-quality-silver)
3. [Schemat Gold](#schemat-gold)
   - [Tabele wymiarów](#tabele-wymiarów)
   - [Tabele faktów dziennych](#tabele-faktów-dziennych)
   - [Tabele agregacji miesięcznych](#tabele-agregacji-miesięcznych)
   - [Tabele agregacji rocznych](#tabele-agregacji-rocznych)
   - [Widoki diagnostyczne](#widoki-diagnostyczne-gold)
4. [Schemat Maintenance](#schemat-maintenance)
   - [Tabele pipeline](#tabele-pipeline)
   - [Widoki monitoringu dysku](#widoki-monitoringu-dysku)
   - [Procedury i funkcje](#procedury-i-funkcje)

---

## Schemat Bronze

Schemat `bronze` przechowuje surowe dane wgrane bezpośrednio z plików JSON. Dane trafiają tu bez żadnych transformacji ani walidacji — 1:1.

---

### Tabele danych

#### **Nazwa:** bronze.raw_offers_pracuj

**Przeznaczenie:** Surowe oferty pracy z portalu pracuj.pl.

**Źródło:** Loader `load_raw_pracuj.py` → plik JSON `pracuj_YYYYMMDD_HHMMSS.json`

| Kolumna | Typ | Opis |
|---|---|---|
| `raw_id` | SERIAL PK | Klucz techniczny — auto-inkrementowany identyfikator rekordu |
| `source_file_id` | INT FK | Powiązanie z `bronze.audit_file_log.file_id` — skąd pochodzi rekord |
| `offer_id` | TEXT | Natywne ID oferty z portalu pracuj.pl |
| `url` | TEXT | Bezpośredni link do oferty |
| `title` | TEXT | Tytuł stanowiska |
| `employer` | TEXT | Nazwa pracodawcy |
| `employer_address` | TEXT | Adres pracodawcy jako string |
| `job_workplace` | TEXT | Miejsce pracy |
| `job_contract` | TEXT | Typ umowy (surowy tekst z portalu) |
| `job_schedule` | TEXT | Harmonogram pracy (surowy tekst) |
| `employment_type` | TEXT | Poziom stanowiska (surowy tekst: Senior/Mid/Junior) |
| `job_modes` | TEXT | Tryb pracy (surowy tekst) |
| `specialization` | TEXT | Specjalizacja IT (surowy tekst) |
| `salary_info` | JSONB | Informacje o wynagrodzeniu jako lista/obiekt JSON |
| `technology_expected` | JSONB | Lista wymaganych technologii |
| `technology_optional` | JSONB | Lista opcjonalnych technologii |
| `responsibilities` | JSONB | Lista obowiązków |
| `requirements_expected` | JSONB | Lista wymagań obowiązkowych |
| `requirements_optional` | JSONB | Lista wymagań opcjonalnych |
| `offered` | JSONB | Wolny opis benefitów pracodawcy |
| `benefits` | JSONB | Lista ustandaryzowanych benefitów portalu |
| `loaded_at` | TIMESTAMP | Czas załadowania rekordu do bazy |

---

#### **Nazwa:** bronze.raw_offers_nofluff

**Przeznaczenie:** Surowe oferty pracy z portalu nofluffjobs.com.

**Źródło:** Loader `load_raw_nofluff.py` → plik JSON `nofluff_YYYYMMDD_HHMMSS.json`

| Kolumna | Typ | Opis |
|---|---|---|
| `raw_id` | SERIAL PK | Klucz techniczny |
| `source_file_id` | INT FK | Powiązanie z `bronze.audit_file_log.file_id` |
| `offer_id` | TEXT | Natywne ID oferty — MD5 hash z URL |
| `url` | TEXT | Bezpośredni link do oferty |
| `job_title` | TEXT | Tytuł stanowiska |
| `employer` | TEXT | Nazwa pracodawcy |
| `employer_address` | JSONB | Adresy pracodawcy jako lista (nofluff może mieć kilka lokalizacji) |
| `job_level` | TEXT | Poziom stanowiska (surowy tekst) |
| `job_modes` | TEXT | Tryb pracy — pierwsza wartość |
| `job_modes_2` | TEXT | Tryb pracy — druga wartość (nofluff rozróżnia dwa tryby) |
| `specialization` | JSONB | Specjalizacja IT |
| `salary_info` | JSONB | Wynagrodzenie jako lista stringów z typem umowy |
| `technology_expected` | JSONB | Lista wymaganych technologii |
| `technology_optional` | JSONB | Lista opcjonalnych technologii |
| `requirements_expected` | JSONB | Lista wymagań obowiązkowych |
| `requirements_optional` | JSONB | Lista wymagań opcjonalnych |
| `responsibilities` | JSONB | Lista obowiązków |
| `details_responsibilities` | JSONB | Dodatkowe warunki oferty (Start ASAP itp.) |
| `office_benefits` | JSONB | Udogodnienia biurowe (osobna lista — specyfika nofluff) |
| `benefits` | JSONB | Lista benefitów pracowniczych |
| `loaded_at` | TIMESTAMP | Czas załadowania rekordu do bazy |

---

#### **Nazwa:** bronze.raw_offers_joinit

**Przeznaczenie:** Surowe oferty pracy z portalu justjoin.it.

**Źródło:** Loader `load_raw_joinit.py` → plik JSON `joinit_YYYYMMDD_HHMMSS.json`

| Kolumna | Typ | Opis |
|---|---|---|
| `raw_id` | SERIAL PK | Klucz techniczny |
| `source_file_id` | INT FK | Powiązanie z `bronze.audit_file_log.file_id` |
| `offer_id` | TEXT | Natywne ID oferty — MD5 hash z URL |
| `url` | TEXT | Bezpośredni link do oferty |
| `title` | TEXT | Tytuł stanowiska |
| `employer` | TEXT | Nazwa pracodawcy |
| `employer_url` | TEXT | URL strony pracodawcy |
| `seniority` | TEXT | Poziom stanowiska (surowy tekst) |
| `job_schedule` | TEXT | Harmonogram pracy |
| `job_contract` | TEXT | Typ umowy |
| `job_mode` | TEXT | Tryb pracy |
| `specialization` | TEXT | Specjalizacja IT |
| `location_city` | TEXT | Miasto — joinit jako jedyny portal ma rozbitą lokalizację |
| `location_region` | TEXT | Województwo / region |
| `location_street` | TEXT | Ulica |
| `location_postal_code` | TEXT | Kod pocztowy |
| `location_country` | TEXT | Kraj |
| `date_posted` | TIMESTAMP | Data publikacji oferty |
| `valid_through` | TIMESTAMP | Data ważności oferty |
| `salary` | JSONB | Wynagrodzenie jako obiekt `{min, max, currency, period}` |
| `tech_stack` | JSONB | Stos technologiczny jako lista obiektów `{name, level}` |
| `loaded_at` | TIMESTAMP | Czas załadowania rekordu do bazy |

---

#### **Nazwa:** bronze.raw_offers_protocol

**Przeznaczenie:** Surowe oferty pracy z portalu theprotocol.it.

**Źródło:** Loader `load_raw_protocol.py` → plik JSON `protocol_YYYYMMDD_HHMMSS.json`

| Kolumna | Typ | Opis |
|---|---|---|
| `raw_id` | SERIAL PK | Klucz techniczny |
| `source_file_id` | INT FK | Powiązanie z `bronze.audit_file_log.file_id` |
| `offer_id` | TEXT | Natywne ID oferty — MD5 hash z URL |
| `url` | TEXT | Bezpośredni link do oferty |
| `offer_title` | TEXT | Tytuł stanowiska |
| `offer_company` | TEXT | Nazwa pracodawcy |
| `offer_level` | TEXT | Poziom stanowiska (surowy tekst) |
| `offer_modes` | TEXT | Tryb pracy (surowy tekst) |
| `offer_location` | TEXT | Lokalizacja jako surowy string |
| `salary_info` | JSONB | Wynagrodzenie jako lista obiektów `{contract_type, salary}` — może zawierać kilka typów umów |
| `tech_required` | JSONB | Lista wymaganych technologii |
| `tech_optional` | JSONB | Lista opcjonalnych technologii |
| `offer_responsibilities` | JSONB | Lista obowiązków |
| `offer_requirements` | JSONB | Lista wymagań |
| `offer_nice_to_have` | JSONB | Mile widziane — osobne pole (specyfika protocol) |
| `offer_offered` | JSONB | Opis benefitów od pracodawcy |
| `offer_benefits` | JSONB | Lista ustandaryzowanych benefitów |
| `loaded_at` | TIMESTAMP | Czas załadowania rekordu do bazy |

---

### Tabela audytowa

#### **Nazwa:** bronze.audit_file_log

**Przeznaczenie:** Log plików JSON załadowanych do Bronze. Każdy loader przed insertem tworzy rekord w tej tabeli. Rekord powiązany jest ze wszystkimi ofertami z danego pliku przez klucz `file_id`.

| Kolumna | Typ | Opis |
|---|---|---|
| `file_id` | SERIAL PK | Klucz techniczny |
| `file_name` | TEXT | Nazwa pliku JSON (np. `nofluff_20260315_164131.json`) |
| `file_date` | DATE | Data wyciągnięta z nazwy pliku |
| `portal` | TEXT | Nazwa portalu: `pracuj` / `nofluff` / `joinit` / `protocol` |
| `total_records` | INT | Liczba rekordów w pliku JSON |
| `status` | TEXT | Status przetwarzania: `SUCCESS` / `PARTIAL` / `ERROR` |
| `loaded_at` | TIMESTAMP | Czas załadowania pliku |

---

### Widoki data quality Bronze

#### **Nazwa:** bronze.v_test_data_raw_offers

**Przeznaczenie:** Sprawdzenie czy obligatoryjne kolumny ofert są wypełnione po wgraniu do Bronze. Wskazuje które oferty mają brakujące dane (NULL lub 'N/A') w kluczowych polach takich jak tytuł, pracodawca, poziom stanowiska, tryb pracy, lokalizacja.

**Zwraca:** Listę `(portal, offer_id, brakujace_dane)` — kolumna `brakujace_dane` zawiera nazwy kolumn z brakującymi wartościami jako string oddzielony przecinkami.

---

#### **Nazwa:** bronze.v_test_double_raw_offers

**Przeznaczenie:** Wykrywanie duplikatów wgranych ofert — sprawdza czy ten sam `offer_id` pojawia się więcej niż raz w danym dniu.

**Zwraca:** Listę `(portal, offer_id, double)` — kolumna `double` = `'TAK'` dla duplikatów.

---

## Schemat Silver

Schemat `silver` przechowuje dane oczyszczone i znormalizowane do wspólnego modelu relacyjnego. Dane z portali są ujednolicone do jednego schematu przez transformacje dbt.

---

### Tabele słownikowe

#### **Nazwa:** silver.def_portal

**Przeznaczenie:** Słownik portali — lista aktywnych źródeł danych. Zasilany ręcznie.

| Kolumna | Typ | Opis |
|---|---|---|
| `id` | SERIAL PK | Klucz techniczny |
| `portal_name` | TEXT | Nazwa portalu: `pracuj` / `nofluff` / `joinit` / `protocol` |
| `portal_url` | TEXT | Bazowy URL portalu |
| `is_active` | BOOLEAN | Czy portal jest aktywnie przetwarzany — domyślnie `TRUE` |
| `created_at` | TIMESTAMP | Czas dodania rekordu |

---

#### **Nazwa:** silver.def_requirement_type

**Przeznaczenie:** Słownik typów wymagalności technologii i umiejętności. Zasilany ręcznie.

| Kolumna | Typ | Opis |
|---|---|---|
| `id` | SERIAL PK | Klucz techniczny |
| `requirement_type_name` | TEXT | Typ wymagalności: `wymagane` / `opcjonalne` |
| `created_at` | TIMESTAMP | Czas dodania rekordu |

---

### Tabela główna ofert

#### **Nazwa:** silver.offers

**Przeznaczenie:** Główna tabela ofert pracy — jeden rekord per oferta. Wszystkie pozostałe tabele Silver są z nią powiązane przez klucz obcy `offer_id`.

| Kolumna | Typ | Opis |
|---|---|---|
| `id` | SERIAL PK | Klucz techniczny |
| `portal_id` | INT FK | Powiązanie z `silver.def_portal.id` |
| `bronze_file_id` | INT FK | Powiązanie z `bronze.audit_file_log.file_id` |
| `source_offer_id` | TEXT | Oryginalne ID oferty z portalu źródłowego |
| `url` | TEXT | Bezpośredni link do oferty |
| `title` | TEXT | Tytuł stanowiska — oczyszczony (trim, nullif) |
| `company_name` | TEXT | Nazwa firmy — oczyszczona |
| `offer_date` | DATE | Data oferty — pochodzi z `file_date` w audit_file_log |
| `created_at` | TIMESTAMP | Czas załadowania do Silver |

---

### Tabele szczegółowe ofert

Wszystkie tabele poniżej mają relację many-to-many z `silver.offers` przez klucz `offer_id`. Jedna oferta może mieć wiele rekordów w każdej z tabel.

#### **Nazwa:** silver.offer_salaries

**Przeznaczenie:** Wynagrodzenia per oferta. Jedna oferta może mieć kilka rekordów — osobno dla B2B i UoP.

| Kolumna | Typ | Opis |
|---|---|---|
| `id` | SERIAL PK | Klucz techniczny |
| `offer_id` | INT FK → `silver.offers.id` | Powiązanie z ofertą |
| `contract_type` | TEXT | Typ umowy: `B2B` / `UoP` / `Umowa zlecenie` |
| `salary_min` | NUMERIC | Minimalne wynagrodzenie |
| `salary_max` | NUMERIC | Maksymalne wynagrodzenie |
| `currency` | TEXT | Waluta: `PLN` / `EUR` |
| `period` | TEXT | Okres: `MONTHLY` / `HOURLY` / `DAILY` / `ANNUALLY` |
| `salary_type` | TEXT | Typ wynagrodzenia: `Netto` / `Brutto` |

---

#### **Nazwa:** silver.offer_technologies

**Przeznaczenie:** Technologie per oferta z podziałem na wymagane i opcjonalne.

| Kolumna | Typ | Opis |
|---|---|---|
| `id` | SERIAL PK | Klucz techniczny |
| `offer_id` | INT FK → `silver.offers.id` | Powiązanie z ofertą |
| `technology_name` | TEXT | Nazwa technologii (np. `Python`, `Docker`, `SQL`) |
| `requirement_type_id` | INT FK → `silver.def_requirement_type.id` | Typ wymagalności: `1 = wymagane` / `2 = opcjonalne` |

---

#### **Nazwa:** silver.offer_benefits

**Przeznaczenie:** Benefity per oferta.

| Kolumna | Typ | Opis |
|---|---|---|
| `id` | SERIAL PK | Klucz techniczny |
| `offer_id` | INT FK → `silver.offers.id` | Powiązanie z ofertą |
| `benefit_name` | TEXT | Nazwa benefitu (surowy tekst z portalu) |

---

#### **Nazwa:** silver.offer_locations

**Przeznaczenie:** Lokalizacje per oferta. Jedna oferta może mieć kilka lokalizacji.

| Kolumna | Typ | Opis |
|---|---|---|
| `id` | SERIAL PK | Klucz techniczny |
| `offer_id` | INT FK → `silver.offers.id` | Powiązanie z ofertą |
| `city` | TEXT | Miasto |
| `region` | TEXT | Województwo / region |
| `country` | TEXT | Kraj — domyślnie `PL` |

---

#### **Nazwa:** silver.offer_modes

**Przeznaczenie:** Tryby pracy per oferta — znormalizowane do wartości: `Remote`, `Hybrid`, `Office`, `Mobile`.

| Kolumna | Typ | Opis |
|---|---|---|
| `id` | SERIAL PK | Klucz techniczny |
| `offer_id` | INT FK → `silver.offers.id` | Powiązanie z ofertą |
| `mode_name` | TEXT | Tryb pracy: `Remote` / `Hybrid` / `Office` / `Mobile` |

---

#### **Nazwa:** silver.offer_levels

**Przeznaczenie:** Poziomy stanowiska per oferta — znormalizowane do: `Trainee`, `Junior`, `Mid`, `Senior`, `Expert`, `Manager`, `Director`.

| Kolumna | Typ | Opis |
|---|---|---|
| `id` | SERIAL PK | Klucz techniczny |
| `offer_id` | INT FK → `silver.offers.id` | Powiązanie z ofertą |
| `level_name` | TEXT | Poziom stanowiska: `Junior` / `Mid` / `Senior` / `Expert` |

---

#### **Nazwa:** silver.offer_contracts

**Przeznaczenie:** Typy umów per oferta — znormalizowane do: `B2B`, `UoP`, `Umowa zlecenie`, `Umowa na zastępstwo`, `Umowa o dzieło`, `Umowa o staż`.

| Kolumna | Typ | Opis |
|---|---|---|
| `id` | SERIAL PK | Klucz techniczny |
| `offer_id` | INT FK → `silver.offers.id` | Powiązanie z ofertą |
| `contract_name` | TEXT | Typ umowy: `B2B` / `UoP` / `Umowa zlecenie` |

---

#### **Nazwa:** silver.offer_requirements

**Przeznaczenie:** Wymagania per oferta z podziałem na obowiązkowe i mile widziane.

| Kolumna | Typ | Opis |
|---|---|---|
| `id` | SERIAL PK | Klucz techniczny |
| `offer_id` | INT FK → `silver.offers.id` | Powiązanie z ofertą |
| `requirement_text` | TEXT | Treść wymagania |
| `requirement_type_id` | INT FK → `silver.def_requirement_type.id` | Typ: `1 = wymagane` / `2 = opcjonalne` |

---

#### **Nazwa:** silver.offer_responsibilities

**Przeznaczenie:** Zakres obowiązków per oferta.

| Kolumna | Typ | Opis |
|---|---|---|
| `id` | SERIAL PK | Klucz techniczny |
| `offer_id` | INT FK → `silver.offers.id` | Powiązanie z ofertą |
| `responsibility_text` | TEXT | Treść obowiązku |

---

#### **Nazwa:** silver.offer_specs

**Przeznaczenie:** Specjalizacje IT per oferta — surowe wartości z portali przed mapowaniem do wymiarów Gold.

| Kolumna | Typ | Opis |
|---|---|---|
| `id` | SERIAL PK | Klucz techniczny |
| `offer_id` | INT FK → `silver.offers.id` | Powiązanie z ofertą |
| `specialization_name` | TEXT | Nazwa specjalizacji (np. `Data Engineering`, `Backend`) |

---

#### **Nazwa:** silver.offer_schedules

**Przeznaczenie:** Harmonogram pracy per oferta — etat pełny, częściowy, freelance.

| Kolumna | Typ | Opis |
|---|---|---|
| `id` | SERIAL PK | Klucz techniczny |
| `offer_id` | INT FK → `silver.offers.id` | Powiązanie z ofertą |
| `schedule_name` | TEXT | Harmonogram: `Full-time` / `Part-time` / `Freelance` |

---

### Widoki data quality Silver

Wszystkie widoki data quality Silver sprawdzają wyłącznie dane z **ostatnio wgranego pliku** (`offer_date = max(offer_date)`).

#### **Nazwa:** silver.v_test_data_offer_benefits

**Przeznaczenie:** Benefity z tabeli `silver.offer_benefits` które nie pasują do żadnego wzorca (`like_patterns`) z tabeli `gold.d_benefit`. Wskazuje benefity do dodania do wymiaru Gold lub do poprawki mapowania.

**Zwraca:** `(benefit_name, cnt)` — posortowane malejąco po liczbie wystąpień.

---

#### **Nazwa:** silver.v_test_data_offer_contracts

**Przeznaczenie:** Oferty których typ umowy nie istnieje w słowniku `gold.d_contract`.

**Zwraca:** `(id, offer_id, contract_name)`.

---

#### **Nazwa:** silver.v_test_data_offer_levels

**Przeznaczenie:** Oferty których poziom stanowiska jest NULL lub nie istnieje w słowniku `gold.d_level`.

**Zwraca:** `(id, offer_id, level_name)`.

---

#### **Nazwa:** silver.v_test_data_offer_modes

**Przeznaczenie:** Oferty których tryb pracy nie należy do dozwolonych wartości (`Hybrid`, `Office`, `Remote`, `Mobile`) ani nie istnieje w `gold.d_mode`.

**Zwraca:** `(id, offer_id, mode_name)`.

---

#### **Nazwa:** silver.v_test_data_offer_salaries

**Przeznaczenie:** Wynagrodzenia z brakującymi wartościami w obligatoryjnych kolumnach (`contract_type`, `salary_min`, `salary_max`, `currency`, `period`, `salary_type`) lub z typem umowy niepasującym do `gold.d_contract`.

**Zwraca:** `(id, offer_id, url, contract_type, salary_min, salary_max, currency, period, salary_type)`.

---

#### **Nazwa:** silver.v_test_data_offer_schedules

**Przeznaczenie:** Oferty z NULL w kolumnie `schedule_name`.

**Zwraca:** `(id, offer_id, schedule_name)`.

---

#### **Nazwa:** silver.v_test_data_offer_specs

**Przeznaczenie:** Specjalizacje które nie pasują do żadnego aliasu w `gold.d_specs`. Wskazuje specjalizacje do dodania do wymiaru lub do poprawki mapowania.

**Zwraca:** `(offer_id, offer_date, spec)` — `spec` to concat wszystkich niedopasowanych specjalizacji per oferta.

---

#### **Nazwa:** silver.v_test_data_offer_tech

**Przeznaczenie:** Technologie które nie pasują do żadnego wzorca (`like_patterns`) w `gold.d_technology`. Wskazuje technologie do dodania do wymiaru lub do poprawki wzorców.

**Zwraca:** `(technology_name, cnt)` — posortowane malejąco po liczbie wystąpień.

---

## Schemat Gold

Schemat `gold` przechowuje model wymiarowy gotowy pod narzędzia BI. Składa się z tabel wymiarów (prefiks `d_`) i tabel faktów (prefiks `f_`).

---

### Tabele wymiarów

#### **Nazwa:** gold.d_date

**Przeznaczenie:** Wymiar czasu — zawiera wszystkie daty w projekcie. Klucz główny `d_date_id` w formacie `YYYYMMDD` jako INT (np. `20260315`).

| Kolumna | Typ | Opis |
|---|---|---|
| `d_date_id` | INT PK | Klucz w formacie YYYYMMDD — np. `20260315` |
| `date_actual` | DATE | Faktyczna data |
| `day` | INT | Dzień miesiąca (1–31) |
| `month` | INT | Numer miesiąca (1–12) |
| `month_name` | TEXT | Nazwa miesiąca: `Styczeń`, `Luty`, ... |
| `quarter` | INT | Kwartał (1–4) |
| `year` | INT | Rok |
| `week` | INT | Numer tygodnia ISO |
| `day_of_week` | INT | Dzień tygodnia (1–7) |
| `is_weekend` | BOOLEAN | Czy dzień jest dniem wolnym |

---

#### **Nazwa:** gold.d_specs

**Przeznaczenie:** Wymiar specjalizacji IT. Każda specjalizacja ma listę aliasów (`spec_aliases`) używanych do dopasowania surowych wartości ze Silver przez operator `@>`.

| Kolumna | Typ | Opis |
|---|---|---|
| `d_spec_id` | SERIAL PK | Klucz wymiaru |
| `spec_name` | TEXT | Nazwa specjalizacji: `Data Engineering`, `Backend`, `DevOps` |
| `spec_aliases` | JSONB | Lista aliasów do dopasowania — np. `["Data Engineer", "Data Engineering", "DE"]` |
| `priority` | INT | Priorytet przy remisach — `1` = najwyższy |
| `created_at` | TIMESTAMP | Czas dodania rekordu — domyślnie `NOW()` |

---

#### **Nazwa:** gold.d_level

**Przeznaczenie:** Wymiar poziomu doświadczenia.

| Kolumna | Typ | Opis |
|---|---|---|
| `d_level_id` | SERIAL PK | Klucz wymiaru |
| `level_name` | TEXT | Poziom: `Junior` / `Mid` / `Senior` / `Expert` / `Manager` / `Director` |
| `created_at` | TIMESTAMP | Czas dodania rekordu — domyślnie `NOW()` |

---

#### **Nazwa:** gold.d_mode

**Przeznaczenie:** Wymiar trybu pracy. Wartości polskie dla spójności z danymi Silver.

| Kolumna | Typ | Opis |
|---|---|---|
| `d_mode_id` | SERIAL PK | Klucz wymiaru |
| `mode_name` | TEXT | Tryb: `Zdalnie` / `Hybrydowo` / `Biuro` / `W terenie` |
| `created_at` | TIMESTAMP | Czas dodania rekordu — domyślnie `NOW()` |

---

#### **Nazwa:** gold.d_contract

**Przeznaczenie:** Wymiar typu umowy.

| Kolumna | Typ | Opis |
|---|---|---|
| `d_contract_id` | SERIAL PK | Klucz wymiaru |
| `contract_name` | TEXT | Typ umowy: `B2B` / `UoP` / `Umowa zlecenie` / `Umowa na zastępstwo` |
| `created_at` | TIMESTAMP | Czas dodania rekordu — domyślnie `NOW()` |

---

#### **Nazwa:** gold.d_technology

**Przeznaczenie:** Wymiar technologii. Każda technologia ma listę wzorców `like_patterns` używanych do dopasowania nazw ze Silver przez operacje `LIKE`.

| Kolumna | Typ | Opis |
|---|---|---|
| `d_tech_id` | SERIAL PK | Klucz wymiaru |
| `tech_name` | TEXT | Ustandaryzowana nazwa: `Python`, `Docker`, `SQL`, `Angielski` |
| `like_patterns` | JSONB | Lista wzorców LIKE — np. `["%python%", "%Python 3%"]` |
| `created_at` | TIMESTAMP | Czas dodania rekordu — domyślnie `NOW()` |

---

#### **Nazwa:** gold.d_benefit

**Przeznaczenie:** Wymiar benefitów. Analogicznie do technologii — dopasowanie przez `like_patterns`.

| Kolumna | Typ | Opis |
|---|---|---|
| `d_benefit_id` | SERIAL PK | Klucz wymiaru |
| `benefit_name` | TEXT | Ustandaryzowana nazwa benefitu: `Praca zdalna`, `Ubezpieczenie zdrowotne` |
| `like_patterns` | JSONB | Lista wzorców LIKE do dopasowania surowych wartości ze Silver |
| `created_at` | TIMESTAMP | Czas dodania rekordu — domyślnie `NOW()` |

---

#### **Nazwa:** gold.d_location

**Przeznaczenie:** Wymiar lokalizacji — lista polskich miast z wzorcami dopasowania. Obsługuje różne formy nazw miast (polskie i angielskie) przez `like_patterns`.

| Kolumna | Typ | Opis |
|---|---|---|
| `d_location_id` | SERIAL PK | Klucz wymiaru |
| `city` | TEXT | Ustandaryzowana nazwa miasta: `Warszawa`, `Kraków`, `Wrocław` |
| `region` | TEXT | Województwo |
| `country` | TEXT | Kraj — domyślnie `PL` |
| `like_patterns` | JSONB | Lista wzorców — np. `["Warsaw", "Warszawa"]` dla obsługi anglojęzycznych nazw |
| `created_at` | TIMESTAMP | Czas dodania rekordu — domyślnie `NOW()` |

---

#### **Nazwa:** gold.d_requirement_type

**Przeznaczenie:** Wymiar typu wymagalności.

| Kolumna | Typ | Opis |
|---|---|---|
| `d_req_type_id` | SERIAL PK | Klucz wymiaru |
| `requirement_type_name` | TEXT | Typ: `wymagane` / `opcjonalne` |
| `created_at` | TIMESTAMP | Czas dodania rekordu — domyślnie `NOW()` |

---

### Tabele faktów dziennych

Tabele faktów dziennych są **partycjonowane po `d_date_id`** per miesiąc. Strategia ładowania: `delete+insert` per `d_date_id` — dane dla danego dnia są usuwane i wgrywane od nowa przy ponownym uruchomieniu.

#### **Nazwa:** gold.f_day_offers

**Przeznaczenie:** Główna tabela faktów — liczba ofert per dzień z podziałem na wymiary. Odpowiada na pytanie: ile ofert danego dnia szukało np. Senior Data Engineerów na B2B w trybie Remote?

| Kolumna | Typ | Opis |
|---|---|---|
| `d_date_id` | INT FK → `gold.d_date` | Wymiar czasu |
| `d_spec_id` | INT FK → `gold.d_specs` | Wymiar specjalizacji IT |
| `d_level_id` | INT FK → `gold.d_level` | Wymiar poziomu stanowiska |
| `d_mode_id` | INT FK → `gold.d_mode` | Wymiar trybu pracy |
| `d_contract_id` | INT FK → `gold.d_contract` | Wymiar typu umowy |
| `total_offers` | INT | Liczba ofert dla danej kombinacji wymiarów |

---

#### **Nazwa:** gold.f_day_offers_loc

**Przeznaczenie:** Liczba ofert per dzień z wymiarem lokalizacji. Zawiera tylko oferty z trybem pracy Hybrid lub Office (Remote i Mobile nie mają fizycznej lokalizacji).

| Kolumna | Typ | Opis |
|---|---|---|
| `d_date_id` | INT FK → `gold.d_date` | Wymiar czasu |
| `d_location_id` | INT FK → `gold.d_location` | Wymiar lokalizacji |
| `d_spec_id` | INT FK → `gold.d_specs` | Wymiar specjalizacji IT |
| `d_level_id` | INT FK → `gold.d_level` | Wymiar poziomu stanowiska |
| `d_mode_id` | INT FK → `gold.d_mode` | Wymiar trybu pracy (tylko Hybrid/Office) |
| `d_contract_id` | INT FK → `gold.d_contract` | Wymiar typu umowy |
| `total_offers` | INT | Liczba ofert dla danej kombinacji wymiarów |

---

#### **Nazwa:** gold.f_day_salaries

**Przeznaczenie:** Wynagrodzenia per dzień znormalizowane do wspólnej stawki miesięcznej PLN, gdzie minimalna i maksymalna stawka zostały określone na podstawie mediany.

| Kolumna | Typ | Opis |
|---|---|---|
| `d_date_id` | INT FK → `gold.d_date` | Wymiar czasu |
| `d_spec_id` | INT FK → `gold.d_specs` | Wymiar specjalizacji IT |
| `d_level_id` | INT FK → `gold.d_level` | Wymiar poziomu stanowiska |
| `d_mode_id` | INT FK → `gold.d_mode` | Wymiar trybu pracy |
| `d_contract_id` | INT FK → `gold.d_contract` | Wymiar typu umowy |
| `salary_min_monthly_avg` | NUMERIC | Średnie minimalne wynagrodzenie miesięczne |
| `salary_max_monthly_avg` | NUMERIC | Średnie maksymalne wynagrodzenie miesięczne |
| `offer_count` | INT | Liczba ofert z wynagrodzeniem dla danej kombinacji |

---

#### **Nazwa:** gold.f_day_offers_technology

**Przeznaczenie:** Ranking technologii per dzień — ile ofert wymaga lub opcjonalnie wskazuje daną technologię.

| Kolumna | Typ | Opis |
|---|---|---|
| `d_date_id` | INT FK → `gold.d_date` | Wymiar czasu |
| `d_technology_id` | INT FK → `gold.d_technology` | Wymiar technologii |
| `d_req_type_id` | INT FK → `gold.d_requirement_type` | Wymiar typu wymagalności |
| `d_spec_id` | INT FK → `gold.d_specs` | Wymiar specjalizacji IT |
| `total_offers` | INT | Liczba ofert dla danej technologii i wymagalności |

---

#### **Nazwa:** gold.f_day_offers_benefit

**Przeznaczenie:** Ranking benefitów per dzień — ile ofert oferuje dany benefit.

| Kolumna | Typ | Opis |
|---|---|---|
| `d_date_id` | INT FK → `gold.d_date` | Wymiar czasu |
| `d_benefit_id` | INT FK → `gold.d_benefit` | Wymiar benefitu |
| `total_offers` | INT | Liczba ofert oferujących dany benefit |

---

### Tabele agregacji miesięcznych

Agregacje miesięczne budowane z tabel faktów dziennych. Strategia ładowania: `delete+insert` per `(year, month)`.

#### **Nazwa:** gold.f_month_offers_agg

**Przeznaczenie:** Miesięczny agregat liczby ofert — suma `total_offers` z `f_day_offers` dla danego miesiąca.

| Kolumna | Typ | Opis |
|---|---|---|
| `year` | INT | Rok |
| `month` | INT | Miesiąc (1–12) |
| `d_spec_id` | INT FK | Wymiar specjalizacji |
| `d_level_id` | INT FK | Wymiar poziomu |
| `d_mode_id` | INT FK | Wymiar trybu pracy |
| `d_contract_id` | INT FK | Wymiar umowy |
| `total_offers` | INT | Suma ofert w miesiącu |

---

#### **Nazwa:** gold.f_month_offers_loc_agg

**Przeznaczenie:** Miesięczny agregat ofert z lokalizacją.

| Kolumna | Typ | Opis |
|---|---|---|
| `year` | INT | Rok |
| `month` | INT | Miesiąc |
| `d_location_id` | INT FK | Wymiar lokalizacji |
| `d_spec_id` | INT FK | Wymiar specjalizacji |
| `d_level_id` | INT FK | Wymiar poziomu |
| `d_mode_id` | INT FK | Wymiar trybu pracy |
| `d_contract_id` | INT FK | Wymiar umowy |
| `total_offers` | INT | Suma ofert w miesiącu |

---

#### **Nazwa:** gold.f_month_salaries_agg

**Przeznaczenie:** Miesięczny agregat wynagrodzeń, w którym minimalna i maksymalna średnia wartość zostały określone za pomocą mediany z dziennej tabeli faktów gold.f_day_salaries.

| Kolumna | Typ | Opis |
|---|---|---|
| `year` | INT | Rok |
| `month` | INT | Miesiąc |
| `d_spec_id` | INT FK | Wymiar specjalizacji |
| `d_level_id` | INT FK | Wymiar poziomu |
| `d_mode_id` | INT FK | Wymiar trybu pracy |
| `d_contract_id` | INT FK | Wymiar umowy |
| `salary_min_monthly_avg` | NUMERIC | Średnie minimalne wynagrodzenie miesięczne |
| `salary_max_monthly_avg` | NUMERIC | Średnie maksymalne wynagrodzenie miesięczne |
| `offer_count` | INT | Liczba ofert z wynagrodzeniem |

---

### Tabele agregacji rocznych

Agregacje reczne budowane z tabel faktów miesięcznych. Strategia ładowania: `delete+insert` per `year`.

#### **Nazwa:** gold.f_year_offers_agg

**Przeznaczenie:** Roczny agregat liczby ofert — suma `total_offers` z `f_month_offers_agg` dla danego roku.

| Kolumna | Typ | Opis |
|---|---|---|
| `year` | INT | Rok |
| `d_spec_id` | INT FK | Wymiar specjalizacji |
| `d_level_id` | INT FK | Wymiar poziomu |
| `d_mode_id` | INT FK | Wymiar trybu pracy |
| `d_contract_id` | INT FK | Wymiar umowy |
| `total_offers` | INT | Suma ofert w roku |

---

#### **Nazwa:** gold.f_year_offers_loc_agg

**Przeznaczenie:** Roczny agregat ofert z lokalizacją.

| Kolumna | Typ | Opis |
|---|---|---|
| `year` | INT | Rok |
| `d_location_id` | INT FK | Wymiar lokalizacji |
| `d_spec_id` | INT FK | Wymiar specjalizacji |
| `d_level_id` | INT FK | Wymiar poziomu |
| `d_mode_id` | INT FK | Wymiar trybu pracy |
| `d_contract_id` | INT FK | Wymiar umowy |
| `total_offers` | INT | Suma ofert w roku |

---

#### **Nazwa:** gold.f_year_salaries_agg

**Przeznaczenie:** Roczny agregat wynagrodzeń.

| Kolumna | Typ | Opis |
|---|---|---|
| `year` | INT | Rok |
| `d_spec_id` | INT FK | Wymiar specjalizacji |
| `d_level_id` | INT FK | Wymiar poziomu |
| `d_mode_id` | INT FK | Wymiar trybu pracy |
| `d_contract_id` | INT FK | Wymiar umowy |
| `salary_min_monthly_avg` | NUMERIC | Średnie minimalne wynagrodzenie miesięczne |
| `salary_max_monthly_avg` | NUMERIC | Średnie maksymalne wynagrodzenie miesięczne |
| `offer_count` | INT | Liczba ofert z wynagrodzeniem |

---

### Widoki diagnostyczne Gold

#### **Nazwa:** gold.v_f_day_offers_rejected

**Przeznaczenie:** Diagnostyczny widok pokazujący oferty które zostały pominięte podczas wgrywania do `gold.f_day_offers` — czyli oferty Silver dla których nie znaleziono dopasowania we wszystkich czterech wymaganych wymiarach (specs, level, mode, contract). Używany do diagnozowania braków w słownikach Gold. Nie wchodzi do raportu email.

**Zwraca:** Szczegóły ofert pominiętych ze wskazaniem których wymiarów brakuje.

---

## Schemat Maintenance

Schemat `maintenance` zawiera obiekty pomocnicze do zarządzania bazą danych i monitorowania pipeline'u.

---

### Tabele pipeline

#### **Nazwa:** maintenance.pipeline_run

**Przeznaczenie:** Rejestr każdego uruchomienia pipeline'u Airflow — jeden rekord per DAG Run. Tworzony na początku przez task `set_run_date`, aktualizowany na końcu przez `finalize_pipeline`.

| Kolumna | Typ | Opis |
|---|---|---|
| `id` | SERIAL PK | Klucz techniczny |
| `run_date` | DATE | Data uruchomienia pobrana z task `set_run_date` |
| `dag_run_id` | TEXT | ID runu z Airflow — np. `scheduled__2026-05-15T20:00:00+00:00` |
| `start_time` | TIMESTAMP | Czas startu pipeline'u |
| `end_time` | TIMESTAMP | Czas zakończenia — uzupełniany przez `finalize_pipeline` |
| `status` | TEXT | Status: `PENDING` / `SUCCESS` / `PARTIAL_SUCCESS` / `ERROR` |
| `created_at` | TIMESTAMP | Czas utworzenia rekordu |

---

#### **Nazwa:** maintenance.pipeline_run_step

**Przeznaczenie:** Szczegóły każdego kroku (tasku Airflow) w ramach pipeline runu. Jeden rekord per task per DAG Run. Zasilany przez callbacki audytowe — `on_task_start`, `on_task_success`, `on_task_failure`, `on_task_skipped`.

| Kolumna | Typ | Opis |
|---|---|---|
| `id` | SERIAL PK | Klucz techniczny |
| `pipeline_run_id` | INT FK → `maintenance.pipeline_run.id` | Powiązanie z runem |
| `step_name` | TEXT | Nazwa tasku Airflow — `task_id` z DAG |
| `start_time` | TIMESTAMP | Czas startu tasku |
| `end_time` | TIMESTAMP | Czas zakończenia tasku |
| `status` | TEXT | Status: `PENDING` / `SUCCESS` / `ERROR` / `SKIPPED` |
| `error_details` | TEXT | Pełny stack trace błędu — wypełniany tylko przy ERROR |
| `created_at` | TIMESTAMP | Czas utworzenia rekordu |

---

#### **Nazwa:** maintenance.notification_queue

**Przeznaczenie:** Tymczasowa kolejka powiadomień dla modułu raportowego. Wypełniana przez task `prepare_report`, odczytywana przez `send_report`. Na początku każdego runu wykonywany jest `TRUNCATE` — przechowuje tylko wpisy ostatniego uruchomienia.

| Kolumna | Typ | Opis |
|---|---|---|
| `pipeline_run_id` | INT | Powiązanie z pipeline runem |
| `type` | TEXT | Typ powiadomienia: `MAIN_INFO` / `WARNING` / `ADD_INFO` |
| `category` | TEXT | Kategoria: `PIPELINE` / `PORTAL` / `STORAGE` / `DATA_QUALITY` |
| `title` | TEXT | Krótki tytuł powiadomienia |
| `message` | TEXT | Szczegółowy opis |
| `attach` | BOOLEAN | Czy rekord bedzie w załączniku |
| `view_name` | TEXT | Nazwa widoku SQL dla rekordów z `attach=TRUE` |
| `view_schema` | TEXT | Schemat widoku SQL |
| `is_sent` | BOOLEAN | Czy rekord został wysłany emailem |
| `sent_at` | TIMESTAMP | Czas wysyłki |
| `created_at` | TIMESTAMP | Czas utworzenia rekordu |

---

#### **Nazwa:** maintenance.queue

**Przeznaczenie:** Kolejka zadań maintenance — VACUUM FULL i REINDEX INDEX dla tabel i indeksów wymagających konserwacji. Wypełniana przez procedurę `p_build_queue`, wykonywana przez task `cleanup_database` w Airflow.

| Kolumna | Typ | Opis |
|---|---|---|
| `id` | SERIAL PK | Klucz techniczny |
| `operation` | TEXT | Typ operacji: `VACUUM FULL` / `REINDEX INDEX` |
| `schema_name` | TEXT | Schemat docelowego obiektu |
| `object_name` | TEXT | Nazwa tabeli lub indeksu |
| `sql_command` | TEXT | Gotowa komenda SQL do wykonania |
| `created_at` | TIMESTAMP | Czas dodania do kolejki |

---

### Widoki monitoringu dysku

#### **Nazwa:** maintenance.v_bronze_obj_sizes

**Przeznaczenie:** Bieżące zużycie miejsca na dysku dla obiektów w schemacie `bronze`.

**Zwraca:** `(table_name, total_size, table_size, indexes_size)` — rozmiary w formacie czytelnym dla człowieka (np. `45 MB`).

---

#### **Nazwa:** maintenance.v_silver_obj_sizes

**Przeznaczenie:** Bieżące zużycie miejsca dla obiektów w schemacie `silver`.

**Zwraca:** `(table_name, total_size, table_size, indexes_size)`.

---

#### **Nazwa:** maintenance.v_gold_obj_sizes

**Przeznaczenie:** Bieżące zużycie miejsca dla obiektów w schemacie `gold`. Obsługuje tabele partycjonowane — sumuje rozmiary wszystkich partycji.

**Zwraca:** `(table_name, total_size, table_size, indexes_size)`.

---

#### **Nazwa:** maintenance.v_total_obj_sizes

**Przeznaczenie:** Łączne zużycie miejsca per schemat oraz suma całkowita. Używany w raporcie email w zakładce `disk_usage`.

**Zwraca:** `(schema, total_size, table_size, indexes_size)` — wiersze dla Bronze, Silver, Gold i Total.

---

### Procedury i funkcje

#### **Nazwa:** gold.load_d_date()

**Przeznaczenie:** Funkcja ładująca nowe daty do wymiaru `gold.d_date`. Wywoływana przez task `pre_gold_schema` w Airflow przed uruchomieniem modeli Gold.

---

#### **Nazwa:** maintenance.p_create_partitions_table_for_date(schema, table_name)

**Przeznaczenie:** Procedura tworząca partycje miesięczne dla tabel faktów dziennych Gold (`f_day_offers`, `f_day_offers_loc`). Wywoływana przez task `pre_gold_schema` przed każdym uruchomieniem Gold.

**Parametry:**
- `schema` — schemat tabeli partycjonowanej
- `table_name` — nazwa tabeli

---

#### **Nazwa:** maintenance.p_build_queue(p_min_free_percent, p_min_dead_percent, p_min_fragmentation, p_min_density)

**Przeznaczenie:** Procedura analizująca stan tabel i indeksów w schematach `bronze`, `silver`, `gold` i budująca kolejkę zadań maintenance w `maintenance.queue`. Używa rozszerzenia `pgstattuple` do analizy fragmentacji. Wywoływana przez task `cleanup_database` przed wykonaniem kolejki.

**Parametry z wartościami domyślnymi:**
- `p_min_free_percent` = 30.0 — minimalny % wolnego miejsca w tabeli przed VACUUM
- `p_min_dead_percent` = 10.0 — minimalny % martwych krotek przed VACUUM
- `p_min_fragmentation` = 30.0 — minimalna fragmentacja indeksu przed REINDEX
- `p_min_density` = 70.0 — minimalna gęstość indeksu przed REINDEX
