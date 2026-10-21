"""KI18n substitutes %N from call arguments only.

`i18n("%1 min").arg(n)` yields "(I18N_ARGUMENT_MISSING) min" at runtime, so
shell QML must pass arguments to i18n() itself.
"""

from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCES = [ROOT / "qml", ROOT / "plasmoids", ROOT / "themes/look-and-feel"]
CHAINED = re.compile(r"""i18n[a-z]?\(\s*(?:"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')\s*\)\s*\.arg\(""")


class I18nArgumentContract(unittest.TestCase):
    def test_no_arg_chained_after_i18n(self):
        offenders = []
        for base in SOURCES:
            for path in base.rglob("*.qml"):
                if CHAINED.search(path.read_text(encoding="utf-8")):
                    offenders.append(str(path.relative_to(ROOT)))
        self.assertEqual(offenders, [])


if __name__ == "__main__":
    unittest.main()
