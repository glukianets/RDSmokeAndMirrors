#import "RDBlockObject.h"
#import "RDPrivate.h"
#import <objc/runtime.h>

static const char *kBlockDescriptorAssocKey = "RDBlockDescriptorAssocKey";

@implementation RDBlockObject {
    RDBlockInfoFlags _flags;
    int _reserved;
    void (*_invoke)(id, ...);
    RDBlockDescriptor *_descriptor;
}

+ (RDBlockDescriptor *)blockDescriptor {
    RDBlockDescriptor *descriptor = (__bridge RDBlockDescriptor *)objc_getAssociatedObject(self, kBlockDescriptorAssocKey);
    if (descriptor == NULL) {
        @synchronized (self) {
            descriptor = (__bridge RDBlockDescriptor *)objc_getAssociatedObject(self, kBlockDescriptorAssocKey);
            if (descriptor == NULL) {
                descriptor = (RDBlockDescriptor *)malloc(sizeof(RDBlockDescriptor));
                *descriptor = (RDBlockDescriptor) {
                    .reserved=0,
                    .size=class_getInstanceSize(self),
                    .copyHelper = NULL,
                    .disposeHelper = NULL,
                    .signature = NULL,
                };
            }
            objc_setAssociatedObject(self, kBlockDescriptorAssocKey, (__bridge id)descriptor, OBJC_ASSOCIATION_ASSIGN);
        }
    }
    return descriptor;
}

- (instancetype)initWithCFunctionPointer:(void (*)(id, ...))fptr {
    self = [super init];
    if (self) {
        if (class_getInstanceSize(class_getSuperclass(RDBlockObject.self)) != sizeof(id)
            || (uintptr_t)&_flags - (uintptr_t)self != offsetof(RDBlockInfo, flags)
            || (uintptr_t)&_reserved - (uintptr_t)self != offsetof(RDBlockInfo, reserved)
            || (uintptr_t)&_invoke - (uintptr_t)self != offsetof(RDBlockInfo, invoke)
            || (uintptr_t)&_descriptor - (uintptr_t)self != offsetof(RDBlockInfo, descriptor))
            return nil; // layout compromized

        _flags = (RDBlockInfoFlags)0;
        _invoke = fptr;
        _descriptor = [self.class blockDescriptor];
    }
    return self;
}

@end
