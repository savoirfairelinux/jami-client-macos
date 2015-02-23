CMAKE_MINIMUM_REQUIRED(VERSION 2.8)

IF(POLICY CMP0022)
  CMAKE_POLICY(SET CMP0022 NEW)
ENDIF(POLICY CMP0022)

SET(PROJ_NAME Ring)
SET(RING_VERSION 1.0)

ADD_DEFINITIONS("-std=c++11")

PROJECT(${PROJ_NAME})

FIND_PACKAGE(Qt5Core REQUIRED)
FIND_PACKAGE(Qt5Widgets REQUIRED)
FIND_PACKAGE(LibRingClient REQUIRED)

INCLUDE_DIRECTORIES(SYSTEM ${Qt5Core_INCLUDE_DIRS})
INCLUDE_DIRECTORIES(${CMAKE_CURRENT_BINARY_DIR})
INCLUDE_DIRECTORIES( ${CMAKE_CURRENT_SOURCE_DIR})
INCLUDE_DIRECTORIES(${LIB_RING_CLIENT_INCLUDE_DIR})

MESSAGE("LibRingClient is here:" ${LIB_RING_CLIENT_INCLUDE_DIR})
SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -w")

#Files to compile
SET(ringclient_SRCS
   main.mm
   AppDelegate.mm
   RingWindowController.mm
   ConversationsViewController.mm
   PreferencesViewController.mm
   QNSTreeController.mm
   AccGeneralVC.mm
   AccAudioVC.mm
   AccVideoVC.mm
   AccRingVC.mm
   AccAdvancedVC.mm
   AccSecurityVC.mm
   AccountsVC.mm
   AudioPrefsVC.mm
   VideoPrefsVC.mm
   GeneralPrefsVC.mm
   HistoryViewController.mm
   MinimalHistoryBackend.mm)

SET(ringclient_FORMS
   MainMenu.xib
   RingWindow.xib
   GeneralPrefs.xib
   Accounts.xib
   AccGeneral.xib
   AccAudio.xib
   AccVideo.xib
   AccRing.xib
   AccAdvanced.xib
   AccSecurity.xib
   AudioPrefs.xib
   VideoPrefs.xib
   PreferencesScreen.xib)

SET(ringclient_HDRS
   AppDelegate.h
   RingWindowController.h
   ConversationsViewController.h
   PreferencesViewController.h
   AccGeneralVC.h
   AccVideoVC.h
   AccAudioVC.h
   AccRingVC.h
   AccAdvancedVC.h
   AccSecurityVC.h
   AudioPrefsVC.h
   AccountsVC.h
   VideoPrefsVC.h
   GeneralPrefsVC.h
   HistoryViewController.h
   QNSTreeController.h
   MinimalHistoryBackend.h)

# Icons

# NOTE: Don't include the path in MACOSX_BUNDLE_ICON_FILE -- this is
# the property added to Info.plist
#SET(MACOSX_BUNDLE_ICON_FILE appicon.icns)

# And this part tells CMake where to find and install the file itself
SET(myApp_ICON ${CMAKE_CURRENT_SOURCE_DIR}/data/appicon.icns)
SET_SOURCE_FILES_PROPERTIES(${myApp_ICON} PROPERTIES
       MACOSX_PACKAGE_LOCATION "Resources")

SET(ring_ICONS ${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_accept.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_call.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_cancel.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_email.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_new_email.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_search.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ancrage.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/audio.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/general.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/video.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_video.png)
SET_SOURCE_FILES_PROPERTIES(${ring_ICONS} PROPERTIES
       MACOSX_PACKAGE_LOCATION Resources)

SET_SOURCE_FILES_PROPERTIES(${ringclient_FORMS} PROPERTIES
       MACOSX_PACKAGE_LOCATION Resources)

ADD_EXECUTABLE(${PROJ_NAME} MACOSX_BUNDLE
   ${ringclient_SRCS}
   ${ringclient_HDRS}
   ${ringclient_FORMS}
   ${myApp_ICON}
   ${ring_ICONS})

TARGET_LINK_LIBRARIES( ${PROJ_NAME}
   ${LIB_RING_CLIENT_LIBRARY}
   ${Qt5Core_LIBRARIES}
   ${Qt5Widgets_LIBRARIES}
)

set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -framework AppKit")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -framework Cocoa")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -framework Quartz")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -framework AVFoundation")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -framework AddressBook")

SET_TARGET_PROPERTIES(${PROJ_NAME} PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/cmake/MacOSXBundleInfo.plist.in
        MACOSX_BUNDLE_GUI_IDENTIFIER "cx.ring"
        MACOSX_BUNDLE_SHORT_VERSION_STRING ${RING_VERSION}
        MACOSX_BUNDLE_LONG_VERSION_STRING "${PROJ_NAME} ${RING_VERSION} Nightly"
        MACOSX_BUNDLE_BUNDLE_VERSION ${RING_VERSION}
        MACOSX_BUNDLE_COPYRIGHT "${PROJ_NAME}"
        MACOSX_BUNDLE_INFO_STRING "Nightly build of ${PROJ_NAME} ${RING_VERSION} for testing and development"
        MACOSX_BUNDLE_BUNDLE_NAME ${PROJ_NAME}
        MACOSX_BUNDLE_ICON_FILE "appicon.icns"
    )
