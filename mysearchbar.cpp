#include "mysearchbar.h"

MySearchBar::MySearchBar(QWidget *parent) : QLineEdit(parent)
{
    QStringList wordList;
    wordList << "alpha" << "omega" << "omicron" << "zeta";

    QCompleter *completer = new QCompleter(wordList, this);
    completer->setCaseSensitivity(Qt::CaseInsensitive);
    setCompleter(completer);

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
        setClearButtonEnabled(true);
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
        setClearButtonEnabled(false);
        setAlignment(Qt::AlignHCenter);
        setStyleSheet("background-color: rgb(225, 225, 225);"
                      "border: 1px solid;"
                      "border-color: rgb(208, 208, 208);"
                      "border-radius: 4px;"
                      "color: rgb(160, 160, 160);");
    } else { // usertext
        setClearButtonEnabled(true);
        setAlignment(Qt::AlignLeft);
        setStyleSheet("background-color: rgb(225, 225, 225);"
                      "border: 1px solid;"
                      "border-color: rgb(208, 208, 208);"
                      "border-radius: 4px;"
                      "color: rgb(45, 45, 45);");
    }
}

