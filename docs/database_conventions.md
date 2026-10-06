# Konwencje nazewnicze — Bazy danych

Dokument opisuje konwencje nazewnicze stosowane dla schematów, tabel, widoków, kolumn i innych obiektów w bazie danych projektu.

## Spis treści

1. [Zasady ogólne](#zasady-ogólne)
2. [Schematy](#schematy)
3. [Konwencje nazewnicze tabel](#konwencje-nazewnicze-tabel)
   - [Bronze](#bronze)
   - [Silver](#silver)
   - [Gold — wymiary](#gold--wymiary)
   - [Gold — fakty](#gold--fakty)
   - [Maintenance](#maintenance)
4. [Konwencje nazewnicze widoków](#konwencje-nazewnicze-widoków)
   - [Widoki data quality](#widoki-data-quality)
   - [Widoki pomocnicze Gold](#widoki-pomocnicze-gold)
   - [Widoki raportowe Maintenance](#widoki-raportowe-maintenance)
5. [Konwencje nazewnicze kolumn](#konwencje-nazewnicze-kolumn)
   - [Klucze główne](#klucze-główne)
   - [Klucze obce](#klucze-obce)
   - [Kolumny audytowe](#kolumny-audytowe)
6. [Konwencje nazewnicze indeksów](#konwencje-nazewnicze-indeksów)
7. [Procedury i funkcje](#procedury-i-funkcje)

---

## Zasady ogólne

- Wszystkie nazwy obiektów bazodanowych używają **snake_case** — małe litery z podkreślnikami jako separatorami.
- Język nazw: **angielski**.
- Nie używać słów zastrzeżonych SQL jako nazw obiektów.
- Nazwy muszą być opisowe i jednoznacznie wskazywać na przeznaczenie obiektu.

---

## Schematy

Projekt używa czterech schematów odpowiadających warstwom architektonicznym:

| Schema | Przeznaczenie |
|---|---|
| `bronze` | Surowe dane 1:1 ze źródła, bez transformacji |
| `silver` | Dane oczyszczone, znormalizowane, model relacyjny |
| `gold` | Model wymiarowy (Dim/Fact) gotowy pod BI |
| `maintenance` | Obiekty pomocnicze — audyt pipeline'u, kolejka zadań |

---

## Konwencje nazewnicze tabel

### Bronze

Tabele Bronze przechowują surowe dane pobrane bezpośrednio ze źródła. Nazwa tabeli składa się z prefiksu opisującego typ danych oraz nazwy portalu źródłowego.

**Wzorzec:** `<typ>_<portal>`

| Segment | Opis |
|---|---|
| `<typ>` | Typ danych: `raw_offers` dla surowych ofert pracy, `audit` dla danych audytowych |
| `<portal>` | Nazwa portalu źródłowego: `pracuj`, `nofluff`, `...` |

**Przykłady:**

| Tabela | Opis |
|---|---|
| `bronze.raw_offers_pracuj` | Surowe oferty z portalu pracuj.pl |
| `bronze.raw_offers_nofluff` | Surowe oferty z portalu nofluffjobs.com |
| `bronze.audit_file_log` | Log plików JSON załadowanych do Bronze |

---

### Silver

Tabele Silver przechowują dane oczyszczone i znormalizowane do wspólnego modelu relacyjnego. Wyróżnione są dwa typy tabel:

**Tabele danych** — wzorzec: `<encja>` lub `<encja>_<atrybut>`

Główna tabela ofert oraz tabele szczegółowe z relacją many-to-many do głównej tabeli.

| Tabela | Opis |
|---|---|
| `silver.offers` | Główna tabela ofert — jeden rekord per oferta |
| `silver.offer_salaries` | Wynagrodzenia per oferta |
| `silver.offer_technologies` | Technologie per oferta |
| `silver.offer_benefits` | Benefity per oferta |
| `silver.offer_locations` | Lokalizacje per oferta |

**Tabele słownikowe** — wzorzec: `def_<nazwa>`

Prefiks `def_` (od definition) oznacza tabele słownikowe zasilane ręcznie, zawierające stałe wartości referencyjne.

| Tabela | Opis |
|---|---|
| `silver.def_portal` | Słownik portali — lista aktywnych źródeł danych |
| `silver.def_requirement_type` | Słownik typów wymagalności — wymagane / opcjonalne |

---

### Gold — wymiary

Tabele wymiarów zaczynają się od prefiksu `d_` (od dimension). Każda tabela wymiaru opisuje jeden atrybut analityczny.

**Wzorzec:** `d_<nazwa_wymiaru>`

| Tabela | Opis |
|---|---|
| `gold.d_date` | Wymiar czasu — daty w formacie YYYYMMDD |
| `gold.d_specs` | Wymiar specjalizacji IT |
| `gold.d_level` | Wymiar poziomu doświadczenia (Junior/Mid/Senior/Expert) |
| `gold.d_mode` | Wymiar trybu pracy (Zdalnie/Hybrydowo/Biuro) |

---

### Gold — fakty

Tabele faktów zaczynają się od prefiksu `f_` (od fact), po którym następuje granularność czasowa i nazwa miary.

**Wzorzec:** `f_<granularność>_<nazwa>`

| Segment | Opis |
|---|---|
| `f_` | Prefiks faktu |
| `<granularność>` | Poziom czasowy: `day` (dzienne), `month` (miesięczne), `year` (roczne) |
| `<nazwa>` | Opisowa nazwa miary lub zestawienia |
| `_agg` | Sufiks dla tabel z agregacjami miesięcznymi i rocznymi |

**Przykłady:**

| Tabela | Granularność | Opis |
|---|---|---|
| `gold.f_day_offers` | Dzień | Liczba ofert per dzień z wymiarami |
| `gold.f_day_offers_loc` | Dzień | Oferty per dzień z lokalizacją |
| `gold.f_day_salaries` | Dzień | Wynagrodzenia per dzień |
| `gold.f_day_offers_technology` | Dzień | Technologie per dzień |
| `gold.f_day_offers_benefit` | Dzień | Benefity per dzień |
| `gold.f_month_offers_agg` | Miesiąc | Agregat miesięczny ofert |
| `gold.f_month_offers_loc_agg` | Miesiąc | Agregat miesięczny ofert z lokalizacją |
| `gold.f_month_salaries_agg` | Miesiąc | Agregat miesięczny wynagrodzeń |
| `gold.f_year_offers_agg` | Rok | Agregat roczny ofert |
| `gold.f_year_offers_loc_agg` | Rok | Agregat roczny ofert z lokalizacją |
| `gold.f_year_salaries_agg` | Rok | Agregat roczny wynagrodzeń |

---

### Maintenance

Tabele warstwy maintenance nie stosują prefiksów — nazwy opisują bezpośrednio przeznaczenie tabeli.

| Tabela | Opis |
|---|---|
| `maintenance.pipeline_run` | Rejestr uruchomień pipeline'u — jeden rekord per DAG Run |
| `maintenance.pipeline_run_step` | Szczegóły kroków — jeden rekord per task per DAG Run |
| `maintenance.notification_queue` | Kolejka powiadomień dla raportu email — truncowana przed każdym runem |
| `maintenance.queue` | Kolejka zadań maintenance (VACUUM FULL, REINDEX) |

---

## Konwencje nazewnicze widoków

### Widoki data quality

Widoki sprawdzające poprawność wgranych danych. Używane przez system raportowy do generowania ostrzeżeń.

**Wzorzec:** `v_test_<typ>_<encja>`

| Segment | Opis |
|---|---|
| `v_` | Prefiks widoku |
| `test_` | Oznacza widok data quality — sprawdza poprawność danych |
| `data_` | Sprawdza kompletność i poprawność kolumn |
| `double_` | Sprawdza duplikaty |
| `<encja>` | Nazwa sprawdzanej encji |

**Przykłady:**

| Widok | Schema | Opis |
|---|---|---|
| `bronze.v_test_data_raw_offers` | bronze | Sprawdzenie czy obligatoryjne kolumny ofert są wypełnione |
| `bronze.v_test_double_raw_offers` | bronze | Wykrywanie duplikatów w surowych ofertach |
| `silver.v_test_data_offer_benefits` | silver | Benefity niepasujące do wzorców z `gold.d_benefit` |
| `silver.v_test_data_offer_contracts` | silver | Typy umów niepasujące do `gold.d_contract` |
| `silver.v_test_data_offer_levels` | silver | Poziomy stanowisk niepasujące do `gold.d_level` |

---

### Widoki pomocnicze Gold

Widoki analityczne i diagnostyczne dla warstwy Gold.

**Wzorzec:** `v_<nazwa_tabeli_faktów>_<opis>`

| Widok | Opis |
|---|---|
| `gold.v_f_day_offers_rejected` | Oferty pominięte podczas wgrywania do `f_day_offers` |

---

### Widoki raportowe Maintenance

Widoki używane przez moduł raportowy do pobierania informacji o przestrzeni dyskowej.

**Wzorzec:** `v_<schema>_obj_sizes` lub `v_total_obj_sizes`

| Widok | Opis |
|---|---|
| `maintenance.v_bronze_obj_sizes` | Rozmiary obiektów w schemacie bronze |
| `maintenance.v_silver_obj_sizes` | Rozmiary obiektów w schemacie silver |

---

## Konwencje nazewnicze kolumn

### Klucze główne

Każda tabela posiada klucz główny typu `SERIAL` lub `INT`.

**Tabele Silver i Maintenance** — klucz główny o nazwie `id`:

```sql
id  SERIAL  PRIMARY KEY
```

**Tabele wymiarów Gold** — klucz główny zawiera prefix `d_` i nazwę tabeli:

**Wzorzec:** `d_<nazwa_tabeli>_id`

| Tabela | Klucz główny |
|---|---|
| `gold.d_date` | `d_date_id` |
| `gold.d_level` | `d_level_id` |
| `gold.d_mode` | `d_mode_id` |
| `gold.d_contract` | `d_contract_id` |

---

### Klucze obce

Kolumny kluczy obcych w tabelach faktów Gold używają tej samej nazwy co klucz główny tabeli wymiaru do której się odwołują.

**Wzorzec:** kolumna FK = nazwa klucza głównego powiązanej tabeli wymiaru

Przykład — tabela `gold.f_day_offers`:

```sql
d_date_id       INT  REFERENCES gold.d_date(d_date_id)
d_spec_id       INT  REFERENCES gold.d_specs(d_spec_id)
d_level_id      INT  REFERENCES gold.d_level(d_level_id)
d_mode_id       INT  REFERENCES gold.d_mode(d_mode_id)
d_contract_id   INT  REFERENCES gold.d_contract(d_contract_id)
```

Dzięki tej konwencji nazwa kolumny FK jest zawsze identyczna z nazwą kolumny PK w tabeli wymiaru — bez aliasów, bez niejednoznaczności.

---

### Kolumny audytowe

Kolumny techniczne obecne w większości tabel:

| Kolumna | Typ | Opis |
|---|---|---|
| `created_at` | `TIMESTAMP DEFAULT NOW()` | Czas utworzenia rekordu w bazie |
| `loaded_at` | `TIMESTAMP DEFAULT NOW()` | Czas załadowania rekordu (Bronze) |
| `source_file_id` | `INT` | Powiązanie z `bronze.audit_file_log` (Bronze) |
| `start_time` | `TIMESTAMP` | Czas startu (Maintenance) |
| `end_time` | `TIMESTAMP` | Czas zakończenia (Maintenance) |

---

## Konwencje nazewnicze indeksów

**Wzorzec:** `idx_<schema>_<tabela>_<kolumna>`

| Segment | Opis |
|---|---|
| `idx_` | Prefiks indeksu |
| `<schema>` | Schemat tabeli: `bronze`, `silver`, `gold`, `maintenance` |
| `<tabela>` | Skrócona nazwa tabeli |
| `<kolumna>` | Kolumna lub kolumny na których zbudowany jest indeks |

**Przykłady:**

```sql
idx_bronze_pracuj_offer_id          -- indeks na offer_id w bronze.raw_offers_pracuj
idx_silver_offer_levels_offer_id    -- indeks na offer_id w silver.offer_levels
idx_gold_d_benefit_name             -- unikalny indeks na benefit_name w gold.d_benefit
idx_pipeline_run_date               -- indeks na run_date w maintenance.pipeline_run
```

Indeksy GIN na kolumnach JSONB stosują ten sam wzorzec z opisem kolumny:

```sql
idx_d_specs_aliases     -- GIN na gold.d_specs.spec_aliases
```

---

## Procedury i funkcje

**Wzorzec:** `<czasownik>_<opis>` lub `p_<opis>` dla procedur

| Obiekt | Schema | Opis |
|---|---|---|
| `gold.load_d_date()` | gold | Funkcja ładująca nowe daty do wymiaru `d_date` |
| `maintenance.p_create_partitions_table_for_date` | maintenance | Procedura tworząca partycje dla tabel faktów dziennych |
