#include "mainwindow.h"
#include "ui_mainwindow.h"



MainWindow::MainWindow(QWidget *parent) :
    QMainWindow(parent),
    ui(new Ui::MainWindow)
{
    ui->setupUi(this);
    ui->contact_list->setAttribute(Qt::WA_MacShowFocusRect, false);

    //setWindowFlags(Qt::Window | Qt::FramelessWindowHint | Qt::CustomizeWindowHint | Qt::WindowMinimizeButtonHint);
    //setWindowFlags(Qt::Window | Qt::FramelessWindowHint | Qt::WindowMinimizeButtonHint | Qt::WindowMaximizeButtonHint | Qt::WindowCloseButtonHint);

    mainAccount_ = AccountModel::currentAccount();
    callModel_ = CallModel::instance();
    HistoryModel::instance()->addBackend(new LegacyHistoryBackend(this), LoadOptions::FORCE_ENABLED);
    connectSlots();

    //ui->contact_list->setModel(CallModel::instance());
    ui->contact_list->setModel(HistoryModel::instance());
//    ui->contact_list->setModel(ContactModel::instance());
}

MainWindow::~MainWindow()
{
    if (mainCall_ != nullptr) {
        mainCall_->performAction(Call::Action::REFUSE);
        delete mainCall_;
    }
    if (mainAccount_) {
        delete mainAccount_;
    }
    if (callModel_) {
        //delete callModel_;
    }

    delete ui;
}



//// PROTECTED ////

void MainWindow::mousePressEvent(QMouseEvent *e)
{
    clickPos_ = e->pos();
}

void MainWindow::mouseMoveEvent(QMouseEvent *e)
{
    qDebug() << clickPos_;
    move(e->globalPos() - clickPos_);
}



//// PRIVATE ////

void MainWindow::connectSlots()
{
    QObject::connect(callModel_, SIGNAL(callStateChanged(Call*, Call::State)),
        this, SLOT(state_changed(Call*, Call::State)));

    QObject::connect(callModel_, SIGNAL(incomingCall(Call*)),
        this, SLOT(incoming_call(Call*)));

    connect(&pollTimer_, SIGNAL(timeout()), this, SLOT(pollEvents()));
    pollTimer_.start(1000);
}




//// SLOTS ////

void MainWindow::state_changed(Call *call, Call::State previousState)
{
    qDebug() << "on state changed! " << previousState << endl;
}

void MainWindow::incoming_call(Call *call)
{
    qDebug() << "incoming call!";
    mainCall_ = call;
}

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

void MainWindow::pollEvents()
{
    qDebug() << "Poll Events?";
    AccountModel::currentAccount()->poll_events();
}


void MainWindow::on_answer_button_clicked()
{
    if (mainCall_) {
        mainCall_->performAction(Call::Action::ACCEPT);
    }
}
