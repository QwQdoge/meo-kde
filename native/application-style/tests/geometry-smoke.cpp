#include "meostyle.h"
#include "meostyleprogress.h"

#include <QtTest/QTest>
#include <limits>
#include <QtWidgets/QApplication>
#include <QtWidgets/QStyleOptionButton>
#include <QtWidgets/QStyleOptionComboBox>
#include <QtWidgets/QStyleOptionFrame>
#include <QtWidgets/QStyleOptionHeader>
#include <QtWidgets/QStyleOptionGroupBox>
#include <QtWidgets/QStyleOptionMenuItem>
#include <QtWidgets/QStyleOptionSlider>
#include <QtWidgets/QStyleOptionSpinBox>
#include <QtWidgets/QStyleOptionToolButton>
#include <QtWidgets/QStyleOptionToolBar>
#include <QtWidgets/QStyleOptionTab>
#include <QtWidgets/QStyleOptionViewItem>
#include <QtWidgets/QTabBar>
#include <QtWidgets/QWidget>

#include <meodesigntokens.h>

class MeoStyleGeometryTest final : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void commonControlSizesIgnoreBaseGeometry();
    void progressDirectionAndFullIntegerRange();
    void toolbarHandleOwnsItsMarginsAndMirrors();
    void groupTitleAndCheckReserveContents();
    void headerContentReservesSortIndicator();
    void complexControlsHitTheirOwnGeometry();
    void itemContentsShareCheckIconAndEditorGeometry();
    void tabContentsReserveButtonsInEveryOrientation();
    void pushButtonContentUsesMeoInsets();
    void sizeHintsReserveContentAndMenuInsets();
    void searchFieldGetsWiderContentInset();
    void checkIndicatorMirrorsInRtl();
    void comboArrowAndContentMirrorInRtl();
    void splitToolButtonOwnsMenuRegion();
    void sliderHandleUsesMeoTokenSize();
};

void MeoStyleGeometryTest::commonControlSizesIgnoreBaseGeometry()
{
    class OversizedBase final : public QProxyStyle {
    public:
        QSize sizeFromContents(ContentsType, const QStyleOption *, const QSize &, const QWidget *) const override { return QSize(900, 900); }
    };
    MeoStyle style; style.setBaseStyle(new OversizedBase);
    const QSize contents(80, 16);
    QStyleOptionButton button;
    for (const auto type : {QStyle::CT_CheckBox, QStyle::CT_RadioButton, QStyle::CT_PushButton, QStyle::CT_LineEdit}) {
        const QSize size = style.sizeFromContents(type, &button, contents, nullptr);
        QCOMPARE(size.height(), qRound(Meo::DesignTokens::controlHeight()));
        QVERIFY(size.width() < 200);
    }
    QStyleOptionToolButton tool;
    QCOMPARE(style.sizeFromContents(QStyle::CT_ToolButton, &tool, contents, nullptr).height(), qRound(Meo::DesignTokens::controlHeight()));
    QStyleOptionMenuItem menu;
    menu.text = QStringLiteral("Open\tCtrl+O");
    menu.menuItemType = QStyleOptionMenuItem::Normal;
    menu.checkType = QStyleOptionMenuItem::NotCheckable;
    menu.menuHasCheckableItems = false;
    menu.maxIconWidth = 0;
    const QSize plainMenu = style.sizeFromContents(QStyle::CT_MenuItem, &menu, contents, nullptr);
    QVERIFY(plainMenu.width() < 300);
    menu.menuHasCheckableItems = true;
    QCOMPARE(style.sizeFromContents(QStyle::CT_MenuItem, &menu, contents, nullptr).width() - plainMenu.width(), qRound(Meo::DesignTokens::iconSizeS() + Meo::DesignTokens::space8()));
    QStyleOptionComboBox combo;
    QCOMPARE(style.sizeFromContents(QStyle::CT_ComboBox, &combo, contents, nullptr).height(), qRound(Meo::DesignTokens::controlHeight()));
}

void MeoStyleGeometryTest::tabContentsReserveButtonsInEveryOrientation()
{
    MeoStyle style;
    for (const auto shape : {QTabBar::RoundedNorth, QTabBar::RoundedSouth, QTabBar::RoundedWest, QTabBar::RoundedEast}) {
        for (const auto direction : {Qt::LeftToRight, Qt::RightToLeft}) {
            QStyleOptionTab tab;
            tab.shape = shape; tab.direction = direction;
            tab.text = QStringLiteral("&Files");
            tab.leftButtonSize = QSize(20, 24); tab.rightButtonSize = QSize(24, 24);
            const bool vertical = shape == QTabBar::RoundedWest || shape == QTabBar::RoundedEast;
            const QSize size = style.sizeFromContents(QStyle::CT_TabBarTab, &tab, QSize(900, 900), nullptr);
            QVERIFY(size.width() < 300); QVERIFY(size.height() < 300);
            QCOMPARE(vertical ? size.width() : size.height(), qRound(Meo::DesignTokens::controlHeight()));
            tab.rect = QRect(QPoint(17, 29), vertical ? QSize(40, 220) : QSize(220, 40));
            const QRect content = style.subElementRect(QStyle::SE_TabBarTabText, &tab);
            const QRect left = style.subElementRect(QStyle::SE_TabBarTabLeftButton, &tab);
            const QRect right = style.subElementRect(QStyle::SE_TabBarTabRightButton, &tab);
            QVERIFY(tab.rect.contains(content)); QVERIFY(tab.rect.contains(left)); QVERIFY(tab.rect.contains(right));
            QCOMPARE(left.size(), tab.leftButtonSize); QCOMPARE(right.size(), tab.rightButtonSize);
            QVERIFY(!content.intersects(left)); QVERIFY(!content.intersects(right)); QVERIFY(!left.intersects(right));
        }
    }
}

void MeoStyleGeometryTest::itemContentsShareCheckIconAndEditorGeometry()
{
    MeoStyle style;
    for (const auto position : {QStyleOptionViewItem::Left, QStyleOptionViewItem::Right, QStyleOptionViewItem::Top, QStyleOptionViewItem::Bottom}) {
        QStyleOptionViewItem item;
        item.rect = QRect(13, 21, 220, 120); item.text = QStringLiteral("File name");
        item.features = QStyleOptionViewItem::HasDisplay | QStyleOptionViewItem::HasDecoration | QStyleOptionViewItem::HasCheckIndicator;
        item.decorationPosition = position; item.decorationSize = QSize(24, 24);
        item.decorationAlignment = Qt::AlignCenter;
        const QRect text = style.subElementRect(QStyle::SE_ItemViewItemText, &item);
        const QRect icon = style.subElementRect(QStyle::SE_ItemViewItemDecoration, &item);
        const QRect check = style.subElementRect(QStyle::SE_ItemViewItemCheckIndicator, &item);
        QVERIFY(item.rect.contains(text)); QVERIFY(item.rect.contains(icon)); QVERIFY(item.rect.contains(check));
        QVERIFY(!text.intersects(icon)); QVERIFY(!text.intersects(check)); QVERIFY(!icon.intersects(check));
        item.direction = Qt::RightToLeft;
        QCOMPARE(style.subElementRect(QStyle::SE_ItemViewItemText, &item), QStyle::visualRect(Qt::RightToLeft, item.rect, text));
        QCOMPARE(style.subElementRect(QStyle::SE_ItemViewItemDecoration, &item), QStyle::visualRect(Qt::RightToLeft, item.rect, icon));
        QCOMPARE(style.subElementRect(QStyle::SE_ItemViewItemCheckIndicator, &item), QStyle::visualRect(Qt::RightToLeft, item.rect, check));
    }
    QStyleOptionViewItem wrapped;
    wrapped.text = QStringLiteral("A long name that should occupy several lines in a narrow column");
    wrapped.features = QStyleOptionViewItem::HasDisplay | QStyleOptionViewItem::WrapText;
    wrapped.rect = QRect(0, 0, 100, 200);
    const QSize narrow = style.sizeFromContents(QStyle::CT_ItemViewItem, &wrapped, QSize(), nullptr);
    wrapped.rect.setWidth(400);
    const QSize wide = style.sizeFromContents(QStyle::CT_ItemViewItem, &wrapped, QSize(), nullptr);
    QVERIFY(narrow.height() > wide.height());
    QVERIFY(narrow.width() <= 100);
}

void MeoStyleGeometryTest::complexControlsHitTheirOwnGeometry()
{
    MeoStyle style;
    for (auto direction : {Qt::LeftToRight, Qt::RightToLeft}) {
        QStyleOptionSpinBox spin;
        spin.rect = QRect(13, 27, 180, 41); spin.direction = direction;
        spin.buttonSymbols = QAbstractSpinBox::UpDownArrows;
        const QRect edit = style.subControlRect(QStyle::CC_SpinBox, &spin, QStyle::SC_SpinBoxEditField);
        for (auto part : {QStyle::SC_SpinBoxUp, QStyle::SC_SpinBoxDown}) {
            const QRect button = style.subControlRect(QStyle::CC_SpinBox, &spin, part);
            QVERIFY(spin.rect.contains(button)); QVERIFY(!edit.intersects(button));
            QCOMPARE(style.hitTestComplexControl(QStyle::CC_SpinBox, &spin, button.center()), part);
        }
        spin.buttonSymbols = QAbstractSpinBox::NoButtons;
        QVERIFY(style.subControlRect(QStyle::CC_SpinBox, &spin, QStyle::SC_SpinBoxUp).isEmpty());
        for (auto orientation : {Qt::Horizontal, Qt::Vertical}) {
            for (bool inverted : {false, true}) {
                QStyleOptionSlider bar;
                bar.rect = QRect(13, 27, orientation == Qt::Horizontal ? 240 : 14, orientation == Qt::Horizontal ? 14 : 240);
                bar.direction = direction; bar.orientation = orientation; bar.upsideDown = inverted;
                bar.minimum = -100; bar.maximum = 100; bar.pageStep = 5; bar.sliderPosition = 0;
                for (auto part : {QStyle::SC_ScrollBarSubLine, QStyle::SC_ScrollBarAddLine, QStyle::SC_ScrollBarSlider, QStyle::SC_ScrollBarSubPage, QStyle::SC_ScrollBarAddPage}) {
                    const QRect rect = style.subControlRect(QStyle::CC_ScrollBar, &bar, part);
                    QVERIFY(bar.rect.contains(rect));
                    QCOMPARE(style.hitTestComplexControl(QStyle::CC_ScrollBar, &bar, rect.center()), part);
                }
                const QRect thumb = style.subControlRect(QStyle::CC_ScrollBar, &bar, QStyle::SC_ScrollBarSlider);
                QCOMPARE(orientation == Qt::Horizontal ? thumb.width() : thumb.height(), qRound(Meo::DesignTokens::space32()));
                bar.minimum = bar.maximum = 0;
                QCOMPARE(style.subControlRect(QStyle::CC_ScrollBar, &bar, QStyle::SC_ScrollBarSlider), style.subControlRect(QStyle::CC_ScrollBar, &bar, QStyle::SC_ScrollBarGroove));
            }
        }
    }
}

void MeoStyleGeometryTest::headerContentReservesSortIndicator()
{
    MeoStyle style;
    for (auto orientation : {Qt::Horizontal, Qt::Vertical}) {
        QStyleOptionHeader header;
        header.rect = QRect(13, 27, 180, 40); header.text = QStringLiteral("Name");
        header.orientation = orientation; header.sortIndicator = QStyleOptionHeader::SortUp;
        const QRect label = style.subElementRect(QStyle::SE_HeaderLabel, &header);
        const QRect arrow = style.subElementRect(QStyle::SE_HeaderArrow, &header);
        QVERIFY(header.rect.contains(label)); QVERIFY(header.rect.contains(arrow)); QVERIFY(!label.intersects(arrow));
        header.direction = Qt::RightToLeft;
        QCOMPARE(style.subElementRect(QStyle::SE_HeaderLabel, &header), QStyle::visualRect(Qt::RightToLeft, header.rect, label));
        QCOMPARE(style.subElementRect(QStyle::SE_HeaderArrow, &header), QStyle::visualRect(Qt::RightToLeft, header.rect, arrow));
        const QSize sorted = style.sizeFromContents(QStyle::CT_HeaderSection, &header, QSize(900, 900), nullptr);
        QCOMPARE(sorted.height(), qRound(Meo::DesignTokens::controlHeight()));
        header.sortIndicator = QStyleOptionHeader::None;
        QVERIFY(style.subElementRect(QStyle::SE_HeaderArrow, &header).isEmpty());
        const QSize plain = style.sizeFromContents(QStyle::CT_HeaderSection, &header, QSize(900, 900), nullptr);
        QCOMPARE(sorted.width() - plain.width(), qRound(Meo::DesignTokens::iconSizeS() + Meo::DesignTokens::space8()));
    }
}

void MeoStyleGeometryTest::groupTitleAndCheckReserveContents()
{
    MeoStyle style;
    for (auto alignment : {Qt::AlignLeft, Qt::AlignHCenter, Qt::AlignRight}) {
        QStyleOptionGroupBox group;
        group.rect = QRect(13, 27, 280, 180); group.text = QStringLiteral("&Options"); group.textAlignment = alignment;
        group.subControls = QStyle::SC_GroupBoxFrame | QStyle::SC_GroupBoxLabel | QStyle::SC_GroupBoxCheckBox;
        const QRect label = style.subControlRect(QStyle::CC_GroupBox, &group, QStyle::SC_GroupBoxLabel);
        const QRect check = style.subControlRect(QStyle::CC_GroupBox, &group, QStyle::SC_GroupBoxCheckBox);
        const QRect contents = style.subControlRect(QStyle::CC_GroupBox, &group, QStyle::SC_GroupBoxContents);
        QVERIFY(group.rect.contains(label)); QVERIFY(group.rect.contains(check)); QVERIFY(group.rect.contains(contents));
        QVERIFY(!label.intersects(check)); QVERIFY(!contents.intersects(label)); QVERIFY(!contents.intersects(check));
        QCOMPARE(style.hitTestComplexControl(QStyle::CC_GroupBox, &group, label.center()), QStyle::SC_GroupBoxLabel);
        QCOMPARE(style.hitTestComplexControl(QStyle::CC_GroupBox, &group, check.center()), QStyle::SC_GroupBoxCheckBox);
        group.direction = Qt::RightToLeft;
        QCOMPARE(style.subControlRect(QStyle::CC_GroupBox, &group, QStyle::SC_GroupBoxLabel), QStyle::visualRect(Qt::RightToLeft, group.rect, label));
        QCOMPARE(style.subControlRect(QStyle::CC_GroupBox, &group, QStyle::SC_GroupBoxCheckBox), QStyle::visualRect(Qt::RightToLeft, group.rect, check));
        QCOMPARE(style.subControlRect(QStyle::CC_GroupBox, &group, QStyle::SC_GroupBoxContents), contents);
    }
    QStyleOptionGroupBox untitled; untitled.rect = QRect(0, 0, 200, 120); untitled.subControls = QStyle::SC_GroupBoxFrame;
    QVERIFY(style.subControlRect(QStyle::CC_GroupBox, &untitled, QStyle::SC_GroupBoxLabel).isEmpty());
    QCOMPARE(style.subControlRect(QStyle::CC_GroupBox, &untitled, QStyle::SC_GroupBoxContents).top(), qRound(Meo::DesignTokens::space16()));
}

void MeoStyleGeometryTest::toolbarHandleOwnsItsMarginsAndMirrors()
{
    MeoStyle style;
    QStyleOptionToolBar bar; bar.rect = QRect(13, 27, 240, 48); bar.state = QStyle::State_Horizontal;
    bar.features = QStyleOptionToolBar::Movable;
    const QRect handle = style.subElementRect(QStyle::SE_ToolBarHandle, &bar);
    QVERIFY(bar.rect.contains(handle));
    QCOMPARE(handle.width(), qRound(Meo::DesignTokens::space12()));
    QCOMPARE(handle.left(), bar.rect.left() + qRound(Meo::DesignTokens::space4()));
    bar.direction = Qt::RightToLeft;
    QCOMPARE(style.subElementRect(QStyle::SE_ToolBarHandle, &bar), QStyle::visualRect(Qt::RightToLeft, bar.rect, handle));
    bar.rect = QRect(13, 27, 48, 240); bar.state = QStyle::State_None;
    const QRect vertical = style.subElementRect(QStyle::SE_ToolBarHandle, &bar);
    QVERIFY(bar.rect.contains(vertical));
    QCOMPARE(vertical.height(), qRound(Meo::DesignTokens::space12()));
    bar.features = QStyleOptionToolBar::None;
    QVERIFY(style.subElementRect(QStyle::SE_ToolBarHandle, &bar).isEmpty());
    QStyleOptionMenuItem menu; menu.text = QStringLiteral("&File");
    const QSize size = style.sizeFromContents(QStyle::CT_MenuBarItem, &menu, QSize(900, 900), nullptr);
    QCOMPARE(size.height(), qRound(Meo::DesignTokens::controlHeight()));
    QCOMPARE(size.width(), menu.fontMetrics.size(Qt::TextSingleLine | Qt::TextShowMnemonic, menu.text).width() + 2 * qRound(Meo::DesignTokens::space12()));
}

void MeoStyleGeometryTest::progressDirectionAndFullIntegerRange()
{
    QStyleOptionProgressBar bar;
    bar.rect = QRect(13, 27, 100, 20); bar.state = QStyle::State_Horizontal;
    bar.minimum = 0; bar.maximum = 100; bar.progress = 25;
    QCOMPARE(MeoProgress::activeRects(bar, 0).first(), QRectF(13, 27, 25, 20));
    bar.direction = Qt::RightToLeft;
    QCOMPARE(MeoProgress::activeRects(bar, 0).first(), QRectF(88, 27, 25, 20));
    bar.invertedAppearance = true;
    QCOMPARE(MeoProgress::activeRects(bar, 0).first(), QRectF(13, 27, 25, 20));
    bar.state = QStyle::State_None; bar.rect = QRect(13, 27, 20, 100); bar.invertedAppearance = false;
    QCOMPARE(MeoProgress::activeRects(bar, 0).first(), QRectF(13, 102, 20, 25));
    bar.invertedAppearance = true;
    QCOMPARE(MeoProgress::activeRects(bar, 0).first(), QRectF(13, 27, 20, 25));
    bar.minimum = std::numeric_limits<int>::min(); bar.maximum = std::numeric_limits<int>::max(); bar.progress = 0;
    const QRectF half = MeoProgress::activeRects(bar, 0).first();
    QVERIFY(qAbs(half.height() - 50.0) < 0.001);
    bar.minimum = bar.maximum = 0;
    QVERIFY(MeoProgress::activeRects(bar, 0.2) != MeoProgress::activeRects(bar, 0.6));
}

void MeoStyleGeometryTest::pushButtonContentUsesMeoInsets()
{
    MeoStyle style;
    QStyleOptionButton option;
    option.rect = QRect(0, 0, 160, 48);

    const QRect contents = style.subElementRect(QStyle::SE_PushButtonContents, &option);
    QCOMPARE(contents.left(), qRound(Meo::DesignTokens::space16()));
    QCOMPARE(contents.top(), qRound(Meo::DesignTokens::space4()));
    QCOMPARE(contents.right(), option.rect.right() - qRound(Meo::DesignTokens::space16()));
    QCOMPARE(contents.bottom(), option.rect.bottom() - qRound(Meo::DesignTokens::space4()));
}

void MeoStyleGeometryTest::sizeHintsReserveContentAndMenuInsets()
{
    MeoStyle style;
    const QSize text(100, 20);
    QStyleOptionButton button;
    button.rect = QRect(QPoint(), style.sizeFromContents(QStyle::CT_PushButton, &button, text, nullptr));
    QVERIFY(style.subElementRect(QStyle::SE_PushButtonContents, &button).width() >= text.width());
    QStyleOptionComboBox combo;
    combo.rect = QRect(QPoint(), style.sizeFromContents(QStyle::CT_ComboBox, &combo, text, nullptr));
    QVERIFY(style.subControlRect(QStyle::CC_ComboBox, &combo, QStyle::SC_ComboBoxEditField).width() >= text.width());
    QStyleOptionToolButton tool;
    tool.features = QStyleOptionToolButton::HasMenu | QStyleOptionToolButton::MenuButtonPopup;
    tool.rect = QRect(QPoint(), style.sizeFromContents(QStyle::CT_ToolButton, &tool, text, nullptr));
    QVERIFY(style.subControlRect(QStyle::CC_ToolButton, &tool, QStyle::SC_ToolButton).width() >= text.width());
}

void MeoStyleGeometryTest::searchFieldGetsWiderContentInset()
{
    MeoStyle style;
    QStyleOptionFrame option;
    option.rect = QRect(0, 0, 200, 48);
    QWidget field;

    const QRect ordinary = style.subElementRect(QStyle::SE_LineEditContents, &option, &field);
    field.setProperty("meo.role", QStringLiteral("search"));
    const QRect search = style.subElementRect(QStyle::SE_LineEditContents, &option, &field);

    QCOMPARE(ordinary.left(), qRound(Meo::DesignTokens::space12()));
    QCOMPARE(search.left(), qRound(Meo::DesignTokens::space16()));
    QVERIFY(search.width() < ordinary.width());
}

void MeoStyleGeometryTest::checkIndicatorMirrorsInRtl()
{
    MeoStyle style;
    QStyleOptionButton option;
    option.rect = QRect(0, 0, 180, 48);
    option.direction = Qt::LeftToRight;

    const QRect ltr = style.subElementRect(QStyle::SE_CheckBoxIndicator, &option);
    QCOMPARE(ltr.left(), qRound(Meo::DesignTokens::space4()));
    QCOMPARE(ltr.width(), qRound(Meo::DesignTokens::iconSizeS()));

    option.direction = Qt::RightToLeft;
    const QRect rtl = style.subElementRect(QStyle::SE_CheckBoxIndicator, &option);
    QCOMPARE(rtl.right(), option.rect.right() - qRound(Meo::DesignTokens::space4()));
    QCOMPARE(rtl.width(), ltr.width());
}

void MeoStyleGeometryTest::comboArrowAndContentMirrorInRtl()
{
    MeoStyle style;
    QStyleOptionComboBox option;
    option.rect = QRect(0, 0, 240, 48);
    option.direction = Qt::LeftToRight;

    const QRect ltrArrow = style.subControlRect(QStyle::CC_ComboBox, &option,
                                                QStyle::SC_ComboBoxArrow);
    const QRect ltrContent = style.subControlRect(QStyle::CC_ComboBox, &option,
                                                  QStyle::SC_ComboBoxEditField);
    QCOMPARE(ltrArrow.right(), option.rect.right());
    QCOMPARE(ltrArrow.width(), qRound(Meo::DesignTokens::controlHeight()));
    QVERIFY(ltrContent.right() < ltrArrow.left());

    option.direction = Qt::RightToLeft;
    const QRect rtlArrow = style.subControlRect(QStyle::CC_ComboBox, &option,
                                                QStyle::SC_ComboBoxArrow);
    const QRect rtlContent = style.subControlRect(QStyle::CC_ComboBox, &option,
                                                  QStyle::SC_ComboBoxEditField);
    QCOMPARE(rtlArrow.left(), option.rect.left());
    QCOMPARE(rtlArrow.width(), ltrArrow.width());
    QVERIFY(rtlContent.left() > rtlArrow.right());
}

void MeoStyleGeometryTest::splitToolButtonOwnsMenuRegion()
{
    MeoStyle style;
    QStyleOptionToolButton option;
    option.rect = QRect(0, 0, 160, 40);
    option.direction = Qt::LeftToRight;
    option.features = QStyleOptionToolButton::HasMenu | QStyleOptionToolButton::MenuButtonPopup;

    const QRect main = style.subControlRect(QStyle::CC_ToolButton, &option,
                                            QStyle::SC_ToolButton);
    const QRect menu = style.subControlRect(QStyle::CC_ToolButton, &option,
                                            QStyle::SC_ToolButtonMenu);
    QCOMPARE(menu.width(), qRound(Meo::DesignTokens::space32()));
    QCOMPARE(main.right() + 1, menu.left());
    QCOMPARE(menu.right(), option.rect.right());
}

void MeoStyleGeometryTest::sliderHandleUsesMeoTokenSize()
{
    MeoStyle style;
    QStyleOptionSlider option;
    option.rect = QRect(0, 0, 220, 40);
    option.orientation = Qt::Horizontal;
    option.minimum = 0;
    option.maximum = 100;
    option.sliderPosition = 50;

    const QRect groove = style.subControlRect(QStyle::CC_Slider, &option,
                                              QStyle::SC_SliderGroove);
    const QRect handle = style.subControlRect(QStyle::CC_Slider, &option,
                                              QStyle::SC_SliderHandle);
    const int tokenSize = qRound(Meo::DesignTokens::iconSizeS());

    QCOMPARE(handle.size(), QSize(tokenSize, tokenSize));
    QCOMPARE(groove.left(), option.rect.left() + tokenSize / 2);
    QCOMPARE(groove.right(), option.rect.right() - tokenSize / 2);
    QCOMPARE(handle.center().x(), option.rect.center().x());
}

QTEST_MAIN(MeoStyleGeometryTest)
#include "geometry-smoke.moc"
