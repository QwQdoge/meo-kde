#include <QtWidgets/QApplication>
#include <QtWidgets/QCheckBox>
#include <QtWidgets/QComboBox>
#include <QtWidgets/QFormLayout>
#include <QtWidgets/QGroupBox>
#include <QtWidgets/QLineEdit>
#include <QtWidgets/QMainWindow>
#include <QtWidgets/QMenuBar>
#include <QtWidgets/QPlainTextEdit>
#include <QtWidgets/QProgressBar>
#include <QtWidgets/QPushButton>
#include <QtWidgets/QRadioButton>
#include <QtWidgets/QScrollBar>
#include <QtWidgets/QSlider>
#include <QtWidgets/QTabWidget>
#include <QtWidgets/QTableWidget>
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
    auto *controls = new QGroupBox(QStringLiteral("Core controls"));
    auto *form = new QFormLayout(controls);
    form->addRow(new QPushButton(QStringLiteral("Primary action")));
    form->addRow(new QCheckBox(QStringLiteral("Checkbox")));
    form->addRow(new QRadioButton(QStringLiteral("Radio button")));
    form->addRow(QStringLiteral("Text field"), new QLineEdit(QStringLiteral("Meo")));
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
    tabs->addTab(table, QStringLiteral("Table"));
    auto *tree = new QTreeWidget;
    tree->setHeaderLabels({QStringLiteral("Tree"), QStringLiteral("Value")});
    tree->addTopLevelItem(new QTreeWidgetItem({QStringLiteral("Meo"), QStringLiteral("Style") }));
    tabs->addTab(tree, QStringLiteral("Tree"));
    layout->addWidget(tabs);
    window.setCentralWidget(central);
    window.resize(760, 620);
    window.show();
    return app.exec();
}
