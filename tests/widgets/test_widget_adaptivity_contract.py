"""Desktop widgets adapt to the cell they are resized to instead of spilling out."""

from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


class WidgetAdaptivityContract(unittest.TestCase):
    def test_metric_card_adapts_to_its_cell(self):
        card = read("qml/MeoKDE/MetricCard.qml")
        for token in ("readonly property bool compact", "readonly property bool narrow",
                      "readonly property bool tiny", "clip: true",
                      "fontSizeMode: Text.HorizontalFit", "Layout.maximumWidth: limit"):
            with self.subTest(token=token):
                self.assertIn(token, card)

    def test_performance_widget_drops_cards_instead_of_squashing_them(self):
        widget = read("plasmoids/org.meo.widget.performance/contents/ui/main.qml")
        for token in ("visibleCards", "cardMinHeight", "summaryColumn.height",
                      "summaryHeader", "footerRow"):
            with self.subTest(token=token):
                self.assertIn(token, widget)

    def test_media_empty_state_is_height_aware(self):
        widget = read("plasmoids/org.meo.widget.media/contents/ui/main.qml")
        self.assertIn("parent.parent.height >= 190", widget)


if __name__ == "__main__":
    unittest.main()
