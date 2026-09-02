#include <QtWidgets/QApplication>
#include <QtWidgets/QCheckBox>
#include <QtWidgets/QComboBox>
#include <QtWidgets/QFormLayout>
#include <QtWidgets/QHBoxLayout>
#include <QtWidgets/QLabel>
#include <QtWidgets/QLineEdit>
#include <QtWidgets/QMainWindow>
#include <QtWidgets/QMenu>
#include <QtWidgets/QMenuBar>
#include <QtWidgets/QPlainTextEdit>
#include <QtWidgets/QProgressBar>
#include <QtWidgets/QPushButton>
#include <QtWidgets/QRadioButton>
#include <QtWidgets/QScrollBar>
#include <QtWidgets/QSlider>
#include <QtWidgets/QTabWidget>
#include <QtWidgets/QTableWidget>
#include <QtWidgets/QToolButton>
#include <QtWidgets/QToolBar>
#include <QtWidgets/QTreeWidget>
#include <QtWidgets/QVBoxLayout>

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    QMainWindow window;
    window.setWindowTitle(QStringLiteral("Meo Application Style Gallery"));
    auto *tools = window.addToolBar(QStringLiteral("Actions"));
    tools->addAction(QStringLiteral("New"));
    tools->addAction(QStringLiteral("Open"));
    window.menuBar()->addMenu(QStringLiteral("File"))->addAction(QStringLiteral("Quit"), &app, &QApplication::quit);

    auto *central = new QWidget;
    auto *layout = new QVBoxLayout(central);
    auto *heading = new QLabel(QStringLiteral("Pixel controls"));
    QFont headingFont = heading->font();
    headingFont.setBold(true);
    headingFont.setPointSizeF(headingFont.pointSizeF() * 1.35);
    heading->setFont(headingFont);
    layout->addWidget(heading);
    auto *controls = new QWidget;
    auto *form = new QFormLayout(controls);
    auto *primaryAction = new QPushButton(QStringLiteral("Primary action"));
    primaryAction->setDefault(true);
    primaryAction->setProperty("meo.variant", "filled");
    auto *secondaryAction = new QPushButton(QStringLiteral("Secondary action"));
    secondaryAction->setProperty("meo.variant", "tonal");
    auto *textAction = new QPushButton(QStringLiteral("Text action"));
    textAction->setFlat(true);
    textAction->setProperty("meo.variant", "text");
    auto *actionRow = new QWidget;
    auto *actionLayout = new QHBoxLayout(actionRow);
    actionLayout->setContentsMargins(0, 0, 0, 0);
    actionLayout->addWidget(primaryAction);
    actionLayout->addWidget(secondaryAction);
    actionLayout->addWidget(textAction);
    actionLayout->addStretch();
    form->addRow(QStringLiteral("Actions"), actionRow);
    auto *checkBox = new QCheckBox(QStringLiteral("Checkbox"));
    checkBox->setCheckState(Qt::Checked);
    form->addRow(checkBox);
    auto *partialCheckBox = new QCheckBox(QStringLiteral("Indeterminate checkbox"));
    partialCheckBox->setTristate(true);
    partialCheckBox->setCheckState(Qt::PartiallyChecked);
    form->addRow(partialCheckBox);
    auto *radioButton = new QRadioButton(QStringLiteral("Radio button"));
    radioButton->setChecked(true);
    form->addRow(radioButton);
    form->addRow(QStringLiteral("Text field"), new QLineEdit(QStringLiteral("Meo")));
    auto *searchField = new QLineEdit;
    searchField->setProperty("meo.role", "search");
    searchField->setPlaceholderText(QStringLiteral("Search applications"));
    searchField->setClearButtonEnabled(true);
    searchField->addAction(QIcon::fromTheme(QStringLiteral("edit-find")), QLineEdit::LeadingPosition);
    form->addRow(QStringLiteral("Search field"), searchField);
    auto *toolButton = new QToolButton;
    toolButton->setText(QStringLiteral("Options"));
    toolButton->setAutoRaise(true);
    toolButton->setCheckable(true);
    toolButton->setChecked(true);
    toolButton->setPopupMode(QToolButton::MenuButtonPopup);
    auto *toolMenu = new QMenu(toolButton);
    toolMenu->addAction(QStringLiteral("Refresh"));
    toolButton->setMenu(toolMenu);
    form->addRow(QStringLiteral("Tool button"), toolButton);
    auto *combo = new QComboBox;
    combo->addItems({QStringLiteral("Light"), QStringLiteral("Dark"), QStringLiteral("System")});
    form->addRow(QStringLiteral("Combo box"), combo);
    auto *slider = new QSlider(Qt::Horizontal);
    slider->setValue(55);
    form->addRow(QStringLiteral("Slider"), slider);
    auto *progress = new QProgressBar;
    progress->setValue(62);
    form->addRow(QStringLiteral("Progress"), progress);
    layout->addWidget(controls);

    auto *tabs = new QTabWidget;
    auto *table = new QTableWidget(3, 2);
    table->setHorizontalHeaderLabels({QStringLiteral("Name"), QStringLiteral("State")});
    table->setItem(0, 0, new QTableWidgetItem(QStringLiteral("Dolphin")));
    table->setItem(0, 1, new QTableWidgetItem(QStringLiteral("Ready")));
    table->setItem(1, 0, new QTableWidgetItem(QStringLiteral("Kate")));
    table->setItem(1, 1, new QTableWidgetItem(QStringLiteral("Selected")));
    table->setCurrentCell(1, 0);
    tabs->addTab(table, QStringLiteral("Table"));
    auto *tree = new QTreeWidget;
    tree->setHeaderLabels({QStringLiteral("Tree"), QStringLiteral("Value")});
    auto *treeItem = new QTreeWidgetItem({QStringLiteral("Meo"), QStringLiteral("Style") });
    tree->addTopLevelItem(treeItem);
    tree->setCurrentItem(treeItem);
    tabs->addTab(tree, QStringLiteral("Tree"));
    layout->addWidget(tabs);
    window.setCentralWidget(central);
    window.resize(760, 620);
    window.show();
    return app.exec();
}
