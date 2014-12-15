#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QString>
#include <QDebug>
#include <QMainWindow>
#include <QTimer>

#include <memory>

#include <account.h>
#include <accountmodel.h>
#include <call.h>
#include <callmodel.h>

namespace Ui {
class MainWindow;
}

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    explicit MainWindow(QWidget *parent = 0);
    ~MainWindow();

private slots:
    void on_pushButton_clicked();
    void on_state_changed(Call* call, Call::State previousState);

private slots:
    void pollEvents() {
        qDebug() << "Poll Events?";
        AccountModel::currentAccount()->poll_events();
    }

private:
    Ui::MainWindow *ui;
    CallModel* callModel_;
    Call* mainCall_;
    Account* mainAccount_;
    QString savedNumber_;

    QTimer pollTimer_;
};

#endif // MAINWINDOW_H
