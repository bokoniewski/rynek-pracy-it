# airflow_prod/plugins/tasks/send_report_tasks.py
# Funkcja wysyłania raportu email przez SendGrid
# Wysyłana zawsze po zakończeniu pipeline'u (SUCCESS lub ERROR)
#
# Załączniki:
#   summary_{date}.pdf            ← podsumowanie pipeline (zawsze)
#   report_warnings_{date}.xlsx   ← zakładki z widokami WARNING (jeśli są dane)
#   report_details_{date}.xlsx    ← kroki pipeline + przestrzeń dyskowa (zawsze)
#   error_scrape_{portal}_{date}.txt ← błędy scraperów (jeśli były)
#   error_details_{date}.txt      ← błąd krytyczny (tylko przy ERROR)

import os
import glob
import base64

from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import (
    Mail, Attachment, FileContent, FileName,
    FileType, Disposition
)
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable
)
from reportlab.lib.enums import TA_CENTER
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

from db import get_db_connection
from config import PROJECT_DIR

REPORTS_DIR = os.path.join(PROJECT_DIR, "data", "reports")

# ── Rejestracja czcionki z polskimi znakami ──────────────────────────────────
try:
    pdfmetrics.registerFont(TTFont(
        'DejaVu',
        '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
    ))
    pdfmetrics.registerFont(TTFont(
        'DejaVu-Bold',
        '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
    ))
    pdfmetrics.registerFont(TTFont(
        'DejaVu-Mono',
        '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'
    ))
    FONT_NORMAL = 'DejaVu'
    FONT_BOLD   = 'DejaVu-Bold'
    FONT_MONO   = 'DejaVu-Mono'
    print("[send_report] Czcionka DejaVu załadowana pomyślnie.")
except Exception as e:
    print(f"[send_report] Brak DejaVu — używam Helvetica (brak polskich znaków): {e}")
    FONT_NORMAL = 'Helvetica'
    FONT_BOLD   = 'Helvetica-Bold'
    FONT_MONO   = 'Courier'


# ── Kolory PDF ───────────────────────────────────────────────────────────────

COLOR_DARK_BLUE  = colors.HexColor("#1F4E79")
COLOR_SUCCESS    = colors.HexColor("#E2EFDA")
COLOR_ERROR      = colors.HexColor("#FFE0E0")
COLOR_SKIPPED    = colors.HexColor("#EDEDED")
COLOR_HEADER_TXT = colors.white
COLOR_LIGHT_GRAY = colors.HexColor("#F5F5F5")
COLOR_BORDER     = colors.HexColor("#CCCCCC")


# ── Funkcje pomocnicze ───────────────────────────────────────────────────────

def _encode_attachment(file_path: str) -> Attachment:
    """Koduje plik do base64 i zwraca obiekt Attachment dla SendGrid."""
    with open(file_path, 'rb') as f:
        data = f.read()

    encoded  = base64.b64encode(data).decode()
    filename = os.path.basename(file_path)

    if filename.endswith('.xlsx'):
        mime_type = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    elif filename.endswith('.pdf'):
        mime_type = 'application/pdf'
    elif filename.endswith('.txt'):
        mime_type = 'text/plain'
    else:
        mime_type = 'application/octet-stream'

    return Attachment(
        FileContent(encoded),
        FileName(filename),
        FileType(mime_type),
        Disposition('attachment'),
    )


def _format_duration(seconds) -> str:
    """Formatuje sekundy do czytelnego formatu hh:mm:ss."""
    if not seconds:
        return "N/A"
    try:
        seconds = int(seconds)
        h = seconds // 3600
        m = (seconds % 3600) // 60
        s = seconds % 60
        return f"{h:02d}:{m:02d}:{s:02d}"
    except Exception:
        return "N/A"


def _get_json_file_names(run_date: str) -> list:
    """
    Pobiera nazwy plików JSON z dysku dla bieżącego runu.
    Szuka w data/raw/{YYYYMMDD}/ lub data/archive/YYYY/MM/{YYYYMMDD}/
    """
    date_compact = run_date.replace('-', '')
    pattern      = os.path.join(PROJECT_DIR, "data", "raw", date_compact, f"*_{date_compact}_*.json")
    json_files   = glob.glob(pattern)

    if not json_files:
        year  = run_date[:4]
        month = run_date[5:7]
        pattern_archive = os.path.join(
            PROJECT_DIR, "data", "archive", year, month, date_compact,
            f"*_{date_compact}_*.json"
        )
        json_files = glob.glob(pattern_archive)

    return [os.path.basename(f) for f in json_files]


# ── Style PDF ────────────────────────────────────────────────────────────────

def _get_styles() -> dict:
    """Zwraca słownik stylów PDF z obsługą polskich znaków."""
    return {
        "title": ParagraphStyle(
            "title",
            fontSize=18, fontName=FONT_BOLD,
            textColor=COLOR_DARK_BLUE, alignment=TA_CENTER,
            spaceAfter=6,
        ),
        "subtitle": ParagraphStyle(
            "subtitle",
            fontSize=11, fontName=FONT_NORMAL,
            textColor=colors.gray, alignment=TA_CENTER,
            spaceAfter=20,
        ),
        "section": ParagraphStyle(
            "section",
            fontSize=12, fontName=FONT_BOLD,
            textColor=COLOR_DARK_BLUE,
            spaceBefore=16, spaceAfter=6,
        ),
        "normal": ParagraphStyle(
            "normal",
            fontSize=9, fontName=FONT_NORMAL,
            textColor=colors.black,
            spaceAfter=3,
        ),
        "error_box": ParagraphStyle(
            "error_box",
            fontSize=7, fontName=FONT_MONO,
            textColor=colors.HexColor("#8B0000"),
            backColor=colors.HexColor("#FFF0F0"),
            borderPadding=8, spaceAfter=6,
        ),
        "footer": ParagraphStyle(
            "footer",
            fontSize=8, fontName=FONT_NORMAL,
            textColor=colors.gray, alignment=TA_CENTER,
            spaceBefore=20,
        ),
    }


def _table_style_base() -> TableStyle:
    """Bazowy styl tabeli PDF."""
    return TableStyle([
        ("BACKGROUND",    (0, 0), (-1, 0),  COLOR_DARK_BLUE),
        ("TEXTCOLOR",     (0, 0), (-1, 0),  COLOR_HEADER_TXT),
        ("FONTNAME",      (0, 0), (-1, 0),  FONT_BOLD),
        ("FONTSIZE",      (0, 0), (-1, 0),  9),
        ("ALIGN",         (0, 0), (-1, 0),  "CENTER"),
        ("FONTNAME",      (0, 1), (-1, -1), FONT_NORMAL),
        ("FONTSIZE",      (0, 1), (-1, -1), 8),
        ("ROWBACKGROUNDS",(0, 1), (-1, -1), [colors.white, COLOR_LIGHT_GRAY]),
        ("GRID",          (0, 0), (-1, -1), 0.5, COLOR_BORDER),
        ("VALIGN",        (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING",    (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("LEFTPADDING",   (0, 0), (-1, -1), 6),
        ("RIGHTPADDING",  (0, 0), (-1, -1), 6),
    ])


def _summary_table_style() -> TableStyle:
    """Styl tabeli podsumowania (bez nagłówka)."""
    return TableStyle([
        ("FONTNAME",      (0, 0), (0, -1), FONT_BOLD),
        ("FONTNAME",      (1, 0), (1, -1), FONT_NORMAL),
        ("FONTSIZE",      (0, 0), (-1, -1), 9),
        ("ROWBACKGROUNDS",(0, 0), (-1, -1), [colors.white, COLOR_LIGHT_GRAY]),
        ("GRID",          (0, 0), (-1, -1), 0.5, COLOR_BORDER),
        ("TOPPADDING",    (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("LEFTPADDING",   (0, 0), (-1, -1), 8),
    ])


# ── Generowanie PDF SUCCESS ──────────────────────────────────────────────────

def _generate_success_pdf(run_date: str, pipeline_run_id: int,
                           failed_scrapers: list, conn) -> str:
    """
    Generuje summary_{date}.pdf dla scenariusza SUCCESS.
    Zawiera: podsumowanie wykonania, wgrane dane per portal, przestrzeń dyskową.
    """
    file_path = os.path.join(REPORTS_DIR, f"summary_{run_date}.pdf")
    styles    = _get_styles()
    elements  = []
    page_w    = A4[0] - 4 * cm

    # ── Nagłówek ─────────────────────────────────────────────────────────────
    elements.append(Paragraph("Pipeline praca IT", styles["title"]))
    elements.append(Paragraph(f"Raport dzienny — {run_date} — SUCCESS", styles["subtitle"]))
    elements.append(HRFlowable(width="100%", thickness=1.5, color=COLOR_DARK_BLUE))
    elements.append(Spacer(1, 0.3 * cm))

    # ── Podsumowanie wykonania ────────────────────────────────────────────────
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT
                TO_CHAR(start_time AT TIME ZONE 'Europe/Warsaw', 'YYYY-MM-DD HH24:MI:SS'),
                TO_CHAR(end_time   AT TIME ZONE 'Europe/Warsaw', 'YYYY-MM-DD HH24:MI:SS'),
                EXTRACT(EPOCH FROM (end_time - start_time))::INT
            FROM maintenance.pipeline_run
            WHERE id = %s;
            """,
            (pipeline_run_id,)
        )
        run_data = cur.fetchone()

    start_time = run_data[0] if run_data and run_data[0] else "N/A"
    end_time   = run_data[1] if run_data and run_data[1] else "N/A"
    duration   = _format_duration(run_data[2]) if run_data and run_data[2] else "N/A"

    elements.append(Paragraph("PODSUMOWANIE WYKONANIA", styles["section"]))

    summary_data = [
        ["Data",              run_date],
        ["Czas startu",       start_time],
        ["Czas zakończenia",  end_time],
        ["Całkowity czas",    duration],
        ["Status",            "SUCCESS"],
    ]
    st = _summary_table_style()
    st.add("BACKGROUND", (1, 4), (1, 4), COLOR_SUCCESS)
    summary_table = Table(summary_data, colWidths=[5 * cm, page_w - 5 * cm])
    summary_table.setStyle(st)
    elements.append(summary_table)
    elements.append(Spacer(1, 0.3 * cm))

    # ── Wgrane dane per portal ────────────────────────────────────────────────
    file_names  = _get_json_file_names(run_date)
    portal_data = []

    if file_names:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    portal,
                    records_inserted AS inserted,
                    records_skipped  AS skipped,
                    records_errors   AS errors
                FROM bronze.audit_file_log
                WHERE file_name = ANY(%s)
                  AND status IN ('SUCCESS', 'SUCCESS_EMPTY')
                ORDER BY portal;
                """,
                (file_names,)
            )
            portal_data = cur.fetchall()

    elements.append(Paragraph("WGRANE DANE", styles["section"]))

    if portal_data:
        portal_table_data = [["Portal", "Wgrane", "Pominięte", "Błędy"]]
        total_ins = total_skp = total_err = 0
        for portal, ins, skp, err in portal_data:
            ins = ins or 0
            skp = skp or 0
            err = err or 0
            portal_table_data.append([portal, str(ins), str(skp), str(err)])
            total_ins += ins
            total_skp += skp
            total_err += err
        portal_table_data.append(["SUMA", str(total_ins), str(total_skp), str(total_err)])

        col_w = page_w / 4
        portal_table = Table(
            portal_table_data,
            colWidths=[col_w * 2.5, col_w * 0.7, col_w * 0.7, col_w * 0.6]
        )
        style = _table_style_base()
        style.add("FONTNAME",   (0, -1), (-1, -1), FONT_BOLD)
        style.add("BACKGROUND", (0, -1), (-1, -1), COLOR_LIGHT_GRAY)
        portal_table.setStyle(style)
        elements.append(portal_table)
    else:
        elements.append(Paragraph("Brak danych o wgranych rekordach.", styles["normal"]))

    elements.append(Spacer(1, 0.3 * cm))

    # Ostrzeżenia o scraperach jeśli były
    if failed_scrapers:
        elements.append(Paragraph("PROBLEMY PODCZAS SCRAPOWANIA", styles["section"]))
        for scraper in failed_scrapers:
            portal = scraper.replace("scrape_", "")
            elements.append(Paragraph(
                f"- {scraper} — portal {portal} nie wgral danych (szczegoly w zalaczniku txt)",
                styles["normal"]
            ))
        elements.append(Spacer(1, 0.3 * cm))

    # ── Przestrzeń dyskowa ────────────────────────────────────────────────────
    elements.append(Paragraph("PRZESTRZEŃ DYSKOWA", styles["section"]))

    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT schema, total_size, table_size, indexes_size
            FROM maintenance.v_total_obj_sizes;
            """
        )
        disk_data = cur.fetchall()

    if disk_data:
        disk_table_data = [["Schema", "Total", "Tabele", "Indeksy"]]
        for row in disk_data:
            disk_table_data.append(list(row))

        col_w = page_w / 4
        disk_table = Table(disk_table_data, colWidths=[col_w, col_w, col_w, col_w])
        disk_table.setStyle(_table_style_base())
        elements.append(disk_table)
    else:
        elements.append(Paragraph("Brak danych o przestrzeni dyskowej.", styles["normal"]))

    # ── Stopka ────────────────────────────────────────────────────────────────
    elements.append(Spacer(1, 0.5 * cm))
    elements.append(HRFlowable(width="100%", thickness=0.5, color=COLOR_BORDER))
    elements.append(Paragraph(
        "Raport wygenerowany automatycznie przez Apache Airflow",
        styles["footer"]
    ))

    doc = SimpleDocTemplate(
        file_path, pagesize=A4,
        leftMargin=2*cm, rightMargin=2*cm,
        topMargin=2*cm, bottomMargin=2*cm
    )
    doc.build(elements)
    print(f"[send_report] Zapisano PDF SUCCESS: {file_path}")
    return file_path


# ── Generowanie PDF ERROR ────────────────────────────────────────────────────

def _generate_error_pdf(run_date: str, pipeline_run_id: int, conn) -> str:
    """
    Generuje summary_{date}.pdf dla scenariusza ERROR.
    Zawiera: podsumowanie wykonania, wykonane kroki, informacje o błędzie.
    """
    file_path = os.path.join(REPORTS_DIR, f"summary_{run_date}.pdf")
    styles    = _get_styles()
    elements  = []
    page_w    = A4[0] - 4 * cm

    # ── Nagłówek ─────────────────────────────────────────────────────────────
    elements.append(Paragraph("Pipeline praca IT", styles["title"]))
    elements.append(Paragraph(f"Raport dzienny — {run_date} — ERROR", styles["subtitle"]))
    elements.append(HRFlowable(width="100%", thickness=1.5, color=colors.HexColor("#C00000")))
    elements.append(Spacer(1, 0.3 * cm))

    # ── Podsumowanie wykonania ────────────────────────────────────────────────
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT
                TO_CHAR(start_time AT TIME ZONE 'Europe/Warsaw', 'YYYY-MM-DD HH24:MI:SS'),
                TO_CHAR(end_time   AT TIME ZONE 'Europe/Warsaw', 'YYYY-MM-DD HH24:MI:SS'),
                EXTRACT(EPOCH FROM (end_time - start_time))::INT
            FROM maintenance.pipeline_run
            WHERE id = %s;
            """,
            (pipeline_run_id,)
        )
        run_data = cur.fetchone()

    start_time = run_data[0] if run_data and run_data[0] else "N/A"
    end_time   = run_data[1] if run_data and run_data[1] else "N/A"
    duration   = _format_duration(run_data[2]) if run_data and run_data[2] else "N/A"

    elements.append(Paragraph("PODSUMOWANIE WYKONANIA", styles["section"]))

    summary_data = [
        ["Data",             run_date],
        ["Czas startu",      start_time],
        ["Czas zakończenia", end_time],
        ["Całkowity czas",   duration],
        ["Status",           "ERROR"],
    ]
    st = _summary_table_style()
    st.add("BACKGROUND", (1, 4), (1, 4), COLOR_ERROR)
    summary_table = Table(summary_data, colWidths=[5 * cm, page_w - 5 * cm])
    summary_table.setStyle(st)
    elements.append(summary_table)
    elements.append(Spacer(1, 0.3 * cm))

    # ── Wykonane kroki ────────────────────────────────────────────────────────
    elements.append(Paragraph("WYKONANE KROKI", styles["section"]))

    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT
                step_name,
                TO_CHAR(start_time AT TIME ZONE 'Europe/Warsaw', 'YYYY-MM-DD HH24:MI:SS'),
                TO_CHAR(end_time   AT TIME ZONE 'Europe/Warsaw', 'YYYY-MM-DD HH24:MI:SS'),
                EXTRACT(EPOCH FROM (end_time - start_time))::INT,
                status,
                error_details
            FROM maintenance.pipeline_run_step
            WHERE pipeline_run_id = %s
            ORDER BY start_time;
            """,
            (pipeline_run_id,)
        )
        steps = cur.fetchall()

    status_icons = {
        "SUCCESS": "[OK]",
        "ERROR":   "[ERR]",
        "SKIPPED": "[SKIP]",
        "PENDING": "[PEND]",
    }

    steps_table_data = [["Krok", "Start", "Koniec", "Czas", "Status"]]
    first_error = None

    for row in steps:
        if not row or len(row) < 5:
            continue
        step_name     = row[0]
        start         = row[1]
        end           = row[2]
        dur           = row[3]
        status        = row[4]
        error_details = row[5] if len(row) > 5 else None
        icon = status_icons.get(status, "?")
        steps_table_data.append([
            step_name,
            start or "N/A",
            end   or "N/A",
            _format_duration(dur),
            f"{icon} {status}",
        ])
        if status == "ERROR" and not first_error:
            first_error = (step_name, error_details)

    col_w = page_w / 5
    steps_table = Table(
        steps_table_data,
        colWidths=[col_w * 1.8, col_w * 1.2, col_w * 1.2, col_w * 0.6, col_w * 0.9]
    )
    style = _table_style_base()
    for row_idx, row in enumerate(steps_table_data[1:], 1):
        status_val = row[4] if row[4] else ""
        if "ERR"  in status_val:
            style.add("BACKGROUND", (0, row_idx), (-1, row_idx), COLOR_ERROR)
        elif "SKIP" in status_val:
            style.add("BACKGROUND", (0, row_idx), (-1, row_idx), COLOR_SKIPPED)
        elif "OK"  in status_val:
            style.add("BACKGROUND", (0, row_idx), (-1, row_idx), COLOR_SUCCESS)
    steps_table.setStyle(style)
    elements.append(steps_table)
    elements.append(Spacer(1, 0.3 * cm))

    # ── Informacja o błędzie ──────────────────────────────────────────────────
    if first_error:
        step_name, error_details = first_error
        elements.append(Paragraph("BLAD", styles["section"]))
        elements.append(Paragraph(f"Krok: {step_name}", styles["normal"]))
        elements.append(Spacer(1, 0.2 * cm))
        short_error = (error_details or "Brak szczegolów")[:800]
        elements.append(Paragraph(
            short_error.replace("\n", "<br/>").replace("<", "&lt;").replace(">", "&gt;"),
            styles["error_box"]
        ))
        elements.append(Paragraph(
            "Pelny opis bledu dostepny w zalaczniku error_details.txt",
            styles["normal"]
        ))

    # ── Stopka ────────────────────────────────────────────────────────────────
    elements.append(Spacer(1, 0.5 * cm))
    elements.append(HRFlowable(width="100%", thickness=0.5, color=COLOR_BORDER))
    elements.append(Paragraph(
        "Raport wygenerowany automatycznie przez Apache Airflow",
        styles["footer"]
    ))

    doc = SimpleDocTemplate(
        file_path, pagesize=A4,
        leftMargin=2*cm, rightMargin=2*cm,
        topMargin=2*cm, bottomMargin=2*cm
    )
    doc.build(elements)
    print(f"[send_report] Zapisano PDF ERROR: {file_path}")
    return file_path


# ── Główna funkcja t_send_report ─────────────────────────────────────────────

def send_report(**context):
    """
    Task wysyłania raportu email przez SendGrid.
    Uruchamiany zawsze po t_prepare_report (trigger_rule=ALL_DONE).
    Treść emaila: tylko jedna linia informacyjna.
    Całe podsumowanie w PDF jako załącznik.
    """
    run_date            = context['ti'].xcom_pull(task_ids='set_run_date')
    pipeline_run_id     = context['ti'].xcom_pull(task_ids='set_run_date', key='pipeline_run_id')
    pipeline_status     = context['ti'].xcom_pull(task_ids='prepare_report', key='pipeline_status')
    warnings_file       = context['ti'].xcom_pull(task_ids='prepare_report', key='warnings_file')
    details_file        = context['ti'].xcom_pull(task_ids='prepare_report', key='details_file')
    scraper_error_files = context['ti'].xcom_pull(task_ids='prepare_report', key='scraper_error_files') or []
    critical_error_file = context['ti'].xcom_pull(task_ids='prepare_report', key='critical_error_file')
    failed_scrapers     = context['ti'].xcom_pull(task_ids='prepare_report', key='failed_scrapers') or []

    # Konfiguracja SendGrid
    sendgrid_key = os.environ.get("SENDGRID_API_KEY")
    sender_email = os.environ.get("SENDER_EMAIL")
    report_email = os.environ.get("REPORT_EMAIL")

    if not sendgrid_key:
        raise Exception("[send_report] Brak SENDGRID_API_KEY w zmiennych środowiskowych!")
    if not sender_email:
        raise Exception("[send_report] Brak SENDER_EMAIL w zmiennych środowiskowych!")
    if not report_email:
        raise Exception("[send_report] Brak REPORT_EMAIL w zmiennych środowiskowych!")

    conn = get_db_connection()
    try:
        if pipeline_status in ("SUCCESS", "PARTIAL_SUCCESS"):
            summary_pdf = _generate_success_pdf(run_date, pipeline_run_id, failed_scrapers, conn)
        else:
            summary_pdf = _generate_error_pdf(run_date, pipeline_run_id, conn)
    finally:
        conn.close()

    # Subject emaila
    if pipeline_status == "SUCCESS":
        subject = f"Pipeline praca IT [{run_date}] - SUCCESS"
    elif pipeline_status == "PARTIAL_SUCCESS":
        subject = f"Pipeline praca IT [{run_date}] - PARTIAL SUCCESS"
    else:
        subject = f"Pipeline praca IT [{run_date}] - ERROR"

    # Treść emaila — tylko jedna linia informacyjna
    body = "=" * 55 + "\n  Raport wygenerowany automatycznie przez Airflow\n" + "=" * 55

    # Buduj email
    message = Mail(
        from_email=sender_email,
        to_emails=report_email,
        subject=subject,
        plain_text_content=body,
    )

    # Dodaj załączniki — tylko istniejące pliki
    attachments_added = []

    # 1. PDF z podsumowaniem (zawsze)
    if summary_pdf and os.path.exists(summary_pdf):
        message.attachment = _encode_attachment(summary_pdf)
        attachments_added.append(os.path.basename(summary_pdf))

    # 2. Excel ze szczegółami (zawsze)
    if details_file and os.path.exists(details_file):
        message.attachment = _encode_attachment(details_file)
        attachments_added.append(os.path.basename(details_file))

    # 3. Excel z warningami (jeśli są dane)
    if warnings_file and os.path.exists(warnings_file):
        message.attachment = _encode_attachment(warnings_file)
        attachments_added.append(os.path.basename(warnings_file))

    # 4. Pliki txt z błędami scraperów (jeśli były)
    for error_file in scraper_error_files:
        if error_file and os.path.exists(error_file):
            message.attachment = _encode_attachment(error_file)
            attachments_added.append(os.path.basename(error_file))

    # 4b. Plik txt z błędami dbt test Silver (jeśli był błąd)
    dbt_test_error_file = context['ti'].xcom_pull(task_ids='prepare_report', key='dbt_test_error_file')
    if dbt_test_error_file and os.path.exists(dbt_test_error_file):
        message.attachment = _encode_attachment(dbt_test_error_file)
        attachments_added.append(os.path.basename(dbt_test_error_file))

    # 5. Plik txt z błędem krytycznym (tylko przy ERROR)
    if critical_error_file and os.path.exists(critical_error_file):
        message.attachment = _encode_attachment(critical_error_file)
        attachments_added.append(os.path.basename(critical_error_file))

    print(f"[send_report] Wysyłam email: {subject}")
    print(f"[send_report] Załączniki: {attachments_added}")

    # Wyślij email
    sg       = SendGridAPIClient(sendgrid_key)
    response = sg.send(message)

    print(f"[send_report] Status SendGrid: {response.status_code}")

    if response.status_code not in [200, 202]:
        raise Exception(f"[send_report] Błąd wysyłania emaila: {response.status_code} {response.body}")

    # Zaktualizuj notification_queue — is_sent = true
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE maintenance.notification_queue
                SET is_sent = true,
                    sent_at = NOW()
                WHERE pipeline_run_id = %s;
                """,
                (pipeline_run_id,)
            )
            conn.commit()
        print("[send_report] Zaktualizowano notification_queue — is_sent = true")
    finally:
        conn.close()

    print("[send_report] Email wysłany pomyślnie!")