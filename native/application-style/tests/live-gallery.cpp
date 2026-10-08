// Opt-in real-display capture of the production gallery; not an offscreen CTest.
#include <QTimer>
#include <cstdio>
#include <QApplication>
#include <QMenu>
#include <QMenuBar>
#include <QJsonDocument>
#include <QJsonObject>
#include <QFile>
#include <QStyle>
#include <QPushButton>
#include <QStyleOptionButton>
static void capture() {
 QTimer::singleShot(1500, qApp, [] {
  QWidget *window=nullptr;
  for(auto *w: QApplication::topLevelWidgets()) if(w->isVisible() && w->windowTitle()=="Meo Application Style Gallery") window=w;
  if(!window) {qApp->exit(2); return;}
  for(auto *b:window->findChildren<QPushButton*>()) {
   QStyleOptionButton opt;opt.initFrom(b);opt.rect=b->rect();opt.text=b->text();
   std::printf("button %s width=%d text=%d contents=%d\n",qPrintable(b->text()),b->width(),b->fontMetrics().horizontalAdvance(b->text()),b->style()->subElementRect(QStyle::SE_PushButtonContents,&opt,b).width());
  }
  QString prefix=qEnvironmentVariable("MEO_CAPTURE_PREFIX");
  bool ok=window->grab().save(prefix+".png");
  if(!ok) {qApp->exit(2);return;}
  QFile f(prefix+".json");if(!f.open(QIODevice::WriteOnly)) {qApp->exit(2);return;}f.write(QJsonDocument(QJsonObject{{"style",qApp->style()->objectName()},{"platform",QGuiApplication::platformName()},{"dpr",window->devicePixelRatioF()},{"saved",ok}}).toJson());f.close();
  if(auto *bar=window->findChild<QMenuBar*>()) {
   auto *menu=bar->actions().first()->menu();menu->popup(window->mapToGlobal(QPoint(10,30)));
   QTimer::singleShot(300,qApp,[menu,prefix]{qApp->exit(menu->grab().save(prefix+"-menu.png") ? 0 : 2);});
  } else qApp->quit();
 });
}
Q_COREAPP_STARTUP_FUNCTION(capture)
#define main gallery_main
#include "../gallery/main.cpp"
#undef main
int main(int argc,char **argv) {
 if(qEnvironmentVariableIsEmpty("MEO_CAPTURE_PREFIX")) {
  std::fputs("Set MEO_CAPTURE_PREFIX to an explicit output path.\n",stderr);
  return 2;
 }
 return gallery_main(argc,argv);
}
