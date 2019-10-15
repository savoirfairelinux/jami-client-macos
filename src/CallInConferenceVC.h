//
//  CallInConferenceVC.h
//  Jami
//
//  Created by kate on 2019-10-11.
//

#import <Cocoa/Cocoa.h>
#include <string>

namespace lrc {
    namespace api {
        namespace account {
            struct Info;
        }
    }
}

@protocol CallInConferenceVCDelegate
-(void)removePreviewForContactUri:(std::string)uri;
@end

@interface CallInConferenceVC : NSViewController

-(id) initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
               callId:(const std::string)callId
          accountInfo:(const lrc::api::account::Info *)accInfo;
@property (retain, nonatomic) id <CallInConferenceVCDelegate> delegate;

@end

