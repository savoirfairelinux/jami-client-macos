//
//  ChooseContactVC.h
//  Jami
//
//  Created by kate on 2019-10-10.
//

#import <Cocoa/Cocoa.h>
#include <string>

@protocol ChooseContactVCDelegate <NSObject>
-(void)addCallToParticipant:(std::string)participantUri;
@end
namespace lrc {
    namespace api {
        class ConversationModel;
        namespace conversation {
            struct Info;
        }
    }
}

@interface ChooseContactVC : NSViewController
@property (retain, nonatomic) id <ChooseContactVCDelegate> delegate;

- (void)setConversationModel:(lrc::api::ConversationModel *)conversationModel;
- (void)setCurrentConversation:(std::string)conversation;

@end
