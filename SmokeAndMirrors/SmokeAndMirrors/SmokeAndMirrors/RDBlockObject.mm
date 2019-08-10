#import "RDBlockObject.h"
#import "RDType.h"
#import "RDPrivate.h"

#import <objc/runtime.h>
#import <ffi/ffi.h>

static const char *kBlockCaptureAssocKey = "RDBlockCaptureAssocKey";

struct RDBlockObjectCapture {
    RDBlockDescriptor descriptor;
    ffi_cif cifExt;
    ffi_cif cifInt;
    SEL selector;
    void *fptr;
};

@implementation RDBlockObject {
    RDBlockInfoFlags _flags;
    int _reserved;
    void (*_invoke)(id, ...);
    RDBlockDescriptor *_descriptor;
}

void RDBlockObjectTramp(ffi_cif *, void *ret, void **args, void *cap) {
    __unsafe_unretained id self = *(__autoreleasing id *)args[0];
    RDBlockObjectCapture *capture = (RDBlockObjectCapture *)cap;
    SEL selector = capture->selector;
    
    Method method = class_getInstanceMethod(object_getClass(self), selector);
    if (method == NULL)
        return;

    unsigned extArgCount = capture->cifExt.nargs;
    void *argValues[extArgCount];

    argValues[0] = &self;
    argValues[1] = &selector;
    for (unsigned i = 2; i < extArgCount; ++i)
        argValues[i] = args[i - 1];
    
    ffi_call(&capture->cifExt, method_getImplementation(method), ret, argValues);
}

void RDBlockObjectCopy(void *, void *) {
    // do nothing;
}

void RDBlockObjectDispose(void *block) {
    [(__bridge id)block dealloc];
}

RDBlockObjectCapture *RDBlockObjectCaptureForSelectorInClass(SEL selector, Class cls) {
    RDBlockObjectCapture *capture = (RDBlockObjectCapture *)calloc(1, sizeof(RDBlockObjectCapture));
    capture->selector = selector;
        
    Method method = class_getInstanceMethod(cls, selector);
    if (method == NULL)
        return NULL;

    RDMethodSignature *sig = [RDMethodSignature signatureWithObjcTypeEncoding:method_getTypeEncoding(method)];
    if (sig == nil)
        return NULL;

    NSUInteger extArgCount = sig.argumentsCount;
    {
        ffi_type **argTypes = (ffi_type **)calloc(extArgCount, sizeof(ffi_type *));

        for (NSUInteger i = 0; i < extArgCount; ++i)
            if (ffi_type *type = [sig argumentAtIndex:i]->type._ffi_type; type != NULL)
                argTypes[i] = type;
            else
                return NULL;

        ffi_type *retType = sig.returnValue->type._ffi_type;
        if (retType == NULL)
            return NULL;
        
        if (ffi_prep_cif(&capture->cifExt, FFI_DEFAULT_ABI, (unsigned)extArgCount, retType, argTypes) != FFI_OK)
            return NULL;
    }
    
    NSUInteger intArgCount = extArgCount - 1;
    {
        ffi_type **argTypes = (ffi_type **)calloc(intArgCount, sizeof(ffi_type *));
        for (NSUInteger i = 0; i < intArgCount; ++i)
            argTypes[i] = capture->cifExt.arg_types[i + i];
        
        ffi_type *retType = capture->cifExt.rtype;
        if (ffi_prep_cif(&capture->cifInt, FFI_DEFAULT_ABI, (unsigned)intArgCount, retType, argTypes) != FFI_OK)
            return NULL;
    }
    
    ffi_closure *closure = (ffi_closure *)ffi_closure_alloc(sizeof(ffi_closure), &capture->fptr);
    if (closure == NULL)
        return NULL;
        
    if (ffi_prep_closure_loc(closure, &capture->cifInt, RDBlockObjectTramp, capture , capture->fptr) != FFI_OK)
        return NULL;

    capture->descriptor = (RDBlockDescriptor) {
        .reserved=0,
        .size=class_getInstanceSize(cls),
        .copy = RDBlockObjectCopy,
        .dispose = RDBlockObjectDispose,
        .signature = NULL, // TODO: fill in
    };

    return capture;
}

+ (void)initialize {
    if (self == RDBlockObject.self)
        return;
            
    SEL selector = [self selectorForCalling];
    if (selector == NULL)
        return;
    
    RDBlockObjectCapture *capture = RDBlockObjectCaptureForSelectorInClass(selector, self);
    if (capture == NULL)
        [NSException raise:NSInternalInconsistencyException
                    format:@"Couldn't form capture for @selector(%s) in %@", sel_getName(selector), self];
    
    objc_setAssociatedObject(self, kBlockCaptureAssocKey, (__bridge id)capture, OBJC_ASSOCIATION_ASSIGN);
}

+ (SEL)selectorForCalling {
    return @selector(invoke);
}

- (instancetype)init {
    RDBlockObjectCapture *capture = (__bridge RDBlockObjectCapture *)objc_getAssociatedObject(self.class, kBlockCaptureAssocKey);
    if (capture == NULL)
        return nil;

    self = [super init];
    if (self) {
        if (class_getInstanceSize(class_getSuperclass(RDBlockObject.self)) != sizeof(id)
            || (uintptr_t)&_flags - (uintptr_t)self != offsetof(RDBlockInfo, flags)
            || (uintptr_t)&_reserved - (uintptr_t)self != offsetof(RDBlockInfo, reserved)
            || (uintptr_t)&_invoke - (uintptr_t)self != offsetof(RDBlockInfo, invoke)
            || (uintptr_t)&_descriptor - (uintptr_t)self != offsetof(RDBlockInfo, descriptor))
            return nil; // layout compromized

        _flags = (RDBlockInfoFlags)(RDBlockInfoFlagHasCopyDispose | RDBlockInfoFlagNeedsFreeing);
        _invoke = (void (*)(id, ...))capture->fptr;
        _descriptor = &capture->descriptor;
    }
    return [self retain];
}

- (instancetype)initWithCFunctionPointer:(void (*)(id, ...))fptr {
    self = [self init];
    if (self) {
        _invoke = fptr;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)__unused zone {
    return self;
}

- (void)invoke {
    // do nothing
}

- (id)retain {
    return Block_copy(self);
}

- (oneway void)release {
    Block_release(self);
}

- (NSUInteger)retainCount {
    return _flags & RDBlockInfoFlagsRefCountMask;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"
- (void)dealloc {
    objc_destructInstance(self);
    // _Block_release will call _Block_deallocator and release memory itself,
    // so we don't want NSObject to do the same; therefore, no [super dealloc];
}
#pragma clang diagnostic pop

- (void (^)(void))asBlock {
    return (id)self;
}

@end
