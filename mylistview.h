#ifndef MYLISTVIEW_H
#define MYLISTVIEW_H

#include <QWidget>
#include <QListView>

class MyListView : public QListView
{
    Q_OBJECT
public:
    explicit MyListView(QWidget *parent = 0);

signals:

public slots:

};

#endif // MYLISTVIEW_H
