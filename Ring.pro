#-------------------------------------------------
#
# Project created by QtCreator 2014-12-02T09:49:01
#
#-------------------------------------------------

QT       += core gui

greaterThan(QT_MAJOR_VERSION, 4): QT += widgets

TARGET = Ring
TEMPLATE = app

CONFIG += c++11

SOURCES += main.cpp\
        mainwindow.cpp \
    mylistview.cpp

HEADERS  += mainwindow.h \
    mylistview.h

FORMS    += mainwindow.ui

macx: LIBS += -L$$PWD/build/ -lqtsflphone

INCLUDEPATH += $$PWD/../sflphone/kde/src/lib
DEPENDPATH += $$PWD/../sflphone/kde/src/lib
