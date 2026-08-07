#include "meodecoration.h"
#include "meobutton.h"

#include <KConfigGroup>
#include <KSharedConfig>
#include <KColorScheme>
#include <KDecoration2/DecorationBridge>
#include <KDecoration2/DecorationSettings>
#include <QPainter>
#include <QPainterPath>
#include <QFontMetrics>
#include <QGuiApplication>

namespace MeoDecoration {

Decoration::Decoration(QObject *parent, const QVariantList &args)
    : KDecoration2::Decoration(parent, args)
{
}

Decoration::~Decoration() = default;

void Decoration::init()
{
    loadConfig();
    updateLayout();
    createButtons();
    updateShadow();

    connect(client().data(), &KDecoration2::DecoratedClient::activeChanged, this, [this]() {
        update();
    });
    connect(client().data(), &KDecoration2::DecoratedClient::captionChanged, this, [this]() {
        update();
    });
    connect(client().data(), &KDecoration2::DecoratedClient::maximizedChanged, this, [this]() {
        updateLayout();
        update();
    });
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
    int borderTop = isWindowMaximized() ? 0 : 0;
    int headerH = m_config.titleBarHeight;

    // Set titlebar metrics for KDecoration2
    setTitleBar(QRect(0, 0, size().width(), headerH));
    setBorders(QMargins(0, headerH, 0, 0));
}

void Decoration::createButtons()
{
    m_rightButtonGroup = new KDecoration2::DecorationButtonGroup(
        KDecoration2::DecorationButtonGroup::Position::Right,
        this,
        [this](KDecoration2::DecorationButtonType type, KDecoration2::Decoration *decoration, QObject *parent) {
            return new Button(type, static_cast<Decoration*>(decoration), parent);
        }
    );

    m_rightButtonGroup->setSpacing(m_config.buttonSpacing);
    
    // Window control buttons order: Minimize -> Maximize -> Close
    m_rightButtonGroup->addButton(KDecoration2::DecorationButtonType::Minimize);
    m_rightButtonGroup->addButton(KDecoration2::DecorationButtonType::Maximize);
    m_rightButtonGroup->addButton(KDecoration2::DecorationButtonType::Close);
}

void Decoration::updateShadow()
{
    if (isWindowMaximized()) {
        setShadow(nullptr);
        return;
    }

    if (!m_shadow) {
        m_shadow = std::make_shared<KDecoration2::DecorationShadow>();
    }

    int rad = m_config.shadowRadius;
    int offset = m_config.shadowOffsetY;
    m_shadow->setPadding(QMargins(rad, rad + offset, rad, rad - offset));
    
    setShadow(m_shadow);
}

bool Decoration::isWindowActive() const
{
    return client() ? client()->isActive() : true;
}

bool Decoration::isWindowMaximized() const
{
    return client() ? client()->isMaximized() : false;
}

QColor Decoration::titleBarBackgroundColor() const
{
    KColorScheme scheme(isWindowActive() ? QPalette::Active : QPalette::Inactive, KColorScheme::Header);
    QColor baseBg = scheme.background(KColorScheme::NormalBackground).color();
    QColor accent = scheme.foreground(KColorScheme::ActiveText).color();

    bool isDark = (baseBg.lightness() < 128);
    QColor targetBg = isDark ? QColor(33, 39, 46) : QColor(230, 236, 239);

    if (m_config.enableAccentTint && accent.isValid()) {
        // Dynamic Accent Color fusion: blend subtle accent tint into pastel base
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

void Decoration::paint(QPainter *painter, const QRect &repaintRegion)
{
    Q_UNUSED(repaintRegion);
    if (!painter) return;

    painter->save();
    painter->setRenderHint(QPainter::Antialiasing, true);

    const int w = size().width();
    const int headerH = m_config.titleBarHeight;
    const bool maxed = isWindowMaximized();
    const int rad = (maxed && m_config.squareMaximized) ? 0 : m_config.cornerRadius;

    QRectF titleBarRect(0, 0, w, headerH);

    // Render Titlebar Background with rounded top corners
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

    // Subtle bottom separator line
    QColor lineCol = isWindowActive() ? QColor(0, 0, 0, 18) : QColor(0, 0, 0, 10);
    painter->setPen(QPen(lineCol, 1.0));
    painter->drawLine(QPointF(0, headerH - 0.5), QPointF(w, headerH - 0.5));

    // Render Window Title Text
    if (client()) {
        QString caption = client()->caption();
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

DecorationFactory::DecorationFactory(QObject *parent)
    : KDecoration2::DecorationFactory(parent)
{
}

KDecoration2::Decoration *DecorationFactory::create(QObject *parent, const QVariantList &args)
{
    return new Decoration(parent, args);
}

} // namespace MeoDecoration

#include "meodecoration.moc"
