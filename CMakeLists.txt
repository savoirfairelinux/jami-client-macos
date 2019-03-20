CMAKE_MINIMUM_REQUIRED(VERSION 2.8)

IF(POLICY CMP0022)
  CMAKE_POLICY(SET CMP0022 NEW)
ENDIF(POLICY CMP0022)

SET(PROJ_NAME Jami)
option(RELEASE_TYPE "RELEASE_TYPE" "website")

# To build nighlies we need to update RING_VERSION with an optional command line arg
IF("${RING_VERSION}" STREQUAL "")
   SET(RING_VERSION "1.0.0")
ENDIF("${RING_VERSION}" STREQUAL "")
# if build for App Store version and build number should be incremented
IF("${RELEASE_TYPE}" STREQUAL "AppStore")
   SET(RING_VERSION_NAME "1.35")
ELSE()
   SET(RING_VERSION_NAME "1")
ENDIF()

MESSAGE("Building Ring version - " ${RING_VERSION_NAME} " " ${RING_VERSION})
SET(PROJ_COPYRIGHT " © 2015-2019 Savoir-faire Linux \n GPLv3 https://www.gnu.org/copyleft/gpl.html")

SET(CMAKE_CXX_STANDARD 14)

ADD_DEFINITIONS("-stdlib=libc++ -fobjc-arc")

PROJECT(${PROJ_NAME})

FIND_PACKAGE(Qt5Core REQUIRED)
FIND_PACKAGE(Qt5MacExtras REQUIRED)
FIND_PACKAGE(Qt5Widgets REQUIRED)
FIND_PACKAGE(Qt5Sql REQUIRED)
FIND_PACKAGE(LibRingClient REQUIRED)
FIND_PACKAGE(OpenGL REQUIRED)

EXECUTE_PROCESS(COMMAND git submodule update --init
                WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})

INCLUDE(ExternalProject)
ExternalProject_Add(libqrencode
    GIT_SUBMODULES libqrencode
    SOURCE_DIR ${CMAKE_SOURCE_DIR}/libqrencode
    BINARY_DIR  ${CMAKE_SOURCE_DIR}/libqrencode
    INSTALL_DIR ${CMAKE_SOURCE_DIR}/libqrencode
    CONFIGURE_COMMAND
    #hack to fix incomplete config.h on first run
    COMMAND ./autogen.sh
    COMMAND ./autogen.sh && ./configure --prefix=${CMAKE_SOURCE_DIR}/libqrencode
    BUILD_COMMAND make
    INSTALL_COMMAND make install)

INCLUDE_DIRECTORIES(${CMAKE_SOURCE_DIR}/libqrencode/include)
LINK_DIRECTORIES(${CMAKE_SOURCE_DIR}/libqrencode/lib)

IF(NOT (${ENABLE_SPARKLE} MATCHES false))
   MESSAGE("Sparkle auto-update enabled")

   # find_library searches in /Library/Frameworks by default
   # We add an hint to our custom location

   FIND_LIBRARY(SPARKLE_FRAMEWORK
                NAMES Sparkle
                HINTS ${CMAKE_CURRENT_SOURCE_DIR}/sparkle)
   IF(EXISTS ${SPARKLE_FRAMEWORK})
      SET(ENABLE_SPARKLE 1 CACHE BOOLEAN "Enable Sparkle")
      ADD_DEFINITIONS(-DENABLE_SPARKLE=1)
      MESSAGE("Sparkle is here:" ${SPARKLE_FRAMEWORK})
      FIND_PATH(SPARKLE_INCLUDE_DIR Sparkle.h HINTS ${SPARKLE_FRAMEWORK}/Headers)
      # we need to copy the public key to check the updates
      SET(PUBLIC_KEY_PATH "${CMAKE_CURRENT_SOURCE_DIR}/sparkle/dsa_pub.pem")
      IF(EXISTS ${PUBLIC_KEY_PATH})
         MESSAGE(STATUS "Looking for Public Key - found")
         SET_SOURCE_FILES_PROPERTIES(${PUBLIC_KEY_PATH} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
         SET(PUBLIC_KEY ${PUBLIC_KEY_PATH})
      ELSE(EXISTS ${PUBLIC_KEY_PATH})
         MESSAGE(WARNING "Looking for Public Key - not found")
         MESSAGE(WARNING "${PUBLIC_KEY_PATH} not found Sparkle Framework will NOT work and may even prevent application from launching. Please consider disabling Sparkle Framework, creating a keypair for testing purposes")
      ENDIF(EXISTS ${PUBLIC_KEY_PATH})
   ELSE()
      MESSAGE(WARNING "Sparkle framework not found, disabling it... to build it see README")
      SET(ENABLE_SPARKLE 0 CACHE BOOLEAN "Enable Sparkle")
   ENDIF(EXISTS ${SPARKLE_FRAMEWORK})
ENDIF(NOT (${ENABLE_SPARKLE} MATCHES false))

INCLUDE_DIRECTORIES(SYSTEM ${Qt5Core_INCLUDE_DIRS})
INCLUDE_DIRECTORIES(SYSTEM ${Qt5MacExtras_INCLUDE_DIRS})
INCLUDE_DIRECTORIES(${CMAKE_CURRENT_BINARY_DIR})
INCLUDE_DIRECTORIES( ${CMAKE_CURRENT_SOURCE_DIR})
INCLUDE_DIRECTORIES(${LIB_RING_CLIENT_INCLUDE_DIR})
INCLUDE_DIRECTORIES(${OPENGL_INCLUDE_DIR})

SET(CMAKE_MACOSX_RPATH ON)
SET(CMAKE_SKIP_BUILD_RPATH FALSE)
SET(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE)
SET(CMAKE_INSTALL_RPATH "${CMAKE_CURRENT_SOURCE_DIR}")
SET(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)

MESSAGE("LRC is here:" ${LIB_RING_CLIENT_INCLUDE_DIR})
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
   src/PreferencesWC.mm
   src/PreferencesWC.h
   src/AccSipGeneralVC.mm
   src/AccSipGeneralVC.h
   src/AccAdvancedVC.mm
   src/AccAdvancedVC.h
   src/AccRingGeneralVC.mm
   src/AccRingGeneralVC.h
   src/AccAdvancedSipVC.mm
   src/AccAdvancedSipVC.h
   src/AccAdvancedRingVC.mm
   src/AccAdvancedRingVC.h
   src/CertificateWC.mm
   src/CertificateWC.h
   src/BackupAccountWC.mm
   src/BackupAccountWC.h
   src/RestoreAccountWC.mm
   src/RestoreAccountWC.h
   src/AudioPrefsVC.mm
   src/AudioPrefsVC.h
   src/VideoPrefsVC.mm
   src/VideoPrefsVC.h
   src/GeneralPrefsVC.h
   src/ChatVC.mm
   src/ChatVC.h
   src/SmartViewVC.mm
   src/SmartViewVC.h
   src/ConversationVC.mm
   src/ConversationVC.h
   src/LoadingWCDelegate.h
   src/AbstractLoadingWC.h
   src/AbstractLoadingWC.mm
   src/ExportPasswordWC.mm
   src/ExportPasswordWC.h
   src/MigrateRingAccountsWC.mm
   src/MigrateRingAccountsWC.h
   src/RingWizardChooseVC.h
   src/RingWizardChooseVC.mm
   src/RingWizardLinkAccountVC.h
   src/RingWizardLinkAccountVC.mm
   src/RingWizardNewAccountVC.mm
   src/RingWizardNewAccountVC.h
   src/DialpadWC.mm
   src/DialpadWC.h
   src/RegisterNameWC.mm
   src/RegisterNameWC.h
   src/ChooseAccountVC.h
   src/ChooseAccountVC.mm
   src/MessagesVC.h
   src/MessagesVC.mm
   src/PasswordChangeWC.h
   src/PasswordChangeWC.mm
   src/LrcModelsProtocol.h
   src/AddSIPAccountVC.mm
   src/AddSIPAccountVC.h
   src/AccountSettingsVC.mm
   src/AccountSettingsVC.h
   src/LeaveMessageVC.mm
   src/LeaveMessageVC.h
)

SET(ringclient_BACKENDS
   src/backends/AddressBookBackend.mm
   src/backends/AddressBookBackend.h)

SET(ringclient_VIEWS
   src/views/CallView.mm
   src/views/CallView.h
   src/views/CallLayer.mm
   src/views/CallLayer.h
   src/views/ITProgressIndicator.mm
   src/views/ITProgressIndicator.h
   src/views/RingOutlineView.mm
   src/views/RingOutlineView.h
   src/views/RingTableView.mm
   src/views/RingTableView.h
   src/views/RingIDField.mm
   src/views/RingIDField.h
   src/views/HoverTableRowView.mm
   src/views/HoverTableRowView.h
   src/views/NSColor+RingTheme.mm
   src/views/NSColor+RingTheme.h
   src/views/NSImage+Extensions.mm
   src/views/NSImage+Extensions.h
   src/views/ContextualTableCellView.mm
   src/views/ContextualTableCellView.h
   src/views/IconButton.h
   src/views/IconButton.mm
   src/views/BackgroundView.h
   src/views/BackgroundView.mm
   src/views/IMTableCellView.h
   src/views/IMTableCellView.mm
   src/views/AccountMenuItemView.h
   src/views/AccountMenuItemView.mm
   src/views/RoundedTextField.h
   src/views/RoundedTextField.mm
   src/views/MessageBubbleView.h
   src/views/MessageBubbleView.mm
   src/views/SendMessagePanel.h
   src/views/SendMessagePanel.mm
   src/views/HoverButton.h
   src/views/HoverButton.mm
   src/views/CenteredClipView.h
   src/views/CenteredClipView.mm
)

SET(ringclient_OTHERS
   src/main.mm
   src/AppDelegate.mm
   src/AppDelegate.h
   src/Constants.h
   src/INDSequentialTextSelectionManager.mm
   src/INDSequentialTextSelectionManager.h
   src/delegates/ImageManipulationDelegate.mm
   src/delegates/ImageManipulationDelegate.h
   src/AccountSelectionManager.h
   src/AccountSelectionManager.mm
   src/utils.h
   src/NSString+Extensions.h
   src/NSString+Extensions.mm
   src/RingMainWindow.h
   src/RingMainWindow.mm)


SET(ringclient_XIBS
   MainMenu
   RingWindow
   CurrentCall
   GeneralPrefs
   AccSipGeneral
   AccRingGeneral
   AccAdvancedSip
   AccAdvancedRing
   AudioPrefs
   VideoPrefs
   PreferencesWindow
   RingWizard
   CertificateWindow
   BackupAccountWindow
   RestoreAccountWindow
   ExportPasswordWindow
   MigrateRingAccountsWindow
   Conversation
   RingWizardLinkAccount
   RingWizardNewAccount
   RingWizardChoose
   Dialpad
   RegisterNameWindow
   AccountMenuItemView
   PasswordChange
   MessageCells
   AddSIPAccountVC
   AccountSettings
   LeaveMessageVC
)

# Icons
# This part tells CMake where to find and install the file itself
SET(myApp_ICON ${CMAKE_CURRENT_SOURCE_DIR}/data/appicon.icns)
SET_SOURCE_FILES_PROPERTIES(${myApp_ICON} PROPERTIES
       MACOSX_PACKAGE_LOCATION Resources)
SET(ring_ICONS
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_audio_file.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_exit.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_stoprecord.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_audio.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_audio.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_folder.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_block.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_attachment.png
${CMAKE_CURRENT_SOURCE_DIR}/data/default_avatar_overlay.png
${CMAKE_CURRENT_SOURCE_DIR}/data/symbol_name.png
${CMAKE_CURRENT_SOURCE_DIR}/data/background-light.png
${CMAKE_CURRENT_SOURCE_DIR}/data/background-dark.png
${CMAKE_CURRENT_SOURCE_DIR}/data/symbol_blue.png
${CMAKE_CURRENT_SOURCE_DIR}/data/background_tile.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_more.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_dialpad.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_accept.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_arrow_back.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_call.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_cancel.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_hangup.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_hold.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_holdoff.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_mute_video.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_mute_audio.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_chat.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_search.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_quality.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_record.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_call_received.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_call_missed.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_call_made.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_transfer.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_add_participant.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_merge_calls.png
${CMAKE_CURRENT_SOURCE_DIR}/data/default_user_icon.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_send.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/audio.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_person_add.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_persons.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_history.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/general.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/video.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_delete.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/qrcode.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_action_video.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/pending_contact_request.png
${CMAKE_CURRENT_SOURCE_DIR}/data/dark/ic_file_upload.png
${CMAKE_CURRENT_SOURCE_DIR}/data/light/ic_picture.png)

SET_SOURCE_FILES_PROPERTIES(${ring_ICONS} PROPERTIES
       MACOSX_PACKAGE_LOCATION Resources)
SET_SOURCE_FILES_PROPERTIES(Credits.rtf PROPERTIES
       MACOSX_PACKAGE_LOCATION Resources)

# package ringtones
IF(NOT IS_DIRECTORY ${RINGTONE_DIR})
    MESSAGE("No ringtone folder provided, use RINGTONE_DIR to specify one")
    SET(RINGTONE_DIR ${CMAKE_INSTALL_PREFIX}/share/ring/ringtones)
    MESSAGE("Trying ${RINGTONE_DIR}")
ENDIF()

IF(IS_DIRECTORY ${RINGTONE_DIR})
    FILE(GLOB RINGTONE_LIST ${RINGTONE_DIR}/*)
    FOREACH(RINGTONE ${RINGTONE_LIST})
        MESSAGE("Adding ringtone ${RINGTONE}")
        GET_FILENAME_COMPONENT(FILE_PATH ${RINGTONE} ABSOLUTE)
        SET(ring_RINGTONES ${ring_RINGTONES} ${FILE_PATH})
    ENDFOREACH()
ELSE()
    MESSAGE("${RINGTONE_DIR} does not exist or is not readable")
ENDIF()

SET_SOURCE_FILES_PROPERTIES(${ring_RINGTONES}
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources/ringtones)

# Check which translations are found for LRC
SET(LRC_TRANSLATIONS_PATH ${CMAKE_INSTALL_PREFIX}/share/libringclient/translations)
FILE(GLOB QM_LIST ${LRC_TRANSLATIONS_PATH}/*.qm)

FOREACH(QM_FILE ${QM_LIST})
    # Extract country code from filename
    GET_FILENAME_COMPONENT(FILENAME ${QM_FILE} NAME_WE)
    STRING(REGEX REPLACE "^lrc_" "" LANG ${FILENAME})

    SET_SOURCE_FILES_PROPERTIES(${LRC_TRANSLATIONS_PATH}/lrc_${LANG}.qm
                PROPERTIES MACOSX_PACKAGE_LOCATION Resources/QtTranslations)
    SET(LOCALIZED_${LANG} ${LOCALIZED_${LANG}}
                "${LRC_TRANSLATIONS_PATH}/lrc_${LANG}.qm")
ENDFOREACH()

# Check which translations are found for the client
FILE(GLOB LPROJ_LIST ui/*.lproj)

FOREACH(LPROJ ${LPROJ_LIST})
    # Extract country code from <lang>.lproj folder name
    GET_FILENAME_COMPONENT(LANG ${LPROJ} NAME_WE)
    IF(EXISTS "${LPROJ}/Localizable.strings")
        MESSAGE("Localizable:" ${LANG})
        SET_SOURCE_FILES_PROPERTIES(${LPROJ}/Localizable.strings
                        PROPERTIES MACOSX_PACKAGE_LOCATION Resources/${LANG}.lproj)

        SET(LOCALIZED_${LANG} ${LOCALIZED_${LANG}}
                        ${LPROJ}/Localizable.strings)
    ENDIF()
    FOREACH(xib ${ringclient_XIBS})
       IF(EXISTS "${LPROJ}/${xib}.strings")
            SET_SOURCE_FILES_PROPERTIES(${LPROJ}/${xib}.strings
                        PROPERTIES MACOSX_PACKAGE_LOCATION Resources/${LANG}.lproj)

            SET(LOCALIZED_${LANG} ${LOCALIZED_${LANG}}
                        ${LPROJ}/${xib}.strings)
        ENDIF()
    ENDFOREACH()

    # Regroup those files under a .lproj folder
    SOURCE_GROUP("Resources\\${LANG}.lproj" FILES
                                    ${LOCALIZED_${LANG}})
    # Add them to the list of files to package
    SET(LOCALIZABLE_FILES ${LOCALIZABLE_FILES} ${LOCALIZED_${LANG}})
ENDFOREACH()

# append '.xib' extension before linking xib files in executable
FOREACH(xib ${ringclient_XIBS})
  SET(ringclient_XIBS_FOR_EXECUTABLE ${ringclient_XIBS_FOR_EXECUTABLE} ui/Base.lproj/${xib}.xib)
ENDFOREACH()

SET(TO_ADD
   ${ringclient_CONTROLLERS}
   ${ringclient_BACKENDS}
   ${ringclient_VIEWS}
   ${ringclient_OTHERS}
   ${ringclient_XIBS_FOR_EXECUTABLE}
   ${LOCALIZABLE_FILES}
   ${myApp_ICON}
   Credits.rtf
   ${ring_ICONS}
   ${ring_RINGTONES})

IF(ENABLE_SPARKLE)
   SET( TO_ADD ${TO_ADD} ${PUBLIC_KEY} ${SPARKLE_FRAMEWORK})
ENDIF(ENABLE_SPARKLE)

ADD_EXECUTABLE(${PROJ_NAME} MACOSX_BUNDLE ${TO_ADD})

ADD_DEPENDENCIES(${PROJ_NAME} libqrencode)

# Follow Xcode hierarchy principles
SOURCE_GROUP("Controllers" FILES ${ringclient_CONTROLLERS})
SOURCE_GROUP("Backends" FILES ${ringclient_BACKENDS})
SOURCE_GROUP("CustomViews" FILES ${ringclient_VIEWS})
SOURCE_GROUP("Classes" FILES ${ringclient_OTHERS})
SOURCE_GROUP("Resources\\Interface Builder" FILES
                                    ${ringclient_XIBS_FOR_EXECUTABLE})
SOURCE_GROUP("Resources\\ringtones" FILES ${ring_RINGTONES})

IF(ENABLE_SPARKLE)
    SOURCE_GROUP("Frameworks" FILES ${SPARKLE_FRAMEWORK})
ENDIF(ENABLE_SPARKLE)

TARGET_LINK_LIBRARIES( ${PROJ_NAME}
   ${LIB_RING_CLIENT_LIBRARY}
   ${Qt5Core_LIBRARIES}
   ${Qt5MacExtras_LIBRARIES}
   ${Qt5Widgets_LIBRARIES}
   ${OPENGL_LIBRARIES}
   -lqrencode
)

IF(ENABLE_SPARKLE)
   TARGET_LINK_LIBRARIES(${PROJ_NAME} ${SPARKLE_FRAMEWORK})
ENDIF(ENABLE_SPARKLE)

SET(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -framework AppKit")
SET(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -framework Cocoa")
SET(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -framework Quartz")
SET(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -framework AVFoundation")
SET(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -framework AddressBook")
SET(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -framework SystemConfiguration")

# These variables are specific to our plist and are NOT standard CMake variables
SET(MACOSX_BUNDLE_NSMAIN_NIB_FILE "MainMenu")
SET(MACOSX_BUNDLE_NSPRINCIPAL_CLASS "NSApplication")

# App store version should be sandboxed and using different bundle identifier
IF("${RELEASE_TYPE}" STREQUAL "AppStore")
    SET_TARGET_PROPERTIES(${PROJ_NAME} PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/cmake/MacOSXBundleInfo.plist.in
        MACOSX_BUNDLE_GUI_IDENTIFIER "com.savoirfairelinux.ring.macos"
        XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS "${CMAKE_CURRENT_LIST_DIR}/data/Jami.entitlements"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "${RING_VERSION_NAME}"
        MACOSX_BUNDLE_LONG_VERSION_STRING "${PROJ_NAME} ${RING_VERSION_NAME}"
        MACOSX_BUNDLE_BUNDLE_VERSION ${RING_VERSION}
        MACOSX_BUNDLE_COPYRIGHT "${PROJ_COPYRIGHT}"
        MACOSX_BUNDLE_INFO_STRING "Build of ${PROJ_NAME}, version ${RING_VERSION}"
        MACOSX_BUNDLE_BUNDLE_NAME ${PROJ_NAME}
        MACOSX_BUNDLE_ICON_FILE "appicon.icns"
    )
ELSE()
    SET_TARGET_PROPERTIES(${PROJ_NAME} PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/cmake/MacOSXBundleInfo.plist.in
        MACOSX_BUNDLE_GUI_IDENTIFIER "cx.ring"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "${RING_VERSION_NAME}"
        MACOSX_BUNDLE_LONG_VERSION_STRING "${PROJ_NAME} ${RING_VERSION_NAME}"
        MACOSX_BUNDLE_BUNDLE_VERSION ${RING_VERSION}
        MACOSX_BUNDLE_COPYRIGHT "${PROJ_COPYRIGHT}"
        MACOSX_BUNDLE_INFO_STRING "Build of ${PROJ_NAME}, version ${RING_VERSION}"
        MACOSX_BUNDLE_BUNDLE_NAME ${PROJ_NAME}
        MACOSX_BUNDLE_ICON_FILE "appicon.icns"
    )
ENDIF()
# Make sure we can find the 'ibtool' program. If we can NOT find it we
# skip generation of this project
FIND_PROGRAM(IBTOOL ibtool HINTS "/usr/bin" "${OSX_DEVELOPER_ROOT}/usr/bin")
IF(${IBTOOL} STREQUAL "IBTOOL-NOTFOUND")
  MESSAGE(SEND_ERROR "ibtool can not be found and is needed to compile the .xib files. It should have been installed with
                    the Apple developer tools. The default system paths were searched in addition to ${OSX_DEVELOPER_ROOT}/usr/bin")
endif()

# Compile the .xib files using the 'ibtool' program with the destination being the app package
FOREACH(xib ${ringclient_XIBS})
  ADD_CUSTOM_COMMAND(TARGET ${PROJ_NAME} POST_BUILD
                      COMMAND ${IBTOOL} --errors --warnings --notices --output-format human-readable-text
                              --compile ${CMAKE_CURRENT_BINARY_DIR}/\${CONFIGURATION}/${PROJ_NAME}.app/Contents/Resources/Base.lproj/${xib}.nib
                             ${CMAKE_CURRENT_SOURCE_DIR}/ui/Base.lproj/${xib}.xib
                      COMMENT "Compiling ${CMAKE_CURRENT_SOURCE_DIR}/ui/Base.lproj/${xib}.xib")

ENDFOREACH()

SET(CMAKE_LIBRARY_PATH ${CMAKE_LIBRARY_PATH} ${CMAKE_INSTALL_PREFIX})

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
                                    Qt5::QTiffPlugin)

# we need two plugin directories platform and imageformats
GET_TARGET_PROPERTY(_loc Qt5::QCocoaIntegrationPlugin LOCATION)
INSTALL(FILES ${_loc} DESTINATION ${QT_PLUGINS_DESTDIR}/platforms COMPONENT Runtime)
LIST(APPEND QT_PLUGINS Qt5::QCocoaIntegrationPlugin)

FOREACH(plugin ${QT_PLUGINS_IMAGEFORMAT})
  GET_TARGET_PROPERTY(_loc ${plugin} LOCATION)
  INSTALL(FILES ${_loc} DESTINATION ${QT_PLUGINS_DESTDIR}/imageformats COMPONENT Runtime)
  LIST(APPEND QT_PLUGINS ${plugin})
ENDFOREACH()

# Add SQLite driver for QtSql
GET_TARGET_PROPERTY(_loc Qt5::QSQLiteDriverPlugin LOCATION)
INSTALL(FILES ${_loc} DESTINATION ${QT_PLUGINS_DESTDIR}/sqldrivers COMPONENT Runtime)
LIST(APPEND QT_PLUGINS Qt5::QSQLiteDriverPlugin)

# directories to look for dependencies
SET(DIRS    ${CMAKE_INSTALL_PREFIX}/lib
            ${QT_LIB_DIR}
            ${CMAKE_CURRENT_SOURCE_DIR}/sparkle
            ${CMAKE_CURRENT_SOURCE_DIR}/libqrencode/lib)

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
