#import <AppKit/NSApplication.h> // NSApplicationMain
#import <qapplication.h>

int main(int argc, const char *argv[]) {
    
    //Qt event loop will override native event loop
    QApplication* app = new QApplication(argc, const_cast<char**>(argv));
    app->setAttribute(Qt::AA_MacPluginApplication);


    return NSApplicationMain(argc, argv);
}
