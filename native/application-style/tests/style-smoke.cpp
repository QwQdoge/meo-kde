#include <QtCore/QCoreApplication>
#include <QtCore/QScopeGuard>
#include <QtGui/QImage>
#include <QtGui/QPainter>
#include <QtTest/QTest>
#include <QtWidgets/QApplication>
#include <QtWidgets/QComboBox>
#include <QtWidgets/QMenu>
#include <QtWidgets/QMenuBar>
#include <QtWidgets/QProxyStyle>
#include <QtWidgets/QPushButton>
#include <QtWidgets/QScrollBar>
#include <QtWidgets/QSlider>
#include <QtWidgets/QStyleFactory>
#include <QtWidgets/QStyleOptionComboBox>
#include <QtWidgets/QStyleOptionMenuItem>
#include <QtWidgets/QStyleOptionSlider>
#include <QtWidgets/QStyleOptionTab>
#include <QtWidgets/QStyleOptionToolButton>
#include <QtWidgets/QTabBar>
#include <QtWidgets/QVBoxLayout>

#include <array>
#include <memory>

namespace {

enum class ControlKind {
    Button,
    DefaultButton,
    ToolButton,
    ComboBox,
    Menu,
    MenuBar,
    Slider,
    Tab,
    ScrollBar,
};

std::unique_ptr<QStyle> createMeoStyle()
{
    return std::unique_ptr<QStyle>(QStyleFactory::create(QStringLiteral("Meo")));
}

QPalette semanticPalette(const QColor &accent, bool dark = false)
{
    QPalette palette;
    const std::array groups{QPalette::Active, QPalette::Inactive, QPalette::Disabled};
    for (const QPalette::ColorGroup group : groups) {
        const bool disabled = group == QPalette::Disabled;
        palette.setColor(group, QPalette::Window,
                         disabled ? QColor("#30343a") : dark ? QColor("#1b1b1f") : QColor("#f7f2fa"));
        palette.setColor(group, QPalette::WindowText,
                         disabled ? QColor("#777b82") : dark ? QColor("#e5e1e6") : QColor("#211f24"));
        palette.setColor(group, QPalette::Base,
                         disabled ? QColor("#34383e") : dark ? QColor("#141317") : QColor("#fff8ff"));
        palette.setColor(group, QPalette::Text,
                         disabled ? QColor("#777b82") : dark ? QColor("#e5e1e6") : QColor("#211f24"));
        palette.setColor(group, QPalette::Button,
                         disabled ? QColor("#3b3f45") : dark ? QColor("#36343b") : QColor("#ece6f0"));
        palette.setColor(group, QPalette::ButtonText,
                         disabled ? QColor("#777b82") : dark ? QColor("#e5e1e6") : QColor("#211f24"));
        palette.setColor(group, QPalette::Highlight, disabled ? QColor("#665f69") : accent);
        palette.setColor(group, QPalette::HighlightedText, disabled ? QColor("#aaa3ad") : QColor("#ffffff"));
        palette.setColor(group, QPalette::Mid,
                         disabled ? QColor("#51555b") : dark ? QColor("#938f99") : QColor("#79747e"));
        palette.setColor(group, QPalette::Midlight,
                         disabled ? QColor("#41454b") : dark ? QColor("#49454f") : QColor("#cac4d0"));
        palette.setColor(group, QPalette::Dark,
                         disabled ? QColor("#292d32") : dark ? QColor("#cac4d0") : QColor("#49454f"));
    }
    return palette;
}

bool imageHasContent(const QImage &image)
{
    int opaquePixels = 0;
    QRgb first = 0;
    bool hasFirst = false;
    bool hasDifferentPixel = false;
    for (int y = 0; y < image.height(); ++y) {
        const auto *line = reinterpret_cast<const QRgb *>(image.constScanLine(y));
        for (int x = 0; x < image.width(); ++x) {
            if (qAlpha(line[x]) == 0) {
                continue;
            }
            ++opaquePixels;
            if (!hasFirst) {
                first = line[x];
                hasFirst = true;
            } else if (line[x] != first) {
                hasDifferentPixel = true;
            }
        }
    }
    return opaquePixels > 24 && hasDifferentPixel;
}

bool imageContainsColor(const QImage &image, const QColor &wanted, int tolerance = 2)
{
    for (int y = 0; y < image.height(); ++y) {
        const auto *line = reinterpret_cast<const QRgb *>(image.constScanLine(y));
        for (int x = 0; x < image.width(); ++x) {
            const QColor actual = QColor::fromRgba(line[x]);
            if (actual.alpha() > 0
                && qAbs(actual.red() - wanted.red()) <= tolerance
                && qAbs(actual.green() - wanted.green()) <= tolerance
                && qAbs(actual.blue() - wanted.blue()) <= tolerance) {
                return true;
            }
        }
    }
    return false;
}

QImage renderControl(QStyle *style, ControlKind kind, QStyle::State extraState,
                     const QPalette &palette, bool enabled = true)
{
    const QSize canvasSize = kind == ControlKind::Slider || kind == ControlKind::ScrollBar
        ? QSize(220, 44)
        : QSize(220, 48);
    QImage image(canvasSize, QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);
    QPainter painter(&image);

    QStyle::State state = QStyle::State_Active | extraState;
    if (enabled) {
        state |= QStyle::State_Enabled;
    }

    switch (kind) {
    case ControlKind::Button:
    case ControlKind::DefaultButton: {
        QStyleOptionButton option;
        option.rect = image.rect().adjusted(8, 4, -8, -4);
        option.palette = palette;
        option.state = state;
        option.text = kind == ControlKind::DefaultButton
            ? QStringLiteral("Default action") : QStringLiteral("Action");
        if (kind == ControlKind::DefaultButton) {
            option.features = QStyleOptionButton::DefaultButton;
        }
        style->drawPrimitive(QStyle::PE_PanelButtonCommand, &option, &painter);
        style->drawControl(QStyle::CE_PushButtonLabel, &option, &painter);
        break;
    }
    case ControlKind::ToolButton: {
        QStyleOptionToolButton option;
        option.rect = QRect((image.width() - 40) / 2, 4, 40, 40);
        option.palette = palette;
        option.state = state | QStyle::State_AutoRaise;
        option.text = QStringLiteral("T");
        option.toolButtonStyle = Qt::ToolButtonTextOnly;
        option.features = QStyleOptionToolButton::None;
        style->drawPrimitive(QStyle::PE_PanelButtonTool, &option, &painter);
        style->drawControl(QStyle::CE_ToolButtonLabel, &option, &painter);
        break;
    }
    case ControlKind::ComboBox: {
        QStyleOptionComboBox option;
        option.rect = image.rect().adjusted(8, 4, -8, -4);
        option.palette = palette;
        option.state = state;
        option.subControls = QStyle::SC_ComboBoxFrame | QStyle::SC_ComboBoxArrow;
        option.frame = true;
        option.currentText = QStringLiteral("Semantic choice");
        style->drawComplexControl(QStyle::CC_ComboBox, &option, &painter);
        style->drawControl(QStyle::CE_ComboBoxLabel, &option, &painter);
        break;
    }
    case ControlKind::Menu:
    case ControlKind::MenuBar: {
        QStyleOptionMenuItem option;
        option.rect = image.rect().adjusted(8, 4, -8, -4);
        option.palette = palette;
        option.state = state;
        option.menuItemType = QStyleOptionMenuItem::Normal;
        option.text = kind == ControlKind::Menu ? QStringLiteral("Selected menu item")
                                                : QStringLiteral("Selected menu");
        option.font = QApplication::font();
        option.fontMetrics = QFontMetrics(option.font);
        style->drawControl(kind == ControlKind::Menu ? QStyle::CE_MenuItem
                                                     : QStyle::CE_MenuBarItem,
                           &option, &painter);
        break;
    }
    case ControlKind::Slider:
    case ControlKind::ScrollBar: {
        QStyleOptionSlider option;
        option.rect = image.rect().adjusted(8, 4, -8, -4);
        option.palette = palette;
        option.state = state;
        option.orientation = Qt::Horizontal;
        option.minimum = 0;
        option.maximum = 100;
        option.sliderPosition = 62;
        option.sliderValue = 62;
        option.pageStep = 10;
        if (kind == ControlKind::Slider) {
            option.subControls = QStyle::SC_SliderGroove | QStyle::SC_SliderHandle;
            if (extraState.testFlag(QStyle::State_MouseOver) || extraState.testFlag(QStyle::State_Sunken)) {
                option.activeSubControls = QStyle::SC_SliderHandle;
            }
            style->drawComplexControl(QStyle::CC_Slider, &option, &painter);
        } else {
            option.subControls = QStyle::SC_ScrollBarGroove | QStyle::SC_ScrollBarSlider
                | QStyle::SC_ScrollBarSubLine | QStyle::SC_ScrollBarAddLine;
            if (extraState.testFlag(QStyle::State_MouseOver) || extraState.testFlag(QStyle::State_Sunken)) {
                option.activeSubControls = QStyle::SC_ScrollBarSlider;
            }
            style->drawComplexControl(QStyle::CC_ScrollBar, &option, &painter);
        }
        break;
    }
    case ControlKind::Tab: {
        QStyleOptionTab option;
        option.rect = image.rect().adjusted(8, 4, -8, -4);
        option.palette = palette;
        option.state = state | QStyle::State_Selected;
        option.shape = QTabBar::RoundedNorth;
        option.text = QStringLiteral("Selected tab");
        style->drawControl(QStyle::CE_TabBarTab, &option, &painter);
        break;
    }
    }

    painter.end();
    return image;
}

QImage renderWidget(QWidget *widget, const QSize &minimumSize = {})
{
    widget->ensurePolished();
    QSize size = widget->sizeHint().expandedTo(minimumSize);
    if (!size.isValid()) {
        size = QSize(240, 48);
    }
    widget->resize(size);
    widget->show();
    QApplication::processEvents();

    QImage image(widget->size(), QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);
    widget->render(&image);
    widget->hide();
    return image;
}

QImage renderWidgetGallery(QStyle *style, const QPalette &palette)
{
    QWidget gallery;
    gallery.setStyle(style);
    gallery.setPalette(palette);
    auto *layout = new QVBoxLayout(&gallery);

    auto *menuBar = new QMenuBar(&gallery);
    QAction *fileAction = menuBar->addAction(QStringLiteral("File"));
    menuBar->addAction(QStringLiteral("Edit"));
    menuBar->setActiveAction(fileAction);
    auto *button = new QPushButton(QStringLiteral("Action"), &gallery);
    auto *combo = new QComboBox(&gallery);
    combo->addItems({QStringLiteral("First"), QStringLiteral("Second")});
    auto *tabs = new QTabBar(&gallery);
    tabs->addTab(QStringLiteral("Overview"));
    tabs->addTab(QStringLiteral("Details"));
    auto *slider = new QSlider(Qt::Horizontal, &gallery);
    slider->setValue(62);
    auto *scrollBar = new QScrollBar(Qt::Horizontal, &gallery);
    scrollBar->setRange(0, 100);
    scrollBar->setPageStep(20);
    scrollBar->setValue(45);

    layout->addWidget(menuBar);
    layout->addWidget(button);
    layout->addWidget(combo);
    layout->addWidget(tabs);
    layout->addWidget(slider);
    layout->addWidget(scrollBar);
    return renderWidget(&gallery, QSize(320, 250));
}

} // namespace

class StyleSmoke final : public QObject
{
    Q_OBJECT

private slots:
    void discoversMeoAndUsesKdeBase()
    {
        QVERIFY2(QStyleFactory::keys().contains(QStringLiteral("Meo"), Qt::CaseInsensitive),
                 "The staged Meo QStyle plugin was not discovered");
        const auto style = createMeoStyle();
        QVERIFY(style);
        QCOMPARE(style->objectName().compare(QStringLiteral("Meo"), Qt::CaseInsensitive), 0);

        const auto *proxy = dynamic_cast<const QProxyStyle *>(style.get());
        QVERIFY(proxy);
        QVERIFY(proxy->baseStyle());
        if (QStyleFactory::keys().contains(QStringLiteral("Breeze"), Qt::CaseInsensitive)) {
            QVERIFY2(proxy->baseStyle()->objectName().contains(QStringLiteral("breeze"), Qt::CaseInsensitive),
                     qPrintable(QStringLiteral("Expected Breeze base, got %1")
                                    .arg(proxy->baseStyle()->objectName())));
        }
    }

    void preservesApplicationPalette()
    {
        const QPalette original = QApplication::palette();
        const auto restore = qScopeGuard([original]() { QApplication::setPalette(original); });
        const QPalette dynamic = semanticPalette(QColor("#9b2bd9"));
        QApplication::setPalette(dynamic);
        const auto style = createMeoStyle();
        QVERIFY(style);

        const QPalette standard = style->standardPalette();
        QCOMPARE(standard.color(QPalette::Active, QPalette::Highlight),
                 dynamic.color(QPalette::Active, QPalette::Highlight));
        QCOMPARE(standard.color(QPalette::Active, QPalette::Button),
                 dynamic.color(QPalette::Active, QPalette::Button));
        QCOMPARE(standard.color(QPalette::Inactive, QPalette::Window),
                 dynamic.color(QPalette::Inactive, QPalette::Window));
        QCOMPARE(standard.color(QPalette::Disabled, QPalette::ButtonText),
                 dynamic.color(QPalette::Disabled, QPalette::ButtonText));
    }

    void rendersActualWidgetsAndMenu()
    {
        const auto style = createMeoStyle();
        QVERIFY(style);
        const QPalette palette = semanticPalette(QColor("#6750a4"));

        const QImage gallery = renderWidgetGallery(style.get(), palette);
        QVERIFY2(imageHasContent(gallery), "The offscreen widget gallery rendered no meaningful pixels");
        QVERIFY2(imageContainsColor(gallery, palette.color(QPalette::Active, QPalette::Highlight), 4),
                 "The widget gallery did not consume the active semantic highlight role");

        QMenu menu;
        menu.setStyle(style.get());
        menu.setPalette(palette);
        QAction *first = menu.addAction(QStringLiteral("Open"));
        menu.addAction(QStringLiteral("Save"));
        menu.setActiveAction(first);
        const QImage menuImage = renderWidget(&menu, QSize(220, 80));
        QVERIFY2(imageHasContent(menuImage), "The offscreen menu rendered no meaningful pixels");
    }

    void rendersEveryInteractionState()
    {
        const auto style = createMeoStyle();
        QVERIFY(style);
        const QPalette palette = semanticPalette(QColor("#006e2f"));
        const std::array controls{ControlKind::Button, ControlKind::DefaultButton, ControlKind::ToolButton,
                                  ControlKind::ComboBox, ControlKind::Menu, ControlKind::MenuBar,
                                  ControlKind::Slider, ControlKind::Tab, ControlKind::ScrollBar};

        for (const ControlKind control : controls) {
            const QImage normal = renderControl(style.get(), control, QStyle::State_None, palette);
            QVERIFY2(imageHasContent(normal), "A normal control rendered no meaningful pixels");

            QStyle::State selectedHover = QStyle::State_MouseOver;
            if (control == ControlKind::Menu || control == ControlKind::MenuBar) {
                selectedHover |= QStyle::State_Selected;
            }
            const QImage hover = renderControl(style.get(), control, selectedHover, palette);
            const QImage pressed = renderControl(style.get(), control,
                selectedHover | QStyle::State_Sunken, palette);
            const QImage focus = renderControl(style.get(), control,
                QStyle::State_HasFocus | (control == ControlKind::Menu || control == ControlKind::MenuBar
                                              ? QStyle::State_Selected
                                              : QStyle::State_None), palette);
            const QImage disabled = renderControl(style.get(), control,
                control == ControlKind::Menu || control == ControlKind::MenuBar
                    ? QStyle::State_Selected
                    : QStyle::State_None,
                palette, false);

            QVERIFY2(imageHasContent(hover), "A hovered control rendered no meaningful pixels");
            QVERIFY2(imageHasContent(pressed), "A pressed control rendered no meaningful pixels");
            QVERIFY2(imageHasContent(focus), "A focused control rendered no meaningful pixels");
            QVERIFY2(imageHasContent(disabled), "A disabled control rendered no meaningful pixels");
            const QByteArray controlId = QByteArray::number(static_cast<int>(control));
            QVERIFY2(normal != hover, qPrintable(QStringLiteral("Control %1 hover rendering must differ from normal rendering")
                                                     .arg(QString::fromLatin1(controlId))));
            QVERIFY2(hover != pressed, qPrintable(QStringLiteral("Control %1 pressed rendering must differ from hover rendering")
                                                      .arg(QString::fromLatin1(controlId))));
            QVERIFY2(normal != focus, qPrintable(QStringLiteral("Control %1 focus rendering must differ from normal rendering")
                                                     .arg(QString::fromLatin1(controlId))));
            QVERIFY2(normal != disabled, qPrintable(QStringLiteral("Control %1 disabled rendering must differ from enabled rendering")
                                                        .arg(QString::fromLatin1(controlId))));
        }
    }

    void followsDynamicSemanticPaletteWithoutRecreatingStyle()
    {
        const auto style = createMeoStyle();
        QVERIFY(style);
        const QPalette violet = semanticPalette(QColor("#6750a4"));
        const QPalette orange = semanticPalette(QColor("#a33d00"), true);
        const std::array controls{ControlKind::Button, ControlKind::DefaultButton, ControlKind::ToolButton,
                                  ControlKind::ComboBox, ControlKind::Menu, ControlKind::MenuBar,
                                  ControlKind::Slider, ControlKind::Tab, ControlKind::ScrollBar};

        for (const ControlKind control : controls) {
            QStyle::State state = QStyle::State_MouseOver;
            if (control == ControlKind::ComboBox) {
                state |= QStyle::State_HasFocus;
            }
            if (control == ControlKind::Menu || control == ControlKind::MenuBar) {
                state |= QStyle::State_Selected;
            }
            if (control == ControlKind::ScrollBar) {
                state |= QStyle::State_Sunken;
            }
            const QImage first = renderControl(style.get(), control, state, violet);
            const QImage second = renderControl(style.get(), control, state, orange);
            QVERIFY2(first != second,
                     qPrintable(QStringLiteral("Control %1 ignored a live semantic palette change")
                                    .arg(static_cast<int>(control))));
        }

        const QImage slider = renderControl(style.get(), ControlKind::Slider,
                                             QStyle::State_None, orange);
        const QImage tab = renderControl(style.get(), ControlKind::Tab,
                                         QStyle::State_None, orange);
        const QImage pressedScrollBar = renderControl(style.get(), ControlKind::ScrollBar,
            QStyle::State_MouseOver | QStyle::State_Sunken, orange);
        const QImage focusedCombo = renderControl(style.get(), ControlKind::ComboBox,
            QStyle::State_HasFocus, orange);
        QVERIFY(imageContainsColor(slider, orange.color(QPalette::Active, QPalette::Highlight)));
        QVERIFY(imageContainsColor(tab, orange.color(QPalette::Active, QPalette::Highlight)));
        QVERIFY(imageContainsColor(pressedScrollBar, orange.color(QPalette::Active, QPalette::Highlight)));
        QVERIFY(imageContainsColor(focusedCombo, orange.color(QPalette::Active, QPalette::Highlight)));

        const QImage defaultButton = renderControl(style.get(), ControlKind::DefaultButton,
                                                    QStyle::State_None, orange);
        QVERIFY(imageContainsColor(defaultButton,
                                   orange.color(QPalette::Active, QPalette::Highlight)));

        const QImage disabledCombo = renderControl(style.get(), ControlKind::ComboBox,
                                                    QStyle::State_None, orange, false);
        QVERIFY(imageContainsColor(disabledCombo,
                                   orange.color(QPalette::Disabled, QPalette::Button)));
    }
};

int main(int argc, char **argv)
{
    QApplication app(argc, argv);
    QCoreApplication::addLibraryPath(QStringLiteral(MEO_STYLE_PLUGIN_ROOT));
    StyleSmoke test;
    return QTest::qExec(&test, argc, argv);
}

#include "style-smoke.moc"
