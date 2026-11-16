"""Generate the same synthetic order-line snapshot from a fixed seed."""
import csv
from datetime import date, timedelta
from pathlib import Path
from random import Random

DATA = Path(__file__).resolve().parent / "data"
AS_OF = date(2025, 12, 31)
START = date(2025, 1, 1)


def write(name, fields, rows):
    with (DATA / name).open("w", newline="", encoding="utf-8") as output:
        writer = csv.writer(output, lineterminator="\n")
        writer.writerow(fields)
        writer.writerows(rows)


def main():
    DATA.mkdir(exist_ok=True)
    rng = Random(32071)
    categories = ("Apparel", "Home", "Electronics")
    products = [(f"SKU{i:02}", categories[(i - 1) // 4]) for i in range(1, 13)]
    prices = {"Apparel": (1300, 3900), "Home": (900, 3400), "Electronics": (2300, 6800)}
    probabilities = {"Apparel": 0.17, "Home": 0.07, "Electronics": 0.09}
    lines = []
    for line_id in range(1, 9001):
        sku, category = products[rng.randrange(len(products))]
        channel = "Marketplace" if rng.random() < 0.60 else "Direct"
        delivered = START + timedelta(days=rng.randrange(365))
        amount = rng.randint(*prices[category])
        probability = probabilities[category] + (0.07 if channel == "Marketplace" and category == "Apparel" else 0)
        returned, reason = None, None
        if rng.random() < probability:
            event_date = delivered + timedelta(days=rng.randint(1, 37))
            if event_date <= AS_OF:
                returned = event_date
                reason = rng.choices(
                    ["Fit", "Damaged", "Changed mind"],
                    weights=[65, 15, 20] if category == "Apparel" else [5, 35, 60],
                )[0]
        lines.append((line_id, sku, channel, delivered, amount, returned, reason))
    write("products.csv", ("sku", "category"), products)
    write("order_lines.csv", ("line_id", "sku", "channel", "delivered_on", "amount_rub",
                             "returned_on", "reason"), lines)


if __name__ == "__main__":
    main()
