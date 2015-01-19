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
#include <commonbackendmanagerinterface.h>
#include <contact.h>
#include <contactmodel.h>
#include <historymodel.h>
#include <legacyhistorybackend.h>
#include <transitionalcontactbackend.h>

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
    void connectSlots();
    void showAnswerBar();
    void hideAnswerBar();
    void transformAnswerBar();

private slots:
    void state_changed(Call* call, Call::State previousState);
    void incoming_call(Call* call);
    void on_call_button_clicked();
    void on_hangup_button_clicked();

    void on_answer_button_clicked();


    void on_decline_button_clicked();

private:
    Ui::MainWindow *ui;
    CallModel* callModel_{nullptr};
    Call* mainCall_{nullptr};
    Account* mainAccount_;
    LegacyHistoryBackend* backend_;
    QPoint clickPos_{QPoint(0,0)};
};

#endif // MAINWINDOW_H
