#include "meodecoration.h"
#include "meobutton.h"
#include "meoboxshadowrenderer.h"

#include <KConfigGroup>
#include <KSharedConfig>
#include <KColorScheme>
#include <KPluginFactory>
#include <KDecoration3/DecorationSettings>
#include <KDecoration3/DecoratedWindow>
#include <KDecoration3/ScaleHelpers>
#include <QPainter>
#include <QPainterPath>
#include <QFontMetrics>
#include <QGuiApplication>
#include <QImage>
#include <QVariantAnimation>
#include <QtMath>

namespace MeoDecoration {

namespace {

int scaledAnimationDuration(int duration, qreal factor)
{
    return qBound(0, qRound(duration * factor), 4000);
}

} // namespace

K_PLUGIN_CLASS_WITH_JSON(Decoration, "metadata.json")

Decoration::Decoration(QObject *parent, const QVariantList &args)
    : KDecoration3::Decoration(parent, args)
{
}

Decoration::~Decoration() = default;

bool Decoration::init()
{
    loadConfig();
    m_focusProgress = isWindowActive() ? 1.0 : 0.0;
    m_focusAnimation = new QVariantAnimation(this);
    m_focusAnimation->setDuration(m_config.focusTransitionDuration);
    m_focusAnimation->setEasingCurve(QEasingCurve::OutCubic);
    connect(m_focusAnimation, &QVariantAnimation::valueChanged, this, [this](const QVariant &value) {
        m_focusProgress = value.toReal();
        update();
    });
    createButtons();
    updateLayout();
    updateShadow();

    if (const auto decorationSettings = settings()) {
        connect(decorationSettings.get(), &KDecoration3::DecorationSettings::fontChanged, this, [this]() {
            loadConfig();
            updateLayout();
            update();
        });
    }

    if (window()) {
        connect(window(), &KDecoration3::DecoratedWindow::activeChanged, this, [this]() {
            updateFocusAnimation(window()->isActive());
        });
        connect(window(), &KDecoration3::DecoratedWindow::captionChanged, this, [this]() {
            update();
        });
        connect(window(), &KDecoration3::DecoratedWindow::maximizedChanged, this, [this]() {
            updateLayout();
            updateShadow();
            update();
        });
        connect(window(), &KDecoration3::DecoratedWindow::sizeChanged, this, [this]() {
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

    // 32 logical pixels matches Breeze and Chrome's system titlebar. A tall
    // system font may raise the computed height, but never past 34px.
    const int requestedTitlebarHeight = group.readEntry("TitleBarHeight", 32);
    const QFont titleFont = settings() ? settings()->font() : QGuiApplication::font();
    const int minimumForFont = QFontMetrics(titleFont).height() + 8;
    m_config.titleBarHeight = qBound(30, qMax(requestedTitlebarHeight, minimumForFont), 34);
    m_config.cornerRadius = qBound(0, group.readEntry("CornerRadius", 16), 48);
    m_config.buttonDiameter = qBound(16, group.readEntry("ButtonDiameter", 24), 32);
    m_config.buttonHitSize = qBound(26, group.readEntry("ButtonHitSize", 32), 40);
    m_config.buttonSpacing = qBound(0, group.readEntry("ButtonSpacing", 2), 24);
    m_config.buttonRightMargin = qBound(0, group.readEntry("ButtonRightMargin", 6), 48);
    m_config.showButtonBackground = group.readEntry("ShowButtonBackground", true);
    m_config.shadowIntensity = qBound(0.0, group.readEntry("ShadowIntensity", 0.18), 1.0);
    m_config.shadowRadius = qBound(0, group.readEntry("ShadowRadius", 28), 64);
    m_config.shadowOffsetY = qBound(-m_config.shadowRadius, group.readEntry("ShadowOffsetY", 6), m_config.shadowRadius);
    const KConfigGroup animationGroup(KSharedConfig::openConfig("kdeglobals"), "KDE");
    const qreal animationFactor = qBound<qreal>(0.0,
        animationGroup.readEntry("AnimationDurationFactor", 1.0), 10.0);
    m_config.hoverInDuration = scaledAnimationDuration(
        qBound(0, group.readEntry("HoverInDuration", 100), 300), animationFactor);
    m_config.hoverOutDuration = scaledAnimationDuration(
        qBound(0, group.readEntry("HoverOutDuration", 80), 300), animationFactor);
    m_config.focusTransitionDuration = scaledAnimationDuration(
        qBound(0, group.readEntry("FocusTransitionDuration", 180), 400), animationFactor);
    m_config.rippleDuration = scaledAnimationDuration(180, animationFactor);
    m_config.alignTitleCenter = group.readEntry("AlignTitleCenter", true);
    m_config.squareMaximized = group.readEntry("SquareMaximized", true);
    m_config.enableAccentTint = group.readEntry("EnableAccentTint", false);
}

void Decoration::updateLayout()
{
    const qreal headerH = KDecoration3::snapToPixelGrid(m_config.titleBarHeight, window()->nextScale());
    const int w = size().width();

    setTitleBar(QRectF(0, 0, w, headerH));
    // The titlebar is the only visual decoration border. Side and bottom
    // resize affordances must not widen the visual frame; otherwise the
    // titlebar is wider than the client window by the resize-border width.
    setBorders(QMarginsF(0, headerH, 0, 0));
    constexpr qreal frameBorder = 3.0;
    setResizeOnlyBorders(QMarginsF(frameBorder, 0, frameBorder, frameBorder));
    const int radius = (isWindowMaximized() && m_config.squareMaximized)
        ? 0
        : m_config.cornerRadius;
    setBorderRadius(KDecoration3::BorderRadius(radius));

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
    // Use KDecoration3's right-group constructor. It performs the native
    // button layout/geometry initialization; a manually assembled group can
    // exist but never receive a usable geometry after a KWin restart.
    m_rightButtonGroup = new KDecoration3::DecorationButtonGroup(
        KDecoration3::DecorationButtonGroup::Position::Right,
        this,
        [](KDecoration3::DecorationButtonType type, KDecoration3::Decoration *decoration, QObject *parent) {
            return new Button(type, static_cast<Decoration *>(decoration), parent);
        });

    const auto buttons = m_rightButtonGroup->buttons();
    for (auto *button : buttons) {
        const auto type = button->type();
        if (type != KDecoration3::DecorationButtonType::Minimize
            && type != KDecoration3::DecorationButtonType::Maximize
            && type != KDecoration3::DecorationButtonType::Close) {
            m_rightButtonGroup->removeButton(type);
        }
    }

    // Keep the window controls independent of users' historical button-order
    // settings, which can omit one or more of these standard actions.
    for (const auto type : {KDecoration3::DecorationButtonType::Minimize,
                            KDecoration3::DecorationButtonType::Maximize,
                            KDecoration3::DecorationButtonType::Close}) {
        if (!m_rightButtonGroup->hasButton(type)) {
            m_rightButtonGroup->addButton(new Button(type, this, m_rightButtonGroup));
        }
    }
    m_rightButtonGroup->setSpacing(m_config.buttonSpacing);
}

void Decoration::updateShadow()
{
    if (isWindowMaximized()) {
        setShadow(nullptr);
        return;
    }

    // Ported from Breeze 6.7.4's KDecoration3 path. The texture, padding,
    // central hole and radius all derive from this one box geometry.
    const int blurRadius = m_config.shadowRadius;
    const QPoint shadowOffset(0, m_config.shadowOffsetY);
    constexpr qreal shadowOverlap = 3.0;
    const QSize boxSize = Breeze::BoxShadowRenderer::calculateMinimumBoxSize(blurRadius);
    const qreal cornerRadius = KDecoration3::snapToPixelGrid(m_config.cornerRadius, window()->nextScale());

    Breeze::BoxShadowRenderer renderer;
    renderer.setBoxSize(boxSize);
    renderer.setBorderRadius(cornerRadius + 0.5);
    QColor shadowColor = Qt::black;
    shadowColor.setAlphaF(m_config.shadowIntensity);
    // The texture's shadow is centered. Its global displacement is encoded
    // exactly once below in DecorationShadow padding, as in Breeze's
    // CompositeShadowParams pipeline. Passing shadowOffset here as well
    // displaced the hole twice and caused the visible transparent seam.
    renderer.addShadow(QPointF(), blurRadius, shadowColor);
    QImage texture = renderer.render();

    const QRectF outerRect = texture.rect();
    QRectF boxRect(QPointF(0, 0), boxSize);
    boxRect.moveCenter(outerRect.center());
    const QMarginsF padding(boxRect.left() - outerRect.left() - shadowOverlap - shadowOffset.x(),
                            boxRect.top() - outerRect.top() - shadowOverlap - shadowOffset.y(),
                            outerRect.right() - boxRect.right() - shadowOverlap + shadowOffset.x(),
                            outerRect.bottom() - boxRect.bottom() - shadowOverlap + shadowOffset.y());
    QRectF innerRect = outerRect - padding;
    // This is the same fractional-scaling correction used upstream. It is
    // deliberately applied to both the hole and the matching corner radius.
    innerRect.adjust(2, 2, -2, -2);

    QPainter painter(&texture);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setCompositionMode(QPainter::CompositionMode_DestinationOut);
    painter.setPen(Qt::NoPen);
    painter.setBrush(Qt::black);
    painter.drawRoundedRect(innerRect, cornerRadius + 0.5, cornerRadius + 0.5);
    painter.end();

    m_shadow = std::make_shared<KDecoration3::DecorationShadow>();
    m_shadow->setPadding(padding);
    m_shadow->setInnerShadowRect(QRectF(outerRect.center(), QSizeF(1, 1)));
    m_shadow->setShadow(texture);
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

qreal Decoration::captionIconOpacity() const
{
    return 0.38 + (0.42 * m_focusProgress);
}

qreal Decoration::captionTitleOpacity() const
{
    return 0.60 + (0.40 * m_focusProgress);
}

void Decoration::updateFocusAnimation(bool active)
{
    m_focusAnimation->stop();
    if (m_config.focusTransitionDuration <= 0) {
        m_focusProgress = active ? 1.0 : 0.0;
        update();
        return;
    }
    m_focusAnimation->setDuration(m_config.focusTransitionDuration);
    m_focusAnimation->setStartValue(m_focusProgress);
    m_focusAnimation->setEndValue(active ? 1.0 : 0.0);
    m_focusAnimation->start();
}

QColor Decoration::titleBarBackgroundColor() const
{
    KColorScheme scheme(isWindowActive() ? QPalette::Active : QPalette::Inactive, KColorScheme::Header);
    // `meo-dynamic-colors` writes the complete Material role set into KDE's
    // active color scheme. Using the Header role directly keeps the native
    // decoration in that same MD3 palette instead of applying a second,
    // hand-mixed accent tint on top of it.
    return scheme.background(KColorScheme::NormalBackground).color();
}

QColor Decoration::titleTextColor() const
{
    KColorScheme scheme(isWindowActive() ? QPalette::Active : QPalette::Inactive, KColorScheme::Header);
    QColor txtColor = scheme.foreground(KColorScheme::NormalText).color();
    return txtColor;
}

void Decoration::paint(QPainter *painter, const QRectF &repaintRegion)
{
    Q_UNUSED(repaintRegion);
    if (!painter) return;

    painter->save();
    painter->setRenderHint(QPainter::Antialiasing, true);

    const qreal w = size().width();
    const QRectF titleBarRect = titleBar();
    const qreal headerH = titleBarRect.height();
    const bool maxed = isWindowMaximized();
    const int rad = (maxed && m_config.squareMaximized) ? 0 : m_config.cornerRadius;

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

    if (m_rightButtonGroup) {
        m_rightButtonGroup->paint(painter, repaintRegion);
    }

    QColor lineCol = titleTextColor();
    lineCol.setAlphaF(0.07 * captionTitleOpacity());
    painter->setPen(QPen(lineCol, 1.0));
    painter->drawLine(QPointF(0, headerH - 0.5), QPointF(w, headerH - 0.5));

    if (window()) {
        QString caption = window()->caption();
        if (!caption.isEmpty()) {
            QColor captionColor = titleTextColor();
            captionColor.setAlphaF(captionTitleOpacity());
            painter->setPen(captionColor);
            const QFont titleFont = settings() ? settings()->font() : QGuiApplication::font();
            painter->setFont(titleFont);

            QFontMetrics fm(titleFont);
            const int groupWidth = m_rightButtonGroup
                ? qCeil(m_rightButtonGroup->geometry().width())
                : 0;
            const int rightOffset = m_config.buttonRightMargin + groupWidth + 12;
            int leftMargin = 16;
            const int horizontalReserve = m_config.alignTitleCenter
                ? qMax(leftMargin, rightOffset)
                : leftMargin;
            int availableWidth = w - horizontalReserve - (m_config.alignTitleCenter ? horizontalReserve : rightOffset);

            if (availableWidth > 40) {
                QString elidedCaption = fm.elidedText(caption, Qt::ElideRight, availableWidth);
                QRect textRect(horizontalReserve, 0, availableWidth, headerH);
                Qt::Alignment align = m_config.alignTitleCenter ? Qt::AlignCenter : (Qt::AlignLeft | Qt::AlignVCenter);
                painter->drawText(textRect, align, elidedCaption);
            }
        }
    }

    painter->restore();
}

} // namespace MeoDecoration

#include "meodecoration.moc"
