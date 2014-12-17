#include "mylistview.h"

MyListView::MyListView(QWidget *parent) :
    QListView(parent)
{
    setAttribute(Qt::WA_MacShowFocusRect, false);
}
