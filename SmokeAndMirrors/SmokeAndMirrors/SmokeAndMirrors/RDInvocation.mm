#import "RDInvocation.h"
#import "RDPrivate.h"
#import "RDCommon.h"

#import <ffi/ffi.h>

NSErrorDomain const RDInvocationErrorDomain = @"RDInvocationErrorDomain";
NSInteger const RDInvocationFFIErrorCode = 257;
NSInteger const RDInvocationMethodResolutionErrorCode = 258;
NSInteger const RDInvocationMethodTypeSafetyErrorCode = 259;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#define RDFFIError(STATUS) [NSError errorWithDomain:RDInvocationErrorDomain code:RDInvocationFFIErrorCode userInfo:@{ @"ffi_prep_cif": @(STATUS) }]
#define RDMethodResolutionError() [NSError errorWithDomain:RDInvocationErrorDomain code:RDInvocationMethodResolutionErrorCode userInfo:nil]
#define RDMethodTypeSafetyError() [NSError errorWithDomain:RDInvocationErrorDomain code:RDInvocationMethodTypeSafetyErrorCode userInfo:nil]

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
@interface RDInvocation()

@property (nonatomic, readonly) ffi_cif cif;
@property (nonatomic, readonly) NSUInteger argCount;

@end

@implementation RDInvocation

+ (instancetype)invocationWithArguments:(RDValue *)arguments {
    return [[self alloc] initWithArguments:arguments];
}

- (void)dealloc {
    for (NSUInteger i = 0; i < _argCount; ++i)
        [RDType _ffi_type_destroy:*RD_FLEX_ARRAY_ELEMENT(self, ffi_type *, i)];
}

- (instancetype)initWithArguments:(RDValue *)arguments {
    if (arguments == nil)
        return nil;
    
    NSUInteger count;
    if (RDAggregateType *type = RD_CAST(arguments.type, RDAggregateType); type != nil) {
        if (type.kind != RDAggregateTypeKindStruct)
            return nil;
        count = type.count;
    } else if (RDArrayType *type = RD_CAST(arguments.type, RDArrayType); type != nil) {
        count = type.count;
    } else {
        return nil;
    }
    count += 2;

    self = RD_FLEX_ARRAY_CREATE(self.class, void *, count * 2);
    self = [super init];
    if (self) {
        _arguments = arguments.copy;
        _argCount = count;

        *RD_FLEX_ARRAY_ELEMENT(self, ffi_type *, 0) = &ffi_type_pointer; // self
        *RD_FLEX_ARRAY_ELEMENT(self, ffi_type *, 1) = &ffi_type_pointer; // _cmd
        for (NSUInteger i = 2; i < count; ++i) {
            RDType *fieldType = nil;
            *RD_FLEX_ARRAY_ELEMENT(self, void *, count + i) = (void *)[arguments bufferAtIndex:i - 2 type:&fieldType];
            *RD_FLEX_ARRAY_ELEMENT(self, ffi_type *, i) = fieldType._ffi_type;
        }
    }
    return self;
}

- (RDValue *)invokeWithTarget:(id<NSObject>)target selector:(SEL)selector {
    NSError *error = nil;
    RDValue *result = [self invokeWithTarget:target selector:selector error:&error];
    if (error != nil)
        @throw [[NSException alloc] initWithName:@"InvocationFailedException"
                                          reason:@"invoke returned non-zero error"
                                        userInfo:@{ NSUnderlyingErrorKey: error }];
    return result;
}

- (RDValue *)invokeWithTarget:(id<NSObject>)target selector:(SEL)selector error:(NSError **)error {
    if (target == nil)
        return (void)(error != NULL && (*error = nil)), nil;
    
    Method method = class_getInstanceMethod(object_getClass(target), selector);
    if (method == NULL)
        return (void)(error != NULL && (*error = RDMethodResolutionError())), nil;

    RDMethodSignature *sig = [RDMethodSignature signatureWithObjcTypeEncoding:method_getTypeEncoding(method)];
    if (sig == nil)
        return (void)(error != NULL && (*error = RDMethodTypeSafetyError())), nil;

    RDType *retType = sig.returnValue.type;
    if (retType == nil)
        return (void)(error != NULL && (*error = RDMethodTypeSafetyError())), nil;

    ffi_type *retFFIType = retType._ffi_type;
    if (retFFIType == NULL)
        return (void)(error != NULL && (*error = RDMethodTypeSafetyError())), nil;
    RD_DEFER { [RDType _ffi_type_destroy:retFFIType]; };

    ffi_type **argTypes = RD_FLEX_ARRAY_ELEMENT(self, ffi_type *, 0);
    if (ffi_status status = ffi_prep_cif(&_cif, FFI_DEFAULT_ABI, (unsigned)_argCount, retFFIType, argTypes); status != FFI_OK)
        return (void)(error != NULL && (*error = RDFFIError(status))), nil;

    void **argValues = RD_FLEX_ARRAY_ELEMENT(self, void *, _argCount);
    argValues[0] = &target;
    argValues[1] = &selector;
    RDMutableValue *retValue = [RDMutableValue valueWithBytes:nil ofType:retType];
    ffi_call(&_cif, method_getImplementation(method), [retValue bufferType:NULL], argValues);
    
    return (void)(error != NULL && (*error = nil)), retValue;
}

@end
