CMAKE_MINIMUM_REQUIRED(VERSION 2.8)

IF(POLICY CMP0022)
  CMAKE_POLICY(SET CMP0022 NEW)
ENDIF(POLICY CMP0022)

SET(PROJ_NAME Ring)
SET(RING_VERSION "0.4.0")
SET(RING_VERSION_NAME "Samuel de Champlain")
SET(BUNDLE_VERSION "Samuel de Champlain - beta")

SET(PROJ_COPYRIGHT " © 2015 Savoir-faire Linux \n GPLv3 https://www.gnu.org/copyleft/gpl.html")

ADD_DEFINITIONS("-std=c++11")

PROJECT(${PROJ_NAME})

FIND_PACKAGE(Qt5Core REQUIRED)
FIND_PACKAGE(Qt5MacExtras REQUIRED)
FIND_PACKAGE(Qt5Widgets REQUIRED)
FIND_PACKAGE(LibRingClient REQUIRED)

INCLUDE_DIRECTORIES(SYSTEM ${Qt5Core_INCLUDE_DIRS})
INCLUDE_DIRECTORIES(SYSTEM ${Qt5MacExtras_INCLUDE_DIRS})
INCLUDE_DIRECTORIES(${CMAKE_CURRENT_BINARY_DIR})
INCLUDE_DIRECTORIES( ${CMAKE_CURRENT_SOURCE_DIR})
INCLUDE_DIRECTORIES(${LIB_RING_CLIENT_INCLUDE_DIR})

MESSAGE("LibRingClient is here:" ${LIB_RING_CLIENT_INCLUDE_DIR})
SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -w")

#Files to compile
SET(ringclient_CONTROLLERS
   src/QNSTreeController.mm
   src/QNSTreeController.h
   src/CurrentCallVC.mm
   src/CurrentCallVC.h
   src/GeneralPrefsVC.mm
   src/RingWizardWC.mm
   src/RingWizardWC.h
   src/RingWindowController.mm
   src/RingWindowController.h
   src/ConversationsVC.mm
   src/ConversationsVC.h
   src/PreferencesVC.mm
   src/PreferencesVC.h
   src/AccGeneralVC.mm
   src/AccGeneralVC.h
   src/AccVideoVC.mm
   src/AccVideoVC.h
   src/AccAudioVC.mm
   src/AccAudioVC.h
   src/AccRingVC.mm
   src/AccRingVC.h
   src/AccAdvancedVC.mm
   src/AccAdvancedVC.h
   src/AccSecurityVC.mm
   src/AccSecurityVC.h
   src/AudioPrefsVC.mm
   src/AudioPrefsVC.h
   src/AccountsVC.mm
   src/AccountsVC.h
   src/VideoPrefsVC.mm
   src/VideoPrefsVC.h
   src/GeneralPrefsVC.h
   src/HistoryVC.mm
   src/HistoryVC.h
   src/PersonsVC.mm
   src/PersonsVC.h)

SET(ringclient_BACKENDS
   src/backends/AddressBookBackend.mm
   src/backends/MinimalHistoryBackend.mm
   src/backends/AddressBookBackend.h
   src/backends/MinimalHistoryBackend.h)

SET(ringclient_VIEWS
   src/views/CallView.mm
   src/views/CallView.h
   src/views/PersonCell.mm
   src/views/PersonCell.h)

SET(ringclient_OTHERS
   src/main.mm
   src/AppDelegate.mm
   src/AppDelegate.h
   src/delegates/ImageManipulationDelegate.mm
   src/delegates/ImageManipulationDelegate.h)


SET(ringclient_XIBS
   MainMenu
   RingWindow
   CurrentCall
   GeneralPrefs
   Accounts
   AccGeneral
   AccAudio
   AccVideo
   AccRing
   AccAdvanced
   AccSecurity
   AudioPrefs
   VideoPrefs
   PreferencesScreen
   RingWizard)

# Icons
# This part tells CMake where to find and install the file itself
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
SET_SOURCE_FILES_PROPERTIES(Credits.rtf PROPERTIES
       MACOSX_PACKAGE_LOCATION Resources)

# append '.xib' extension before linking xib files in executable
FOREACH(xib ${ringclient_XIBS})
  SET(ringclient_XIBS_FOR_EXECUTABLE ${ringclient_XIBS_FOR_EXECUTABLE} ui/${xib}.xib)
ENDFOREACH()

ADD_EXECUTABLE(${PROJ_NAME} MACOSX_BUNDLE
   ${ringclient_CONTROLLERS}
   ${ringclient_BACKENDS}
   ${ringclient_VIEWS}
   ${ringclient_OTHERS}
   ${ringclient_XIBS_FOR_EXECUTABLE}
   ${myApp_ICON}
   Credits.rtf
   ${ring_ICONS})

# Follow Xcode hierarchy principles
SOURCE_GROUP("Controllers" FILES ${ringclient_CONTROLLERS})
SOURCE_GROUP("Backends" FILES ${ringclient_BACKENDS})
SOURCE_GROUP("CustomViews" FILES ${ringclient_VIEWS})
SOURCE_GROUP("Classes" FILES ${ringclient_OTHERS})
SOURCE_GROUP("Resources\\Interface Builder" FILES ${ringclient_XIBS_FOR_EXECUTABLE})


TARGET_LINK_LIBRARIES( ${PROJ_NAME}
   ${LIB_RING_CLIENT_LIBRARY}
   ${Qt5Core_LIBRARIES}
   ${Qt5MacExtras_LIBRARIES}
   ${Qt5Widgets_LIBRARIES}
)

SET(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -framework AppKit")
SET(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -framework Cocoa")
SET(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -framework Quartz")
SET(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -framework AVFoundation")
SET(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -framework AddressBook")

# These variables are specific to our plist and are NOT standard CMake variables
set(MACOSX_BUNDLE_NSMAIN_NIB_FILE "MainMenu")
set(MACOSX_BUNDLE_NSPRINCIPAL_CLASS "NSApplication")

SET_TARGET_PROPERTIES(${PROJ_NAME} PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/cmake/MacOSXBundleInfo.plist.in
        MACOSX_BUNDLE_GUI_IDENTIFIER "cx.ring"
        MACOSX_BUNDLE_SHORT_VERSION_STRING ${RING_VERSION_NAME}
        MACOSX_BUNDLE_LONG_VERSION_STRING "${PROJ_NAME} ${RING_VERSION} Nightly"
        MACOSX_BUNDLE_BUNDLE_VERSION ${RING_VERSION}
        MACOSX_BUNDLE_COPYRIGHT "${PROJ_COPYRIGHT}"
        MACOSX_BUNDLE_INFO_STRING "Nightly build of ${PROJ_NAME} ${RING_VERSION} for testing and development"
        MACOSX_BUNDLE_BUNDLE_NAME ${PROJ_NAME}
        MACOSX_BUNDLE_ICON_FILE "appicon.icns"
    )

# Make sure we can find the 'ibtool' program. If we can NOT find it we
# skip generation of this project
FIND_PROGRAM(IBTOOL ibtool HINTS "/usr/bin" "${OSX_DEVELOPER_ROOT}/usr/bin")
IF(${IBTOOL} STREQUAL "IBTOOL-NOTFOUND")
  MESSAGE(SEND_ERROR "ibtool can not be found and is needed to compile the .xib files. It should have been installed with
                    the Apple developer tools. The default system paths were searched in addition to ${OSX_DEVELOPER_ROOT}/usr/bin")
endif()

# Make sure the 'Resources' Directory is correctly created before we build
ADD_CUSTOM_COMMAND(TARGET ${PROJ_NAME} PRE_BUILD
                      COMMAND mkdir -p ${CMAKE_CURRENT_BINARY_DIR}/\${CONFIGURATION}/${PROJ_NAME}.app/Contents/Resources)

# Compile the .xib files using the 'ibtool' program with the destination being the app package
FOREACH(xib ${ringclient_XIBS})
  ADD_CUSTOM_COMMAND(TARGET ${PROJ_NAME} POST_BUILD
                      COMMAND ${IBTOOL} --errors --warnings --notices --output-format human-readable-text
                              --compile ${CMAKE_CURRENT_BINARY_DIR}/\${CONFIGURATION}/${PROJ_NAME}.app/Contents/Resources/${xib}.nib
                             ${CMAKE_CURRENT_SOURCE_DIR}/ui/${xib}.xib
                      COMMENT "Compiling ${CMAKE_CURRENT_SOURCE_DIR}/ui/${xib}.xib")

ENDFOREACH()

set(CMAKE_LIBRARY_PATH ${CMAKE_LIBRARY_PATH} ${CMAKE_INSTALL_PREFIX})

SET(APPS "\${CMAKE_INSTALL_PREFIX}/${PROJ_NAME}.app")

INSTALL(TARGETS ${PROJ_NAME} BUNDLE DESTINATION . COMPONENT Runtime)

SET(QT_PLUGINS_DESTDIR ${PROJ_NAME}.app/Contents/Plugins)
#--------------------------------------------------------------------------------
# Install needed Qt plugins by copying directories from the qt installation


#MESSAGE("GUI====")
#foreach(plugin ${Qt5Gui_PLUGINS})
#  message("Plugin ${plugin} is at location ${_loc}")
#endforeach()

LIST(APPEND QT_PLUGINS_IMAGEFORMAT  Qt5::QTgaPlugin
                                    Qt5::QGifPlugin
                                    Qt5::QICNSPlugin
                                    Qt5::QICOPlugin
                                    Qt5::QJpegPlugin
                                    Qt5::QJp2Plugin
                                    Qt5::QMngPlugin
                                    Qt5::QTiffPlugin
                                    Qt5::QDDSPlugin)

# we need two plugin directories platform and imageformats
GET_TARGET_PROPERTY(_loc Qt5::QCocoaIntegrationPlugin LOCATION)
INSTALL(FILES ${_loc} DESTINATION ${QT_PLUGINS_DESTDIR}/platforms COMPONENT Runtime)
LIST(APPEND QT_PLUGINS Qt5::QCocoaIntegrationPlugin)

FOREACH(plugin ${QT_PLUGINS_IMAGEFORMAT})
  GET_TARGET_PROPERTY(_loc ${plugin} LOCATION)
  INSTALL(FILES ${_loc} DESTINATION ${QT_PLUGINS_DESTDIR}/imageformats COMPONENT Runtime)
  LIST(APPEND QT_PLUGINS ${plugin})
ENDFOREACH()

# directories to look for dependencies
SET(DIRS ${CMAKE_INSTALL_PREFIX}/lib ${QT_LIB_DIR})

INSTALL(CODE "
    file(GLOB_RECURSE QTPLUGINS
      \"\${CMAKE_INSTALL_PREFIX}/${QT_PLUGINS_DESTDIR}/*${CMAKE_SHARED_LIBRARY_SUFFIX}\")
    include(BundleUtilities)
    SET(BU_CHMOD_BUNDLE_ITEMS TRUE)
    fixup_bundle(\"${APPS}\" \"\${QTPLUGINS}\" \"${DIRS}\")
    " COMPONENT Runtime)

#================================
# Packaging
#================================
SET( CPACK_PACKAGE_DESCRIPTION_SUMMARY ${PROJ_NAME})
SET( CPACK_PACKAGE_NAME ${PROJ_NAME} )
SET( CPACK_PACKAGE_CONTACT "Alexandre Lision")
SET( CPACK_PACKAGE_VENDOR "Savoir-faire Linux")
SET( CPACK_PACKAGE_VERSION_MAJOR ${PROG_MAJOR_VERSION})
SET( CPACK_PACKAGE_VERSION_MINOR ${PROG_MINOR_VERSION})
SET( CPACK_PACKAGE_VERSION_PATCH ${PROG_PATCH_VERSION})
SET(CPACK_BINARY_DRAGNDROP ON)
SET( CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}")
INCLUDE(CPack)
