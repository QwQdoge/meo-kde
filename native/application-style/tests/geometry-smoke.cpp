#include "meostyle.h"

#include <QtTest/QTest>
#include <QtWidgets/QApplication>
#include <QtWidgets/QStyleOptionButton>
#include <QtWidgets/QStyleOptionComboBox>
#include <QtWidgets/QStyleOptionFrame>
#include <QtWidgets/QStyleOptionSlider>
#include <QtWidgets/QStyleOptionToolButton>
#include <QtWidgets/QWidget>

#include <meodesigntokens.h>

class MeoStyleGeometryTest final : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void pushButtonContentUsesMeoInsets();
    void sizeHintsReserveContentAndMenuInsets();
    void searchFieldGetsWiderContentInset();
    void checkIndicatorMirrorsInRtl();
    void comboArrowAndContentMirrorInRtl();
    void splitToolButtonOwnsMenuRegion();
    void sliderHandleUsesMeoTokenSize();
};

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
