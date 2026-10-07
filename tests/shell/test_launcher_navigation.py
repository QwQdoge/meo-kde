import json
from pathlib import Path
import unittest

try:
    from PySide6.QtCore import QCoreApplication, Qt
    from PySide6.QtQml import QJSEngine
except ImportError:
    QJSEngine = None

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'plasmoids/org.meo.shelf/contents/ui/LauncherPopup.qml'


def function_source(name):
    text = SOURCE.read_text()
    start = text.index('function ' + name + '(')
    opening = text.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    return text[start:end]


@unittest.skipIf(QJSEngine is None, 'PySide6 is installed by Source contracts CI')
class LauncherNavigationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QCoreApplication.instance() or QCoreApplication([])

    def setUp(self):
        self.engine = QJSEngine()
        qt = {name: getattr(Qt, name).value for name in (
            'AltModifier', 'MetaModifier', 'ControlModifier',
            'Key_J', 'Key_N', 'Key_K', 'Key_P', 'Key_PageDown', 'Key_PageUp', 'Key_A')}
        setup = 'var Qt = ' + json.dumps(qt) + ''';
            var searching = true, MeoTheme = {globalScale: 1}, ListView = {Contain: 1};
            var searchResultList = {count: 12, currentIndex: 0, height: 180,
                currentItem: {height: 60}, positionViewAtIndex: function(i) {this.scrolled = i;}};
            var paneLoader = {item: {moveSelection: moveSelection}};
        '''
        for code in (function_source('moveSelection'), setup,
                     function_source('handleSearchNavigation')):
            value = self.engine.evaluate(code)
            self.assertFalse(value.isError(), value.toString())

    def evaluate(self, code):
        result = self.engine.evaluate(code)
        self.assertFalse(result.isError(), result.toString())
        return result

    def test_shortcuts_scroll_and_preserve_bounds(self):
        self.assertTrue(self.evaluate('handleSearchNavigation({key:Qt.Key_J, modifiers:Qt.ControlModifier})').toBool())
        self.assertEqual(self.evaluate('searchResultList.currentIndex').toInt(), 1)
        self.evaluate('handleSearchNavigation({key:Qt.Key_PageDown, modifiers:0})')
        self.assertEqual(self.evaluate('searchResultList.scrolled').toInt(), 4)
        self.evaluate('searchResultList.currentIndex=11; moveSelection(1,true)')
        self.assertEqual(self.evaluate('searchResultList.currentIndex').toInt(), 11)
        self.evaluate('searchResultList.currentIndex=0; moveSelection(-1,true)')
        self.assertEqual(self.evaluate('searchResultList.currentIndex').toInt(), 0)
        self.evaluate('searchResultList.count=0; searchResultList.currentIndex=-1; moveSelection(1,true)')
        self.assertEqual(self.evaluate('searchResultList.currentIndex').toInt(), -1)

    def test_home_unrelated_and_modified_keys_are_not_consumed(self):
        for setup, event in (
            ('searching=false;', '{key:Qt.Key_J, modifiers:Qt.ControlModifier}'),
            ('searching=true;', '{key:Qt.Key_A, modifiers:0}'),
            ('', '{key:Qt.Key_J, modifiers:Qt.ControlModifier|Qt.AltModifier}'),
            ('', '{key:Qt.Key_PageDown, modifiers:Qt.MetaModifier}'),
        ):
            self.assertFalse(self.evaluate(setup + 'handleSearchNavigation(' + event + ')').toBool())
