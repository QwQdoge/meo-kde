#include "meodecoration.h"
#include "meobutton.h"

#include <KConfigGroup>
#include <KSharedConfig>
#include <KColorScheme>
#include <KPluginFactory>
#include <KDecoration3/DecorationSettings>
#include <KDecoration3/DecoratedWindow>
#include <QPainter>
#include <QPainterPath>
#include <QFontMetrics>
#include <QGuiApplication>

namespace MeoDecoration {

K_PLUGIN_CLASS_WITH_JSON(Decoration, "metadata.json")

Decoration::Decoration(QObject *parent, const QVariantList &args)
    : KDecoration3::Decoration(parent, args)
{
}

Decoration::~Decoration() = default;

bool Decoration::init()
{
    loadConfig();
    createButtons();
    updateLayout();
    updateShadow();

    if (window()) {
        connect(window(), &KDecoration3::DecoratedWindow::activeChanged, this, [this]() {
            update();
        });
        connect(window(), &KDecoration3::DecoratedWindow::captionChanged, this, [this]() {
            update();
        });
        connect(window(), &KDecoration3::DecoratedWindow::maximizedChanged, this, [this]() {
            updateLayout();
            update();
        });
    }
    return true;
}

void Decoration::loadConfig()
{
    auto config = KSharedConfig::openConfig("kwinrc");
    KConfigGroup group(config, "org.meo.decoration");

    m_config.titleBarHeight = group.readEntry("TitleBarHeight", 36);
    m_config.cornerRadius = group.readEntry("CornerRadius", 14);
    m_config.buttonDiameter = group.readEntry("ButtonDiameter", 13);
    m_config.buttonHitSize = group.readEntry("ButtonHitSize", 26);
    m_config.buttonSpacing = group.readEntry("ButtonSpacing", 7);
    m_config.buttonRightMargin = group.readEntry("ButtonRightMargin", 14);
    m_config.showButtonBackground = group.readEntry("ShowButtonBackground", true);
    m_config.shadowIntensity = group.readEntry("ShadowIntensity", 0.25);
    m_config.shadowRadius = group.readEntry("ShadowRadius", 24);
    m_config.shadowOffsetY = group.readEntry("ShadowOffsetY", 4);
    m_config.alignTitleCenter = group.readEntry("AlignTitleCenter", true);
    m_config.squareMaximized = group.readEntry("SquareMaximized", true);
    m_config.enableAccentTint = group.readEntry("EnableAccentTint", true);
}

void Decoration::updateLayout()
{
    const int headerH = m_config.titleBarHeight;
    const int w = size().width();

    setTitleBar(QRectF(0, 0, w, headerH));
    setBorders(QMarginsF(0, headerH, 0, 0));

    if (m_rightButtonGroup) {
        qreal groupW = m_rightButtonGroup->geometry().width();
        qreal groupH = m_rightButtonGroup->geometry().height();
        qreal x = w - groupW - m_config.buttonRightMargin;
        qreal y = (headerH - groupH) / 2.0;
        m_rightButtonGroup->setPos(QPointF(x, qMax(0.0, y)));
    }
}

void Decoration::createButtons()
{
    m_rightButtonGroup = new KDecoration3::DecorationButtonGroup(
        KDecoration3::DecorationButtonGroup::Position::Right,
        this,
        [this](KDecoration3::DecorationButtonType type, KDecoration3::Decoration *decoration, QObject *parent) {
            return new Button(type, static_cast<Decoration*>(decoration), parent);
        }
    );

    m_rightButtonGroup->setSpacing(m_config.buttonSpacing);
}

bool Decoration::isRightGroupHovered() const
{
    if (!m_rightButtonGroup) return false;
    for (auto *btn : m_rightButtonGroup->buttons()) {
        if (btn->isHovered()) return true;
    }
    return false;
}

void Decoration::updateGroupHoverState()
{
    bool groupHovered = isRightGroupHovered();
    if (!m_rightButtonGroup) return;
    for (auto *btn : m_rightButtonGroup->buttons()) {
        if (auto *meoBtn = qobject_cast<Button*>(btn)) {
            meoBtn->setGroupHovered(groupHovered);
        }
    }
}

void Decoration::updateShadow()
{
    if (isWindowMaximized()) {
        setShadow(nullptr);
        return;
    }

    if (!m_shadow) {
        m_shadow = std::make_shared<KDecoration3::DecorationShadow>();
    }

    int rad = m_config.shadowRadius;
    int offset = m_config.shadowOffsetY;
    m_shadow->setPadding(QMargins(rad, rad + offset, rad, rad - offset));
    
    setShadow(m_shadow);
}

bool Decoration::isWindowActive() const
{
    return window() ? window()->isActive() : true;
}

bool Decoration::isWindowMaximized() const
{
    return window() ? window()->isMaximized() : false;
}

QColor Decoration::titleBarBackgroundColor() const
{
    KColorScheme scheme(isWindowActive() ? QPalette::Active : QPalette::Inactive, KColorScheme::Header);
    QColor baseBg = scheme.background(KColorScheme::NormalBackground).color();
    QColor accent = scheme.foreground(KColorScheme::ActiveText).color();

    bool isDark = (baseBg.lightness() < 128);
    QColor targetBg = isDark ? QColor(33, 39, 46) : QColor(230, 236, 239);

    if (m_config.enableAccentTint && accent.isValid()) {
        qreal alpha = isDark ? 0.12 : 0.08;
        targetBg.setRedF(targetBg.redF() * (1.0 - alpha) + accent.redF() * alpha);
        targetBg.setGreenF(targetBg.greenF() * (1.0 - alpha) + accent.greenF() * alpha);
        targetBg.setBlueF(targetBg.blueF() * (1.0 - alpha) + accent.blueF() * alpha);
    }

    if (!isWindowActive()) {
        targetBg.setAlphaF(0.85);
    }

    return targetBg;
}

QColor Decoration::titleTextColor() const
{
    KColorScheme scheme(isWindowActive() ? QPalette::Active : QPalette::Inactive, KColorScheme::Header);
    QColor txtColor = scheme.foreground(KColorScheme::NormalText).color();
    if (!isWindowActive()) {
        txtColor.setAlpha(160);
    }
    return txtColor;
}

void Decoration::paint(QPainter *painter, const QRectF &repaintRegion)
{
    Q_UNUSED(repaintRegion);
    if (!painter) return;

    painter->save();
    painter->setRenderHint(QPainter::Antialiasing, true);

    const qreal w = size().width();
    const qreal headerH = m_config.titleBarHeight;
    const bool maxed = isWindowMaximized();
    const int rad = (maxed && m_config.squareMaximized) ? 0 : m_config.cornerRadius;

    QRectF titleBarRect(0, 0, w, headerH);

    QPainterPath path;
    if (rad > 0) {
        path.moveTo(0, headerH);
        path.lineTo(0, rad);
        path.quadTo(0, 0, rad, 0);
        path.lineTo(w - rad, 0);
        path.quadTo(w, 0, w, rad);
        path.lineTo(w, headerH);
        path.closeSubpath();
    } else {
        path.addRect(titleBarRect);
    }

    painter->setPen(Qt::NoPen);
    painter->setBrush(titleBarBackgroundColor());
    painter->drawPath(path);

    QColor lineCol = isWindowActive() ? QColor(0, 0, 0, 18) : QColor(0, 0, 0, 10);
    painter->setPen(QPen(lineCol, 1.0));
    painter->drawLine(QPointF(0, headerH - 0.5), QPointF(w, headerH - 0.5));

    if (window()) {
        QString caption = window()->caption();
        if (!caption.isEmpty()) {
            painter->setPen(titleTextColor());
            QFont titleFont = QGuiApplication::font();
            titleFont.setPixelSize(13);
            titleFont.setWeight(QFont::Medium);
            painter->setFont(titleFont);

            QFontMetrics fm(titleFont);
            int rightOffset = m_config.buttonRightMargin + (3 * m_config.buttonHitSize) + (2 * m_config.buttonSpacing) + 12;
            int leftMargin = 16;
            int availableWidth = w - leftMargin - rightOffset;

            if (availableWidth > 40) {
                QString elidedCaption = fm.elidedText(caption, Qt::ElideRight, availableWidth);
                QRect textRect(leftMargin, 0, availableWidth, headerH);
                Qt::Alignment align = m_config.alignTitleCenter ? Qt::AlignCenter : (Qt::AlignLeft | Qt::AlignVCenter);
                painter->drawText(textRect, align, elidedCaption);
            }
        }
    }

    painter->restore();
}

} // namespace MeoDecoration

#include "meodecoration.moc"
