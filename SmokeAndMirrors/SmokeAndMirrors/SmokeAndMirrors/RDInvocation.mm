#import "RDInvocation.h"
#import "RDPrivate.h"
#import <ffi/ffi.h>

@implementation RDMessage

+ (instancetype)messageWithSelector:(SEL)selector arguments:(RDValue *)arguments {
    return [[self alloc] initWithSelector:selector arguments:arguments];
}

- (instancetype)initWithSelector:(SEL)selector arguments:(RDValue *)arguments {
    if (selector == NULL || arguments == nil)
        return nil;
    
    if (RDAggregateType *type = RD_CAST(arguments.type, RDAggregateType); type != NULL) {
        if (type.count != RDSelectorArgumentsCount(selector))
            return nil;
    } else {
        if (RDSelectorArgumentsCount(selector) != 0)
            return nil;
    }
    
    self = [super init];
    if (self) {
        _selector = selector;
        _arguments = arguments.copy;
    }
    return self;
}

@end

@interface RDInvocation()

@property (nonatomic, readonly) ffi_cif cif;

@end

@implementation RDInvocation

- (instancetype)initWithSignature:(RDMethodSignature *)signature message:(RDMessage *)message {
    if (signature == nil || message == nil)
        return nil;
    
    self = [super init];
    if (self) {
        _signature= signature;
        _message = message;
        
        NSUInteger argCount = signature.arguments.count;
        ffi_type *argTypes[argCount];
        ffi_type *retType = nil;
        
        if (ffi_prep_cif(&_cif, FFI_DEFAULT_ABI, (unsigned)argCount, retType, argTypes) != FFI_OK)
            return nil;
    }
    return self;
}

- (void)invoke {
    void *values[1];
    const char *s;
    ffi_call(&_cif, objc_msgSend, &rc, values);
}

- (void)test {
    ffi_cif cif;
    ffi_type *args[1];
    void *values[1];
    const char *s;
    ffi_arg rc;
    
    /* Initialize the argument info vectors */
    args[0] = &ffi_type_pointer;
    values[0] = &s;
    
    /* Initialize the cif */
    if (ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 1, &ffi_type_sint, args) != FFI_OK)
        return;

    s = "Hello World!";
    ffi_call(&cif, (void (*)(void))puts, &rc, values);
    /* rc now holds the result of the call to puts */
    
    /* values holds a pointer to the function's arg, so to
     call puts() again all we need to do is change the
     value of s */
    s = "This is cool!";
    ffi_call(&cif, (void (*)(void))puts, &rc, values);

}

@end
