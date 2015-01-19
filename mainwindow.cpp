#include "mainwindow.h"
#include "ui_mainwindow.h"



MainWindow::MainWindow(QWidget *parent) :
    QMainWindow(parent),
    ui(new Ui::MainWindow)
{
    ui->setupUi(this);
    ui->contact_list->setAttribute(Qt::WA_MacShowFocusRect, false);

    // Setup hidden stuff.
    ui->answer_bar->hide();
    ui->hangup_button->hide();

    //setWindowFlags(Qt::Window | Qt::FramelessWindowHint | Qt::CustomizeWindowHint | Qt::WindowMinimizeButtonHint);
    //setWindowFlags(Qt::Window | Qt::FramelessWindowHint | Qt::WindowMinimizeButtonHint | Qt::WindowMaximizeButtonHint | Qt::WindowCloseButtonHint);

    mainAccount_ = AccountModel::currentAccount();
    callModel_ = CallModel::instance();
    HistoryModel::instance()->addBackend(new LegacyHistoryBackend(this),
                                         LoadOptions::FORCE_ENABLED);

    ContactModel::instance()->addBackend(TransitionalContactBackend::instance(),
                                         LoadOptions::FORCE_ENABLED);

    Contact* test = new Contact();
    test->setNickName("George");
    test->setFirstName("George-Amand");
    test->setFamilyName("Tremblay");
    //test->setPhoneNumbers(PhoneNumber());
    ContactModel::instance()->addContact(test);


    connectSlots();
    ui->contact_list->setModel(ContactModel::instance());
    //ui->contact_list->setModel(CallModel::instance());
    //ui->contact_list->setModel(HistoryModel::instance());
    //ui->contact_list->setModel(ContactModel::instance());
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
}

void MainWindow::showAnswerBar()
{
    // Make sure everything is ok:
    ui->answer_button->show();
    ui->decline_button->show();
    ui->hangup_button->hide();

    // Animatate bar
    ui->answer_bar->resize(ui->content_area->width(), 80);
    ui->answer_bar->move(0, ui->content_area->height() + ui->answer_bar->height());
    QPoint goingTo(0, ui->content_area->height() - ui->answer_bar->height());
    ui->answer_bar->show();

    QPropertyAnimation* myAnim = new QPropertyAnimation(ui->answer_bar,
                                                        "pos",
                                                        ui->content_area);
    myAnim->setDuration(500);
    myAnim->setStartValue(ui->answer_bar->pos());
    myAnim->setEasingCurve(QEasingCurve::OutQuart);
    myAnim->setEndValue(goingTo);
    myAnim->start(QPropertyAnimation::DeleteWhenStopped);
}

void MainWindow::hideAnswerBar()
{
    // Move down
    QPoint goingTo(0, ui->content_area->height() + ui->answer_bar->height());
    QPropertyAnimation* myAnim = new QPropertyAnimation(ui->answer_bar,
                                                        "pos",
                                                        ui->content_area);
    myAnim->setDuration(500);
    myAnim->setStartValue(ui->answer_bar->pos());
    myAnim->setEasingCurve(QEasingCurve::InQuart);
    myAnim->setEndValue(goingTo);

    myAnim->start(QPropertyAnimation::DeleteWhenStopped);
}

void MainWindow::transformAnswerBar()
{
    QSize answerSize = ui->answer_button->size();
    QPoint answerPos = ui->answer_button->pos();
    QSize declineSize = ui->decline_button->size();
    QPoint declinePos = ui->decline_button->pos();
    QPropertyAnimation* answAnim = new QPropertyAnimation(ui->answer_button,
                                                        "pos",
                                                        ui->answer_bar);
    answAnim->setDuration(200);
    answAnim->setStartValue(answerPos);
    answAnim->setEasingCurve(QEasingCurve::InCubic);
    answAnim->setEndValue(QPoint(ui->answer_bar->width() + ui->answer_button->width(),
                                ui->answer_button->pos().y()));
    QObject::connect(answAnim, &QPropertyAnimation::finished, [=]() {
        ui->answer_button->hide();
        ui->answer_button->resize(answerSize);
    });


    // Move decline button to center
    QPoint center(ui->answer_bar->width() / 2 - ui->hangup_button->width() / 2,
                  ui->answer_button->pos().y());
    QPropertyAnimation* declAnim = new QPropertyAnimation(ui->decline_button,
                                                        "pos",
                                                        ui->answer_bar);
    declAnim->setDuration(200);
    declAnim->setStartValue(ui->decline_button->pos());
    declAnim->setEasingCurve(QEasingCurve::InOutCubic);
    declAnim->setEndValue(center);
    QObject::connect(declAnim, &QPropertyAnimation::finished, [=]() {
        ui->decline_button->hide();
        ui->hangup_button->show();
        ui->decline_button->resize(declineSize);
        ui->decline_button->move(declinePos);
    });

    answAnim->start(QPropertyAnimation::DeleteWhenStopped);
    declAnim->start(QPropertyAnimation::DeleteWhenStopped);
}


//// SLOTS ////

void MainWindow::state_changed(Call *call, Call::State previousState)
{
    qDebug() << "on state changed! " << previousState << endl;
}

void MainWindow::incoming_call(Call *call)
{
    showAnswerBar();
    mainCall_ = call;
}

void MainWindow::on_call_button_clicked()
{
    mainCall_ = CallModel::instance()->dialingCall();
    qDebug() << "ICI" << ui->search_bar->text();
    mainCall_->setDialNumber(ui->search_bar->text());
    mainCall_->performAction(Call::Action::ACCEPT);
}

void MainWindow::on_hangup_button_clicked()
{
    if (mainCall_)
        mainCall_->performAction(Call::Action::REFUSE);
    hideAnswerBar();

}

void MainWindow::on_answer_button_clicked()
{
    if (mainCall_) {
        mainCall_->performAction(Call::Action::ACCEPT);
    }
    transformAnswerBar();
}


void MainWindow::on_decline_button_clicked()
{
    if (mainCall_) {
        mainCall_->performAction((Call::Action::REFUSE));
    }
    hideAnswerBar();
}
