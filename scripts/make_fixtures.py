#!/usr/bin/env python3
"""Génère les fixtures de test synthétiques (mise en page des exports GOLD, chiffres inventés).

Usage : python3 scripts/make_fixtures.py
Dépendance : openpyxl
"""
import random
from pathlib import Path

from openpyxl import Workbook

OUT = Path(__file__).resolve().parent.parent / "Tests" / "AnalytikCoreTests" / "Fixtures"


def r2(x):
    return round(x, 2)


def write_metadata(ws, pairs, last_col="Q"):
    """Bloc de métadonnées lignes 2..(1+len) : A = libellé, C = valeur (cellules fusionnées comme GOLD)."""
    row = 2
    for label, value, extra in pairs:
        ws.cell(row=row, column=1, value=label)
        ws.merge_cells(f"A{row}:B{row}")
        ws.cell(row=row, column=3, value=value)
        if extra is None:
            ws.merge_cells(f"C{row}:{last_col}{row}")
        else:
            ws.merge_cells(f"C{row}:D{row}")
            ws.cell(row=row, column=5, value=extra)
            ws.merge_cells(f"E{row}:{last_col}{row}")
        row += 1
    return row


def subchannel_fixture():
    """Même structure que l'export fourni : Sub-Channel × (NBL, y/y, LY, Mix), 13 semaines + 2 trimestres."""
    rng = random.Random(394)
    wb = Workbook()
    ws = wb.active
    ws.title = "Sub-Channel"
    write_metadata(ws, [
        ("Product", "iPhone", None),
        ("PresetKPI", "CY/YoY/Mix, COB, Excl APU Abandonment, Excl Refused Delivery", None),
        ("Measures", "Net Billings", None),
        ("Channel", "Retail", None),
        ("Store ID - Name", "R000 - Exemple", " "),
        ("Country/Region", "France", " "),
        ("Type", " ", "REFURB"),
    ])

    members = ["RP - Retail POS", "RW - RETAIL WEB", "RB - RETAIL BUSINESS", "RK - RETAIL KIOSK"]
    weeks = 13
    # NBL par membre et par semaine (le kiosque reste à 0/1 pour produire des '-')
    nbl = {
        members[0]: [rng.randint(180, 300) for _ in range(weeks)],
        members[1]: [rng.randint(70, 140) for _ in range(weeks)],
        members[2]: [rng.randint(3, 40) for _ in range(weeks)],
        members[3]: [0, 1, 0, 0, 2, 1, 0, 1, 1, 0, 0, 0, 0],
    }
    ly = {
        members[0]: [rng.randint(150, 260) for _ in range(weeks)],
        members[1]: [rng.randint(30, 80) for _ in range(weeks)],
        members[2]: [rng.randint(2, 30) for _ in range(weeks)],
        members[3]: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    }
    total_nbl = [sum(nbl[m][w] for m in members) for w in range(weeks)]
    total_ly = [sum(ly[m][w] for m in members) for w in range(weeks)]
    q3_nbl = {m: sum(nbl[m]) for m in members}
    q3_ly = {m: sum(ly[m]) for m in members}
    q2_nbl = {members[0]: 2900, members[1]: 1300, members[2]: 60, members[3]: 2}
    q2_ly = {members[0]: 2000, members[1]: 700, members[2]: 90, members[3]: 4}

    header = ["Sub-Channel", " ", "FY26Q3_W1"] + [f"W{i}" for i in range(2, weeks + 1)] + ["26'Q2", "26'Q3"]
    for col, value in enumerate(header, start=1):
        ws.cell(row=10, column=col, value=value)

    def yoy(cur, prev):
        return "-" if prev == 0 else r2(cur / prev - 1)

    def mix(part, whole):
        return "-" if whole == 0 or part == 0 else r2(part / whole)

    row = 11

    def emit(member, metric, values):
        nonlocal row
        ws.cell(row=row, column=1, value=member)
        ws.cell(row=row, column=2, value=metric)
        for i, v in enumerate(values):
            ws.cell(row=row, column=3 + i, value=v)
        row += 1

    tq2_nbl = sum(q2_nbl.values())
    tq2_ly = sum(q2_ly.values())
    tq3_nbl = sum(q3_nbl.values())
    tq3_ly = sum(q3_ly.values())
    emit("TOTAL", "NBL", total_nbl + [tq2_nbl, tq3_nbl])
    emit(" ", "y/y", [yoy(c, p) for c, p in zip(total_nbl, total_ly)] + [yoy(tq2_nbl, tq2_ly), yoy(tq3_nbl, tq3_ly)])
    emit(" ", "LY", total_ly + [tq2_ly, tq3_ly])
    for m in members:
        emit(m, "NBL", nbl[m] + [q2_nbl[m], q3_nbl[m]])
        emit(" ", "y/y", [yoy(c, p) for c, p in zip(nbl[m], ly[m])] + [yoy(q2_nbl[m], q2_ly[m]), yoy(q3_nbl[m], q3_ly[m])])
        emit(" ", "Mix", [mix(nbl[m][w], total_nbl[w]) for w in range(weeks)] + [mix(q2_nbl[m], tq2_nbl), mix(q3_nbl[m], tq3_nbl)])
    for col in range(1, len(header) + 1):
        ws.cell(row=row, column=col, value=" ")
    wb.save(OUT / "gold-subchannel.xlsx")
    return {"total_nbl": total_nbl, "tq3_nbl": tq3_nbl, "tq2_nbl": tq2_nbl, "nbl": nbl, "ly": ly, "total_ly": total_ly}


def products_fixture():
    """Dimension « Product » en lignes, sans membre TOTAL, deux feuilles (la première n'est pas un rapport)."""
    wb = Workbook()
    notes = wb.active
    notes.title = "Notes"
    notes["A1"] = "Ce classeur contient un onglet de notes sans données."
    notes["A2"] = "Rien à lire ici."

    ws = wb.create_sheet("Product")
    write_metadata(ws, [
        ("Product", "All", None),
        ("Measures", "Net Billings", None),
        ("Channel", "Retail", None),
        ("Store ID - Name", "R000 - Exemple", None),
        ("Country/Region", "France", None),
    ], last_col="G")
    header = ["Product", " ", "FY26Q4_W1", "W2", "W3", "W4", "26'Q4"]
    for col, value in enumerate(header, start=1):
        ws.cell(row=8, column=col, value=value)
    data = {
        "iPhone": ([400, 380, 410, 390], [300, 310, 305, 320]),
        "Mac": ([120, 130, 110, 140], [100, 90, 95, 120]),
        "iPad": ([90, 85, 95, 100], [80, 70, 90, 60]),
    }
    row = 9
    for product, (cur, prev) in data.items():
        ws.cell(row=row, column=1, value=product)
        ws.cell(row=row, column=2, value="NBL")
        for i, v in enumerate(cur + [sum(cur)]):
            ws.cell(row=row, column=3 + i, value=v)
        row += 1
        ws.cell(row=row, column=1, value=" ")
        ws.cell(row=row, column=2, value="y/y")
        for i, (c, p) in enumerate(zip(cur + [sum(cur)], prev + [sum(prev)])):
            ws.cell(row=row, column=3 + i, value=r2(c / p - 1))
        row += 1
        ws.cell(row=row, column=1, value=" ")
        ws.cell(row=row, column=2, value="LY")
        for i, v in enumerate(prev + [sum(prev)]):
            ws.cell(row=row, column=3 + i, value=v)
        row += 1
    wb.save(OUT / "gold-products.xlsx")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    info = subchannel_fixture()
    products_fixture()
    print("TOTAL NBL semaines :", info["total_nbl"])
    print("TOTAL NBL Q3 :", info["tq3_nbl"], "| Q2 :", info["tq2_nbl"])
    print("TOTAL LY semaines :", info["total_ly"])
    for m, v in info["nbl"].items():
        print(m, "NBL:", v, "LY:", info["ly"][m])
    print("Fixtures écrites dans", OUT)
