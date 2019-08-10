#import "RDReflection.h"
#import "RDPrivate.h"
#import "RDSmoke.h"

@implementation RDReflection

- (instancetype)initWithObject:(id)object {
    return [self initWithObject:object usingSmoke:nil];
}

- (instancetype)initWithObject:(id)object usingSmoke:(RDSmoke *)smoke {
    self = [super init];
    if (self) {
        _object = object;
        _smoke = smoke ?: [RDSmoke currentThreadSmoke];
        _mirror = ({
            RDClass *cls;
            if (RDIsBlock(object))
                cls = [_smoke mirrorForObjcBlock:object];
            else
                cls = [_smoke mirrorForObjcClass:object_getClass(object)];
            cls;
        });
    }
    return self;
}

- (id)objectAtKeyedSubscribt:(NSString *)__unused ivarName {
    return nil;
}

- (NSString *)description {
    return [self stringRepresentationWithExtra:NULL];
}

- (NSString *)debugDescription {
    NSArray *extra;
    NSString *repr = [self stringRepresentationWithExtra:&extra];
    return [NSString stringWithFormat:@"%@\n\n%@", repr, [extra componentsJoinedByString:@"\n\n"]];
}

- (NSString *)stringRepresentationWithExtra:(NSArray **)extra {
    NSMutableArray *more = extra == NULL ? nil : [NSMutableArray array];
    
    NSMutableArray *fields = [NSMutableArray array];
    for (RDClass *mirror = self.mirror; mirror != nil; mirror = mirror.super)
        for (RDIvar *ivar in mirror.ivars.reverseObjectEnumerator)
            [fields addObject:({
                uint8_t *bytes = ivar.offset == RDOffsetUnknown ? NULL : (uint8_t *)(__bridge void *)self.object + ivar.offset;
                NSString *def = (bytes == NULL ? nil : [ivar.type _value_describeBytes:bytes additionalInfo:more]) ?: @"<?>";
                [NSString stringWithFormat:@"    %@ = %@;", ivar.name ?: @"_", def];
            })];
   
    if (extra != NULL)
        *extra = more;
    
    NSString *description = [fields.reverseObjectEnumerator.allObjects componentsJoinedByString:@"\n"];
    
    return [NSString stringWithFormat:@"(%@ *)%p {\n%@\n}", self.mirror.name, self.object, description];
}

@end

@implementation NSObject(RDReflection)

- (RDReflection *)rd_reflect {
    return [[RDReflection alloc] initWithObject:self];
}

@end

RD_EXTERN RDReflection *_Nullable RDReflect(_Nullable id object) {
    return object == nil ? nil : [[RDReflection alloc] initWithObject:object];
}

RD_EXTERN RDReflection *_Nullable RDReflectAddress(uintptr_t address) {
    return address == 0u ? nil : [[RDReflection alloc] initWithObject:(__bridge id)(void *)address];
}
