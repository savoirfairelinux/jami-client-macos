#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QString>
#include <QDebug>
#include <QMainWindow>
#include <QTimer>
#include <QMouseEvent>

#include <memory>

#include <account.h>
#include <accountmodel.h>
#include <call.h>
#include <callmodel.h>
#include <contactmodel.h>
#include <historymodel.h>

namespace Ui {
class MainWindow;
}

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    explicit MainWindow(QWidget *parent = 0);
    ~MainWindow();

protected:
    void mousePressEvent(QMouseEvent *);
    void mouseMoveEvent(QMouseEvent *);

private:


private slots:
    void on_call_button_clicked();
    void on_state_changed(Call* call, Call::State previousState);
    void on_hangup_button_clicked();
    void pollEvents();

private:
    Ui::MainWindow *ui;
    CallModel* callModel_{nullptr};
    Call* mainCall_{nullptr};
    Account* mainAccount_;
    QString savedNumber_;
    QTimer pollTimer_;
    QPoint clickPos_{QPoint(0,0)};
};

#endif // MAINWINDOW_H
