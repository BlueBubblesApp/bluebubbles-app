#import "ContactsServicePlugin.h"
#import <contacts_service/contacts_service-Swift.h>

@implementation ContactsServicePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftContactsServicePlugin registerWithRegistrar:registrar];
}
@end
