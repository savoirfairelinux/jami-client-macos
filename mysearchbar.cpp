#include "mysearchbar.h"

MySearchBar::MySearchBar(QWidget *parent) : QLineEdit(parent)
{
    QObject::connect(this, SIGNAL(editingFinished()), this, SLOT(changePlaceholderColor()));
    QObject::connect(this, SIGNAL(textChanged(QString)), this, SLOT(changePlaceholderColor()));
    QObject::connect(this, SIGNAL(), this, SLOT(changePlaceholderColor()));
}

MySearchBar::~MySearchBar()
{

}

void MySearchBar::focusInEvent(QFocusEvent* e)
{
    if (text().count() <= 0) {
        setAlignment(Qt::AlignLeft);
        setStyleSheet("background-color: rgb(225, 225, 225);"
                      "border: 1px solid;"
                      "border-color: rgb(208, 208, 208);"
                      "border-radius: 4px;"
                      "color: rgb(160, 160, 160);");
        QLineEdit::focusInEvent(e);
    }
}

//// SLOTS ////

// TODO: Animate Search placeholder.
void MySearchBar::changePlaceholderColor()
{
    if (text().count() <= 0) { // placeholder
        setAlignment(Qt::AlignHCenter);
        setStyleSheet("background-color: rgb(225, 225, 225);"
                      "border: 1px solid;"
                      "border-color: rgb(208, 208, 208);"
                      "border-radius: 4px;"
                      "color: rgb(160, 160, 160);");
    } else { // usertext
        setAlignment(Qt::AlignLeft);
        setStyleSheet("background-color: rgb(225, 225, 225);"
                      "border: 1px solid;"
                      "border-color: rgb(208, 208, 208);"
                      "border-radius: 4px;"
                      "color: rgb(45, 45, 45);");
    }
}

