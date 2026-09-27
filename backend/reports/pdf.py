"""
Any report (reports/services.py builds them all in one shape) rendered as a
printable PDF: the SACCO's name, the period, the figures, and a footer
saying who produced it and when - what an auditor or a meeting needs on
paper.
"""

from datetime import date
from xml.sax.saxutils import escape

from django.utils.translation import gettext as _
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_RIGHT
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import KeepTogether, PageBreak, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

RED = colors.HexColor("#D62C2C")
ORANGE = colors.HexColor("#F28A1E")
GREY = colors.HexColor("#6B6B6B")
LINE = colors.HexColor("#E4E4E4")
BAND = colors.HexColor("#FBF4EE")

_styles = getSampleStyleSheet()
TITLE = ParagraphStyle("t", parent=_styles["Title"], fontSize=15, spaceAfter=2, textColor=colors.black)
SUBTITLE = ParagraphStyle("s", parent=_styles["BodyText"], fontSize=9.5, textColor=GREY, alignment=TA_CENTER)
SECTION = ParagraphStyle("sec", parent=_styles["Heading3"], fontSize=11, spaceBefore=10, spaceAfter=4,
                         textColor=RED)
CELL = ParagraphStyle("cell", parent=_styles["BodyText"], fontSize=8.5, leading=10.5)
CELL_RIGHT = ParagraphStyle("cellr", parent=CELL, alignment=TA_RIGHT)
HEAD = ParagraphStyle("head", parent=CELL, fontName="Helvetica-Bold", textColor=colors.white)
HEAD_RIGHT = ParagraphStyle("headr", parent=HEAD, alignment=TA_RIGHT)

NUMERIC = {"money", "number", "percent"}


def _cell(value, kind, *, bold=False, header=False):
    text = escape("" if value is None else str(value))
    if header:
        return Paragraph(text, HEAD_RIGHT if kind in NUMERIC else HEAD)
    style = CELL_RIGHT if kind in NUMERIC else CELL
    if bold:
        style = ParagraphStyle("b", parent=style, fontName="Helvetica-Bold")
    return Paragraph(text, style)


def _table(columns, rows, totals, width):
    kinds = [c.get("kind", "text") for c in columns]
    # Numbers need little room; names and descriptions get what is left.
    weights = [1.0 if k in NUMERIC else 2.0 for k in kinds]
    if kinds and kinds[0] not in NUMERIC:
        weights[0] = 2.4
    span = width / sum(weights)
    data = [[_cell(c["label"], c.get("kind", "text"), header=True) for c in columns]]
    for row in rows:
        data.append([_cell(v, kinds[i] if i < len(kinds) else "text") for i, v in enumerate(row)])
    if totals:
        data.append([_cell(v, kinds[i] if i < len(kinds) else "text", bold=True) for i, v in enumerate(totals)])
    table = Table(data, colWidths=[w * span for w in weights], repeatRows=1, hAlign="LEFT")
    style = [
        ("BACKGROUND", (0, 0), (-1, 0), RED),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("GRID", (0, 0), (-1, -1), 0.4, LINE),
        ("ROWBACKGROUNDS", (0, 1), (-1, -2 if totals else -1), [colors.white, BAND]),
    ]
    if totals:
        style += [("BACKGROUND", (0, -1), (-1, -1), BAND), ("LINEABOVE", (0, -1), (-1, -1), 0.8, ORANGE)]
    table.setStyle(TableStyle(style))
    return table


def render_report(report: dict, *, sacco_name: str, currency: str = "") -> bytes:
    """The report dict from reports/services.py, as an A4 PDF (landscape
    when it has many columns)."""
    widest = max((len(s["columns"]) for s in report.get("sections", [])), default=3)
    pagesize = landscape(A4) if widest > 6 else A4
    width = pagesize[0] - 36 * mm

    story = [
        Paragraph(escape(sacco_name.upper()), TITLE),
        Paragraph(escape(report["title"]), SUBTITLE),
        Paragraph(escape(f"{report['period']}{f' - {currency}' if currency else ''}"), SUBTITLE),
        Spacer(1, 6 * mm),
    ]

    summary = report.get("summary") or []
    if summary:
        cells = [[Paragraph(escape(i["label"]), ParagraphStyle("l", parent=CELL, textColor=GREY)),
                  _cell(i["value"], i.get("kind", "text"), bold=True)] for i in summary]
        summary_table = Table(cells, colWidths=[width * 0.62, width * 0.38], hAlign="LEFT")
        summary_table.setStyle(TableStyle([
            ("LINEBELOW", (0, 0), (-1, -2), 0.3, LINE),
            ("TOPPADDING", (0, 0), (-1, -1), 2),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
        ]))
        story += [summary_table, Spacer(1, 4 * mm)]

    for section in report.get("sections", []):
        block = [Paragraph(escape(section["title"]), SECTION)]
        if section["rows"]:
            block.append(_table(section["columns"], section["rows"], section.get("totals"), width))
        else:
            block.append(Paragraph(_("Nothing to show."), CELL))
        # Keep a short section with its heading; let long ones flow.
        story.append(KeepTogether(block) if len(section["rows"]) <= 12 else block[0])
        if len(section["rows"]) > 12:
            story.append(block[1])
        story.append(Spacer(1, 3 * mm))

    checks = report.get("checks") or []
    if checks:
        story.append(Paragraph(_("Checks"), SECTION))
        rows = [[c["label"], _("OK") if c["ok"] else _("DIFFERENCE"), c["detail"]] for c in checks]
        story.append(_table(
            [{"label": _("Check")}, {"label": _("Result")}, {"label": _("Detail")}], rows, None, width))

    generated = report.get("generated_at", "")[:19].replace("T", " ")
    footer_text = _("Generated %(when)s by %(who)s") % {"when": generated, "who": report.get("generated_by", "")}

    def footer(canvas, doc):
        canvas.saveState()
        canvas.setFont("Helvetica", 7.5)
        canvas.setFillColor(GREY)
        canvas.drawString(18 * mm, 12 * mm, footer_text)
        canvas.drawRightString(pagesize[0] - 18 * mm, 12 * mm, _("Page %d") % doc.page)
        canvas.setStrokeColor(LINE)
        canvas.line(18 * mm, 15 * mm, pagesize[0] - 18 * mm, 15 * mm)
        canvas.restoreState()

    from io import BytesIO

    out = BytesIO()
    SimpleDocTemplate(
        out, pagesize=pagesize, leftMargin=18 * mm, rightMargin=18 * mm, topMargin=16 * mm, bottomMargin=20 * mm,
        title=f"{sacco_name} - {report['title']}", author=sacco_name,
    ).build(story, onFirstPage=footer, onLaterPages=footer)
    return out.getvalue()


def filename_for(report: dict) -> str:
    key = report.get("key", "report")
    return f"{key}_{date.today().isoformat()}.pdf"


__all__ = ["render_report", "filename_for", "PageBreak"]
