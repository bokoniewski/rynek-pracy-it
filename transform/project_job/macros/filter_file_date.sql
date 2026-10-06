-- Filtr dla silver.offers — bezpośrednio po offer_date
{% macro file_date_filter() %}
    offer_date = CAST('{{ var("FILE_DATE", "1899-12-30") }}' AS DATE)
{% endmacro %}


-- Filtr dla tabel szczegółowych Silver — przez offer_id
{% macro file_date_filter_by_offer_id() %}
    offer_id IN (
        SELECT id FROM silver.offers
        WHERE offer_date = CAST('{{ var("FILE_DATE", "1899-12-30") }}' AS DATE)
    )
{% endmacro %}