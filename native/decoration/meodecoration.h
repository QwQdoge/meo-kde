#pragma once

#include <KDecoration2/Decoration>
#include <KDecoration2/DecorationButtonGroup>
#include <KDecoration2/DecorationSettings>
#include <KDecoration2/DecorationShadow>
#include <KColorScheme>
#include <QColor>
#include <memory>

namespace MeoDecoration {

struct ConfigSettings {
    int titleBarHeight = 36;
    int cornerRadius = 14;
    int buttonDiameter = 13;
    int buttonHitSize = 26;
    int buttonSpacing = 7;
    int buttonRightMargin = 14;
    bool showButtonBackground = true;
    double shadowIntensity = 0.25;
    int shadowRadius = 24;
    int shadowOffsetY = 4;
    bool alignTitleCenter = true;
    bool squareMaximized = true;
    bool enableAccentTint = true;
};

class Decoration : public KDecoration2::Decoration {
    Q_OBJECT
public:
    explicit Decoration(QObject *parent = nullptr, const QVariantList &args = QVariantList());
    ~Decoration() override;

    void init() override;
    void paint(QPainter *painter, const QRect &repaintRegion) override;

    const ConfigSettings &config() const { return m_config; }
    QColor titleBarBackgroundColor() const;
    QColor titleTextColor() const;

    bool isWindowActive() const;
    bool isWindowMaximized() const;

private:
    void loadConfig();
    void updateLayout();
    void updateShadow();
    void createButtons();

    ConfigSettings m_config;
    KDecoration2::DecorationButtonGroup *m_rightButtonGroup = nullptr;
    std::shared_ptr<KDecoration2::DecorationShadow> m_shadow;
};

class DecorationFactory : public KDecoration2::DecorationFactory {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID KDecoration2Factory_iid FILE "metadata.json")
    Q_INTERFACES(KDecoration2::DecorationFactory)
public:
    explicit DecorationFactory(QObject *parent = nullptr);
    KDecoration2::Decoration *create(QObject *parent, const QVariantList &args) override;
};

} // namespace MeoDecoration
