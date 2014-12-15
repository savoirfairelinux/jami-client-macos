#include "mainwindow.h"
#include "ui_mainwindow.h"



MainWindow::MainWindow(QWidget *parent) :
    QMainWindow(parent),
    ui(new Ui::MainWindow)
{
    ui->setupUi(this);

    mainAccount_ = AccountModel::currentAccount();
    callModel_ = CallModel::instance();

    QObject::connect(callModel_, SIGNAL(callStateChanged(Call*, Call::State)),
        this, SLOT(on_state_changed(Call*, Call::State)));

    connect(&pollTimer_, SIGNAL(timeout()), this, SLOT(pollEvents()));
    pollTimer_.start(1000);
}

MainWindow::~MainWindow()
{
    delete ui;
}



//// SLOTS ////

void MainWindow::on_pushButton_clicked()
{
    mainCall_ = CallModel::instance()->dialingCall();
    mainCall_->setDialNumber(ui->call_number->text());
    mainCall_->performAction(Call::Action::ACCEPT);
}

void MainWindow::on_state_changed(Call *call, Call::State previousState)
{
    qDebug() << "on state changed!" << endl;
}

