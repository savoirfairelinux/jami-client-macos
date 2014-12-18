#ifndef MYSEARCHBAR_H
#define MYSEARCHBAR_H

#include <QWidget>
#include <QLineEdit>
#include <QDebug>
#include <QCompleter>
#include <QPropertyAnimation>
#include <QMargins>

class MySearchBar : public QLineEdit
{
    Q_OBJECT
public:
    explicit MySearchBar(QWidget *parent = 0);
    ~MySearchBar();
    virtual void focusInEvent(QFocusEvent*);


private slots:
    void changePlaceholderColor();
};
#endif // MYSEARCHBAR_H
