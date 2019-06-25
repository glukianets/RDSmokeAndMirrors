#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "RDType.h"

#define RD_FINAL_CLASS __attribute__((objc_subclassing_restricted))

NS_ASSUME_NONNULL_BEGIN

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@class RDSmoke;
@class RDMirror;
@class RDClass;
@class RDProtocol;
@class RDMethod;
@class RDProperty;
@class RDIvar;

typedef objc_property_t Property;
typedef struct objc_method_description MethodDescription;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDMirror : NSObject
@property (nonatomic, readonly) RDSmoke *smoke;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

RD_FINAL_CLASS
@interface RDClass : RDMirror

@property (nonatomic, readonly, nullable) RDClass *super;
@property (nonatomic, readonly) RDClass *meta;

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly, nullable) NSString *imageName;
@property (nonatomic, readonly) int version;

@property (nonatomic, readonly) NSArray<RDProtocol *> *protocols;
@property (nonatomic, readonly) NSArray<RDProperty *> *properties;
@property (nonatomic, readonly) NSArray<RDMethod *> *methods;
@property (nonatomic, readonly) NSArray<RDIvar *> *ivars;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface RDProtocolItem : NSObject

@property (nonatomic, readonly, getter=isClassLevel) BOOL classLevel;
@property (nonatomic, readonly, getter=isRequired) BOOL required;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

RD_FINAL_CLASS
@interface RDProtocolMethod : RDProtocolItem

@property (nonatomic, readonly) RDMethodSignature *signature;
@property (nonatomic, readonly) SEL selector;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

RD_FINAL_CLASS
@interface RDProtocolProperty : RDProtocolItem

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) RDType *type;
@property (nonatomic, readonly) NSArray<RDPropertyAttribute *> *attributes;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

RD_FINAL_CLASS
@interface RDProtocol : RDMirror

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSArray<RDProtocol *> *protocols;
@property (nonatomic, readonly) NSArray<RDProtocolProperty *> *properties;
@property (nonatomic, readonly) NSArray<RDProtocolMethod *> *methods;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

RD_FINAL_CLASS
@interface RDMethod : RDMirror

@property (nonatomic, readonly) SEL selector;
@property (nonatomic, readonly, nullable) RDMethodSignature *signature;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

RD_FINAL_CLASS
@interface RDProperty : RDMirror

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) RDPropertySignature *signature;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

RD_FINAL_CLASS
@interface RDIvar : RDMirror

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) ptrdiff_t offset;
@property (nonatomic, readonly) RDType *type;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

NS_ASSUME_NONNULL_END
