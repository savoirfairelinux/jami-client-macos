#include "mainwindow.h"
#include "ui_mainwindow.h"



MainWindow::MainWindow(QWidget *parent) :
    QMainWindow(parent),
    ui(new Ui::MainWindow)
{
    ui->setupUi(this);
    ui->contact_list->setModel(CallModel::instance());
    ui->contact_list->setModel(HistoryModel::instance());
    ui->contact_list->setModel(ContactModel::instance());
    //setWindowFlags(Qt::Window | Qt::FramelessWindowHint | Qt::CustomizeWindowHint | Qt::WindowMinimizeButtonHint);
    //setWindowFlags(Qt::Window | Qt::FramelessWindowHint | Qt::WindowMinimizeButtonHint | Qt::WindowMaximizeButtonHint | Qt::WindowCloseButtonHint);

    mainAccount_ = AccountModel::currentAccount();
    callModel_ = CallModel::instance();

    QObject::connect(callModel_, SIGNAL(callStateChanged(Call*, Call::State)),
        this, SLOT(on_state_changed(Call*, Call::State)));

    connect(&pollTimer_, SIGNAL(timeout()), this, SLOT(pollEvents()));
    pollTimer_.start(1000);
}

MainWindow::~MainWindow()
{
    if (mainCall_ != nullptr)
        mainCall_->performAction(Call::Action::REFUSE);
    delete mainAccount_;
    delete mainCall_;
    delete ui;
}


void MainWindow::mousePressEvent(QMouseEvent *e)
{
    clickPos_ = e->pos();
}

void MainWindow::mouseMoveEvent(QMouseEvent *e)
{
    qDebug() << clickPos_;
    move(e->globalPos() - clickPos_);
}




//// SLOTS ////

void MainWindow::on_call_button_clicked()
{
    mainCall_ = CallModel::instance()->dialingCall();
    mainCall_->setDialNumber(ui->call_number->text());
    mainCall_->performAction(Call::Action::ACCEPT);
}

void MainWindow::on_hangup_button_clicked()
{
    if (mainCall_)
        mainCall_->performAction(Call::Action::REFUSE);
}

void MainWindow::on_state_changed(Call *call, Call::State previousState)
{
    qDebug() << "on state changed!" << endl;
}

void MainWindow::pollEvents()
{
    qDebug() << "Poll Events?";
    AccountModel::currentAccount()->poll_events();
}

